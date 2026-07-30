#!/bin/bash
set -e 
COMFY_HOME="/workspace/runpod-slim/ComfyUI" 
MODEL_DIR="$COMFY_HOME/models/clip" 
MODEL_FILE="$MODEL_DIR/t5xxl_fp8_e4m3fn.safetensors" 
echo "$MODEL_FILE"
mkdir -p "$MODEL_DIR" 
if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading..." hf download \ comfyanonymous/flux_text_encoders \ t5xxl_fp8_e4m3fn.safetensors \ --local-dir "$MODEL_DIR" else echo "Already exists."
fi
