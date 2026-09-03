#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"

if [ -f "$ENV_FILE" ]; then
    HF_TOKEN_WAS_SET="${HF_TOKEN+x}"
    CIVITAI_TOKEN_WAS_SET="${CIVITAI_TOKEN+x}"
    EXISTING_HF_TOKEN="${HF_TOKEN:-}"
    EXISTING_CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

    set -a
    # .env is local configuration and is never committed.
    . "$ENV_FILE"
    set +a

    if [ -n "$HF_TOKEN_WAS_SET" ]; then
        HF_TOKEN="$EXISTING_HF_TOKEN"
        export HF_TOKEN
    fi

    if [ -n "$CIVITAI_TOKEN_WAS_SET" ]; then
        CIVITAI_TOKEN="$EXISTING_CIVITAI_TOKEN"
        export CIVITAI_TOKEN
    fi
fi

COMFY_HOME="${COMFY_HOME:-/workspace/runpod-slim/ComfyUI}"

MANIFEST="${1:-}"

if [ -z "$MANIFEST" ]; then
    echo "ERROR: Manifest is required."
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest not found: $MANIFEST"
    exit 1
fi

echo
echo "========================================"
echo " Installing workflow"
echo "========================================"
echo "ComfyUI: $COMFY_HOME"
echo "Manifest: $MANIFEST"
echo

# --------------------------------------------------
# Dependencies
# --------------------------------------------------

if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq is not installed."
    echo
    echo "Install it with:"
    echo "  apt-get update && apt-get install -y yq"
    exit 1
fi

# --------------------------------------------------
# Read workflow
# --------------------------------------------------

WORKFLOW_NAME=$(yq -r '.name' "$MANIFEST")
WORKFLOW_DESCRIPTION=$(yq -r '.description // ""' "$MANIFEST")

echo "Workflow: $WORKFLOW_NAME"

if [ -n "$WORKFLOW_DESCRIPTION" ]; then
    echo "Description: $WORKFLOW_DESCRIPTION"
fi

echo

# --------------------------------------------------
# Install assets
# --------------------------------------------------

install_custom_node() {
    local repo="$1"
    local repo_name="${2:-}"
    local target_dir="$COMFY_HOME/custom_nodes"

    if [ -z "$repo" ]; then
        echo "ERROR: custom_node assets require a git repository in 'repo'."
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "ERROR: git is not installed."
        exit 1
    fi

    mkdir -p "$target_dir"

    if [ -z "$repo_name" ]; then
        repo_name="$(basename "$repo" .git)"
    fi

    local install_path="$target_dir/$repo_name"

    if [ -d "$install_path" ]; then
        echo "✓ Already exists"
        return 0
    fi

    echo "Cloning custom node..."
    git clone --depth 1 "$repo" "$install_path"
    echo "✓ Custom node installed"
}

ASSET_COUNT=$(yq '.assets | length' "$MANIFEST")

for ((i=0; i<ASSET_COUNT; i++)); do

    NAME=$(yq -r ".assets[$i].name" "$MANIFEST")
    TYPE=$(yq -r ".assets[$i].type" "$MANIFEST")
    PROVIDER=$(yq -r ".assets[$i].provider" "$MANIFEST")
    REPO=$(yq -r ".assets[$i].repo" "$MANIFEST")
    DESTINATION=$(yq -r ".assets[$i].destination" "$MANIFEST")
    CHECK=$(yq -r ".assets[$i].check" "$MANIFEST")
    FILE=$(yq -r ".assets[$i].file // \"\"" "$MANIFEST")

    MODEL_DIR="$COMFY_HOME/models/$DESTINATION"
    CHECK_FILE="$MODEL_DIR/$CHECK"

    echo "----------------------------------------"
    echo "Asset:       $NAME"
    echo "Type:        $TYPE"
    echo "Provider:    $PROVIDER"
    echo "Repository:  $REPO"
    if [ -n "$DESTINATION" ] && [ "$DESTINATION" != "null" ]; then
        echo "Destination: $MODEL_DIR"
    fi
    echo "----------------------------------------"

    if [ "$TYPE" = "custom_node" ] || [ "$PROVIDER" = "git" ]; then
        TARGET_NAME="${CHECK:-${FILE:-$(basename "$REPO" .git)}}"
        if [ -d "$COMFY_HOME/custom_nodes/$TARGET_NAME" ]; then
            echo "✓ Already exists"
            echo
            continue
        fi
        install_custom_node "$REPO" "$TARGET_NAME"
        echo
        continue
    fi

    mkdir -p "$MODEL_DIR"

    # ----------------------------------------------
    # Already installed
    # ----------------------------------------------

    if [ -f "$CHECK_FILE" ]; then
        echo "✓ Already exists"
        echo
        continue
    fi

    case "$PROVIDER" in
    huggingface)

        if ! command -v hf >/dev/null 2>&1; then
            echo "ERROR: Hugging Face CLI (hf) is not installed."
            exit 1
        fi

        echo "Downloading..."

        if [ -n "$FILE" ]; then

            hf download \
                "$REPO" \
                "$FILE" \
                --local-dir "$MODEL_DIR"

        else

            hf download \
                "$REPO" \
                --local-dir "$MODEL_DIR"

        fi

        echo "✓ Download completed"
        echo

        ;;

    civitai)

        if ! command -v curl >/dev/null 2>&1; then
            echo "ERROR: curl is not installed."
            exit 1
        fi

        if [ -z "${CIVITAI_TOKEN:-}" ]; then
            echo "ERROR: CIVITAI_TOKEN is required for CivitAI assets."
            exit 1
        fi

        if [ -z "$REPO" ]; then
            echo "ERROR: CivitAI assets require a download URL in 'repo'."
            exit 1
        fi

        OUTPUT_FILE="${FILE:-$CHECK}"
        TEMP_FILE="$MODEL_DIR/.${OUTPUT_FILE}.download"

        echo "Downloading..."

        curl --fail --location --retry 3 \
            -H "Authorization: Bearer $CIVITAI_TOKEN" \
            "$REPO" \
            --output "$TEMP_FILE"

        mv "$TEMP_FILE" "$MODEL_DIR/$OUTPUT_FILE"

        echo "✓ Download completed"
        echo

        ;;

    *)

        echo "ERROR: Unsupported provider: $PROVIDER"
        exit 1

        ;;
    esac

done

echo "========================================"
echo " Workflow installation complete"
echo "========================================"
echo
echo "Workflow: $WORKFLOW_NAME"
echo
