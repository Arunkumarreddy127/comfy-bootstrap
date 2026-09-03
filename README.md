# comfy-bootstrap

Bootstrap model assets into a ComfyUI installation from Hugging Face or CivitAI.

## Requirements

- `yq`
- Hugging Face CLI (`hf`) for Hugging Face assets
- `curl` for CivitAI assets
- Access to a ComfyUI installation

Select the ComfyUI installation used by the installer:

```sh
./workflow set local
./workflow set contabo
./workflow set runpod
```

These set `COMFY_HOME` to `/test-downloads`, `/root/contabo/ComfyUI`, or `/workspace/runpod-slim/ComfyUI`, respectively. The selection is saved in `.env` and used by future installs.

Credentials can be loaded from a local `.env` file. Copy `.env.example` to `.env` and fill in the tokens. The `.env` file is ignored by Git and must not be committed:

```sh
cp .env.example .env
```

The installer loads `.env` automatically. You can use another file by setting `ENV_FILE=/path/to/file.env`. Explicit `HF_TOKEN` or `CIVITAI_TOKEN` environment variables take precedence over values in `.env`. The Hugging Face CLI also supports its normal login configuration. `CIVITAI_TOKEN` is required only when installing a CivitAI asset.

## Usage

```sh
./workflow setup
./workflow set runpod
./workflow list
./workflow install qwen-test
```

`./workflow setup` installs `yq` automatically with `apt-get` when it is missing. Run it as root or with sudo on Debian/Ubuntu/RunPod:

```sh
sudo ./workflow setup
```

On macOS or other systems without `apt-get`, install `yq` with the system package manager instead.

Each workflow script is defined by `workflow-scripts/<name>/manifest.yaml`. The ComfyUI workflow JSON files are in `workflows/`. Hugging Face assets use the repository name in `repo`; CivitAI assets use a CivitAI download URL in `repo` and should provide the destination filename in `file`.
