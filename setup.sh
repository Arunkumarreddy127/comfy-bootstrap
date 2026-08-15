#!/bin/bash
set -euo pipefail

if command -v yq >/dev/null 2>&1; then
    echo "yq is already installed: $(yq --version)"
    exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: yq is not installed and apt-get is unavailable."
    echo "Install yq with your operating system's package manager."
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Installing yq requires root privileges."
    echo "Run this command as root or with sudo:"
    echo "  sudo ./setup.sh"
    exit 1
fi

echo "Installing yq..."
apt-get update
apt-get install -y yq

echo "yq installed: $(yq --version)"