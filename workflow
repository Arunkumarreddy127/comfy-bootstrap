#!/bin/bash
set -euo pipefail

COMMAND="${1:-}"
WORKFLOW_NAME="${2:-}"

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

    list)

        echo "Available workflows:"
        echo

        find "$REPO_ROOT/workflow-scripts" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -exec basename {} \;
        ;;

    *)

        echo "Usage:"
        echo
        echo "  ./workflow setup"
        echo "  ./workflow set local|contabo|runpod"
        echo "  ./workflow install <workflow>"
        echo "  ./workflow list"
        echo
        echo "Examples:"
        echo "  ./workflow install qwen-test"
        echo "  ./workflow list"
        exit 1
        ;;

esac
