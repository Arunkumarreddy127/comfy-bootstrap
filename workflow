#!/bin/bash
set -euo pipefail

COMMAND="${1:-}"
WORKFLOW_NAME="${2:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$COMMAND" in

    install)

        if [ -z "$WORKFLOW_NAME" ]; then
            echo "Usage:"
            echo "  ./workflow install <workflow>"
            exit 1
        fi

        MANIFEST="$REPO_ROOT/workflows/$WORKFLOW_NAME/manifest.yaml"

        if [ ! -f "$MANIFEST" ]; then
            echo "ERROR: Workflow '$WORKFLOW_NAME' not found."
            echo
            echo "Available workflows:"

            find "$REPO_ROOT/workflows" \
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

        find "$REPO_ROOT/workflows" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -exec basename {} \;
        ;;

    *)

        echo "Usage:"
        echo
        echo "  ./workflow install <workflow>"
        echo "  ./workflow list"
        echo
        echo "Examples:"
        echo "  ./workflow install qwen-test"
        echo "  ./workflow list"
        exit 1
        ;;

esac
