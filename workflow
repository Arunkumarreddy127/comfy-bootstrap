#!/bin/bash
set -euo pipefail

COMMAND="${1:-}"
WORKFLOW_NAME="${2:-}"
ASSET_NAME="${3:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
export ENV_FILE

set_comfy_home() {
    local target="$1"
    local comfy_home=""

    case "$target" in
        local)
            comfy_home="/test-downloads"
            ;;
        contabo)
            comfy_home="/root/contabo/ComfyUI"
            ;;
        runpod)
            comfy_home="/workspace/runpod-slim/ComfyUI"
            ;;
        *)
            echo "ERROR: Unknown target '$target'."
            echo "Choose one of: local, contabo, runpod"
            exit 1
            ;;
    esac

    mkdir -p "$(dirname "$ENV_FILE")"
    if [ -f "$ENV_FILE" ]; then
        awk -v comfy_home="$comfy_home" '
            BEGIN { updated = 0 }
            /^COMFY_HOME=/ {
                if (!updated) {
                    print "COMFY_HOME=" comfy_home
                    updated = 1
                }
                next
            }
            { print }
            END {
                if (!updated) print "COMFY_HOME=" comfy_home
            }
        ' "$ENV_FILE" > "$ENV_FILE.tmp"
        mv "$ENV_FILE.tmp" "$ENV_FILE"
    else
        printf 'COMFY_HOME=%s\n' "$comfy_home" > "$ENV_FILE"
    fi

    echo "COMFY_HOME set to: $comfy_home"
}

require_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq is not installed."
        echo "Install it with your operating system's package manager."
        exit 1
    fi
}

list_models() {
    require_yq

    echo "Available models:"
    echo
    yq -r '.models[] | "\(.name)    ./workflow install-model \(.name)"' "$REPO_ROOT/assets/models.yaml"
}

list_custom_nodes() {
    require_yq

    echo "Available custom nodes:"
    echo
    yq -r '.custom_nodes[] | "\(.name)    ./workflow install-node \(.name)"' "$REPO_ROOT/assets/custom_nodes.yaml"
}

case "$COMMAND" in

    setup)

        "$REPO_ROOT/setup.sh"
        ;;

    set)

        if [ -z "$WORKFLOW_NAME" ]; then
            echo "Usage:"
            echo "  ./workflow set local|contabo|runpod"
            exit 1
        fi

        set_comfy_home "$WORKFLOW_NAME"
        ;;

    install)

        if [ -z "$WORKFLOW_NAME" ]; then
            echo "Usage:"
            echo "  ./workflow install <workflow>"
            exit 1
        fi

        case "$WORKFLOW_NAME" in
            model|models)
                if [ -z "$ASSET_NAME" ]; then
                    echo "Usage: ./workflow install model <model>"
                    exit 1
                fi
                "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/assets/models.yaml" model "$ASSET_NAME"
                exit 0
                ;;
            custom_node|custom_nodes|node)
                if [ -z "$ASSET_NAME" ]; then
                    echo "Usage: ./workflow install custom_node <custom-node>"
                    exit 1
                fi
                "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/assets/custom_nodes.yaml" custom_node "$ASSET_NAME"
                exit 0
                ;;
        esac

        MANIFEST="$REPO_ROOT/workflow-scripts/$WORKFLOW_NAME/manifest.yaml"

        if [ ! -f "$MANIFEST" ]; then
            echo "ERROR: Workflow '$WORKFLOW_NAME' not found."
            echo
            echo "Available workflows:"

            find "$REPO_ROOT/workflow-scripts" \
                -mindepth 1 \
                -maxdepth 1 \
                -type d \
                -exec basename {} \;

            exit 1
        fi

        "$REPO_ROOT/scripts/install.sh" "$MANIFEST"
        ;;

    install-model)

        if [ -z "$WORKFLOW_NAME" ]; then
            echo "Usage:"
            echo "  ./workflow install-model <model>"
            exit 1
        fi

        "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/assets/models.yaml" model "$WORKFLOW_NAME"
        ;;

    install-node)

        if [ -z "$WORKFLOW_NAME" ]; then
            echo "Usage:"
            echo "  ./workflow install-node <custom-node>"
            exit 1
        fi

        "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/assets/custom_nodes.yaml" custom_node "$WORKFLOW_NAME"
        ;;

    list)

        case "$WORKFLOW_NAME" in
            model|models)
                list_models
                exit 0
                ;;
            custom_node|custom_nodes|node|nodes)
                list_custom_nodes
                exit 0
                ;;
        esac

        echo "Available workflows:"
        echo

        find "$REPO_ROOT/workflow-scripts" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -exec basename {} \; \
            | while IFS= read -r workflow_name; do
                printf '%s    ./workflow install %s\n' "$workflow_name" "$workflow_name"
            done
        ;;

    list-models|list-model)

        list_models
        ;;

    list-custom-nodes|list-nodes)

        list_custom_nodes
        ;;

    *)

        echo "Usage:"
        echo
        echo "  ./workflow setup"
        echo "  ./workflow set local|contabo|runpod"
        echo "  ./workflow install <workflow>"
        echo "  ./workflow install-model <model>"
        echo "  ./workflow install-node <custom-node>"
        echo "  ./workflow list"
        echo "  ./workflow list-models"
        echo "  ./workflow list-custom-nodes"
        echo
        echo "Examples:"
        echo "  ./workflow install qwen-test"
        echo "  ./workflow install-model dreamshaper-xl"
        echo "  ./workflow install-node comfyui-pixaroma"
        echo "  ./workflow list"
        exit 1
        ;;

esac
