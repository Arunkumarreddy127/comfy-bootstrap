#!/bin/bash
set -e 

COMFY_HOME="/workspace/runpod-slim/ComfyUI" 
MODEL_DIR="$COMFY_HOME/models/qwen" 
MODEL_FILE="$MODEL_DIR/Qwen2.5-Coder-14B-Instruct" 

echo "$MODEL_FILE"

mkdir -p "$MODEL_DIR" 

if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading..."
   
 hf download \
     Qwen/Qwen2.5-Coder-14B-Instruct \
     --local-dir "$MODEL_DIR" 

else 
   echo "Already exists."
fi

echo "Done!"
