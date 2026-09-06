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
ASSET_TYPE="${2:-workflow}"
ASSET_NAME="${3:-}"
MODELS_CATALOG="${MODELS_CATALOG:-$REPO_ROOT/assets/models.yaml}"
CUSTOM_NODES_CATALOG="${CUSTOM_NODES_CATALOG:-$REPO_ROOT/assets/custom_nodes.yaml}"

if [ -z "$MANIFEST" ]; then
    echo "ERROR: Manifest is required."
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest not found: $MANIFEST"
    exit 1
fi

if [ ! -f "$MODELS_CATALOG" ]; then
    echo "ERROR: Model catalog not found: $MODELS_CATALOG"
    exit 1
fi

if [ ! -f "$CUSTOM_NODES_CATALOG" ]; then
    echo "ERROR: Custom-node catalog not found: $CUSTOM_NODES_CATALOG"
    exit 1
fi

echo
echo "========================================"
echo " Installing assets"
echo "========================================"
echo "ComfyUI: $COMFY_HOME"
echo "Manifest: $MANIFEST"
if [ "$ASSET_TYPE" != "workflow" ]; then
    echo "Asset:    $ASSET_NAME ($ASSET_TYPE)"
fi
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

if [ "$ASSET_TYPE" = "workflow" ]; then
    WORKFLOW_NAME=$(yq -r '.name' "$MANIFEST")
    WORKFLOW_DESCRIPTION=$(yq -r '.description // ""' "$MANIFEST")
else
    if [ -z "$ASSET_NAME" ]; then
        echo "ERROR: Asset name is required."
        exit 1
    fi
    WORKFLOW_NAME="$ASSET_NAME"
    WORKFLOW_DESCRIPTION=""
fi

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

install_asset() {
    local source_manifest="$1"
    local asset_path="$2"
    local NAME TYPE PROVIDER REPO DESTINATION CHECK FILE OUTPUT

    NAME=$(yq -r "$asset_path | .name // \"\"" "$source_manifest")
    if [ -z "$NAME" ]; then
        echo "ERROR: Asset was not found in catalog."
        exit 1
    fi
    TYPE=$(yq -r "$asset_path | .type" "$source_manifest")
    PROVIDER=$(yq -r "$asset_path | .provider" "$source_manifest")
    REPO=$(yq -r "$asset_path | .repo" "$source_manifest")
    DESTINATION=$(yq -r "$asset_path | .destination // \"\"" "$source_manifest")
    CHECK=$(yq -r "$asset_path | .check // \"\"" "$source_manifest")
    FILE=$(yq -r "$asset_path | .file // \"\"" "$source_manifest")
    OUTPUT=$(yq -r "$asset_path | .output // \"\"" "$source_manifest")

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
            return 0
        fi
        install_custom_node "$REPO" "$TARGET_NAME"
        echo
        return 0
    fi

    mkdir -p "$MODEL_DIR"

    # ----------------------------------------------
    # Already installed
    # ----------------------------------------------

    if [ -f "$CHECK_FILE" ]; then
        echo "✓ Already exists"
        echo
        return 0
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

            if [ -n "$OUTPUT" ]; then
                mv "$MODEL_DIR/$FILE" "$MODEL_DIR/$OUTPUT"
                rmdir -p "$(dirname "$MODEL_DIR/$FILE")" 2>/dev/null || true
            fi

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
}

if [ "$ASSET_TYPE" = "workflow" ]; then
    for TYPE in models custom_nodes; do
        if [ "$TYPE" = "models" ]; then
            SOURCE_CATALOG="$MODELS_CATALOG"
        else
            SOURCE_CATALOG="$CUSTOM_NODES_CATALOG"
        fi
        while IFS= read -r ASSET_NAME; do
            [ -z "$ASSET_NAME" ] && continue
            install_asset "$SOURCE_CATALOG" ".${TYPE}[] | select(.name == \"$ASSET_NAME\")"
        done < <(yq -r ".${TYPE}[]? // empty" "$MANIFEST")
    done
else
    case "$ASSET_TYPE" in
        model|models)
            SOURCE_CATALOG="$MODELS_CATALOG"
            ASSET_PATH=".models[] | select(.name == \"$ASSET_NAME\")"
            ;;
        custom_node|custom_nodes|node)
            SOURCE_CATALOG="$CUSTOM_NODES_CATALOG"
            ASSET_PATH=".custom_nodes[] | select(.name == \"$ASSET_NAME\")"
            ;;
        *)
            echo "ERROR: Unsupported asset type: $ASSET_TYPE"
            exit 1
            ;;
    esac
    install_asset "$SOURCE_CATALOG" "$ASSET_PATH"
fi

echo "========================================"
echo " Workflow installation complete"
echo "========================================"
echo
echo "Workflow: $WORKFLOW_NAME"
echo
