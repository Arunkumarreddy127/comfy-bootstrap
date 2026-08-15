# comfy-bootstrap

Bootstrap model assets into a ComfyUI installation from Hugging Face or CivitAI.

## Requirements

- `yq`
- Hugging Face CLI (`hf`) for Hugging Face assets
- `curl` for CivitAI assets
- Access to a ComfyUI installation

Set `COMFY_HOME` when ComfyUI is not at the default path:

```sh
export COMFY_HOME=/workspace/runpod-slim/ComfyUI
```

Credentials can be loaded from a local `.env` file. Copy `.env.example` to `.env` and fill in the tokens. The `.env` file is ignored by Git and must not be committed:

```sh
cp .env.example .env
```

The installer loads `.env` automatically. You can use another file by setting `ENV_FILE=/path/to/file.env`. Explicit `HF_TOKEN` or `CIVITAI_TOKEN` environment variables take precedence over values in `.env`. The Hugging Face CLI also supports its normal login configuration. `CIVITAI_TOKEN` is required only when installing a CivitAI asset.

## Usage

```sh
./workflow list
./workflow install qwen-test
```

Each workflow is defined by `workflows/<name>/manifest.yaml`. Hugging Face assets use the repository name in `repo`; CivitAI assets use a CivitAI download URL in `repo` and should provide the destination filename in `file`.
