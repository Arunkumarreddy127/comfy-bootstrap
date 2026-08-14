#!/bin/bash
set -euo pipefail

COMFY_HOME="${COMFY_HOME:-/workspace/runpod-slim/ComfyUI}"

MANIFEST="$1"

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

if ! command -v hf >/dev/null 2>&1; then
    echo "ERROR: Hugging Face CLI (hf) is not installed."
    exit 1
fi

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
    echo "Destination: $MODEL_DIR"
    echo "----------------------------------------"

    mkdir -p "$MODEL_DIR"

    # ----------------------------------------------
    # Already installed
    # ----------------------------------------------

    if [ -f "$CHECK_FILE" ]; then
        echo "✓ Already exists"
        echo
        continue
    fi

    # ----------------------------------------------
    # Hugging Face
    # ----------------------------------------------

    if [ "$PROVIDER" = "huggingface" ]; then

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

    else

        echo "ERROR: Unsupported provider: $PROVIDER"
        exit 1

    fi

done

echo "========================================"
echo " Workflow installation complete"
echo "========================================"
echo
echo "Workflow: $WORKFLOW_NAME"
echo
