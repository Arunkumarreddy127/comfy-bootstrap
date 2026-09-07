# comfy-bootstrap

Install ComfyUI models and custom nodes from reusable catalogs, or install all
assets required by a workflow.

## Requirements

- A ComfyUI installation
- `yq`
- Hugging Face CLI (`hf`) for Hugging Face assets
- `curl` for CivitAI assets
- `git` for custom nodes

Install `yq` with your platform's package manager. For example:

```sh
# macOS
brew install yq

# Debian or Ubuntu
sudo apt-get update
sudo apt-get install -y yq
```

The repository's setup helper installs `yq` on Debian-based systems:

```sh
sudo ./workflow setup
```

On macOS, use Homebrew or another system package manager instead.

## Configure the target

Choose where assets should be installed:

```sh
./workflow set local
./workflow set contabo
./workflow set runpod
./workflow set vastai
```

The target paths are:

| Target    | `COMFY_HOME`                     |
| --------- | -------------------------------- |
| `local`   | `/test-downloads`                |
| `contabo` | `/root/contabo/ComfyUI`          |
| `runpod`  | `/workspace/runpod-slim/ComfyUI` |
| `vastai`  | `/workspace/ComfyUI`             |

The selected value is saved in `.env` and used by later installs.

## Credentials

Copy the example environment file when credentials are needed:

```sh
cp .env.example .env
```

The installer loads `.env` automatically. You can use a different file with
`ENV_FILE`:

```sh
ENV_FILE=/path/to/file.env ./workflow install <workflow>
```

`HF_TOKEN` may be provided through the environment or the Hugging Face CLI's
normal login configuration. `CIVITAI_TOKEN` is required for CivitAI downloads.
Explicit environment variables take precedence over values from `.env`.

## Workflows

List available workflow manifests with their copyable install commands:

```sh
./workflow list
```

Each workflow is printed beside a command in this form:

```text
minimax-h3    ./workflow install minimax-h3
```

Install one workflow and all of its referenced models and custom nodes:

```sh
./workflow install minimax-h3
```

Workflow manifests live in `workflow-scripts/<name>/manifest.yaml`. A workflow
contains asset names, not duplicated asset definitions:

```yaml
name: minimax-h3
description: MiniMax H3 text-to-video workflow with Pixaroma nodes

models:
  - minimax-h3-diffusion
  - qwen3vl-32b-minimax-h3

custom_nodes:
  - comfyui-pixaroma
```

## Models

Reusable model definitions live in `assets/models.yaml`. List models with their
copyable install commands:

```sh
./workflow list-models
./workflow list-model
./workflow list models
```

Each entry is printed beside a command in this form:

```text
dreamshaper-xl    ./workflow install-model dreamshaper-xl
```

Install one model without installing a complete workflow:

```sh
./workflow install-model dreamshaper-xl
```

The generic equivalent is:

```sh
./workflow install model dreamshaper-xl
```

Each model entry identifies its provider, repository, destination directory,
and installed-file check:

```yaml
models:
  - name: dreamshaper-xl
    type: model
    provider: huggingface
    repo: Lykon/DreamShaper
    file: DreamShaperXL1.0Alpha2_fixedVae_half_00001_.safetensors
    destination: checkpoints
    check: DreamShaperXL1.0Alpha2_fixedVae_half_00001_.safetensors
```

Hugging Face entries use `repo` as the repository name. CivitAI entries use a
download URL in `repo` and should provide the destination filename in `file`.

## Custom nodes

List reusable custom nodes with their copyable install commands:

```sh
./workflow list-custom-nodes
./workflow list-nodes
./workflow list custom_nodes
```

Each entry is printed beside a command in this form:

```text
comfyui-pixaroma    ./workflow install-node comfyui-pixaroma
```

Install one custom node:

```sh
./workflow install-node comfyui-pixaroma
```

The generic equivalent is:

```sh
./workflow install custom_node comfyui-pixaroma
```

Custom-node definitions live in `assets/custom_nodes.yaml` and use Git
repositories:

```yaml
custom_nodes:
  - name: comfyui-pixaroma
    type: custom_node
    provider: git
    repo: https://github.com/pixaroma/ComfyUI-Pixaroma.git
    check: ComfyUI-Pixaroma
```

Repositories are cloned into `COMFY_HOME/custom_nodes`. Existing target
directories are skipped.

## Repository layout

```text
assets/
  models.yaml
  custom_nodes.yaml
workflow-scripts/
  <workflow>/manifest.yaml
workflows/
  ComfyUI workflow JSON files
scripts/install.sh
workflow
```
