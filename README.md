# Container My Pi Docker

A modular, multi‑variant Docker build system for [Oh My Pi (OMP)](https://github.com/can1357/oh-my-pi) — a terminal‑native AI coding agent.

## 🌟 System Overview

Container My Pi Docker delivers a **reproducible, minimal, and secure** foundation for development, CI, and home‑lab use.

The entire build system is driven by a modular approach centered on `build_config.yaml`, which serves as the single source of truth for defining all image variants, their required tools, and tags.

*   **`Dockerfile`**: Defines the multi-stage build logic (builder and runtime) to ensure minimal image size.
*   **`build_config.yaml`**: The centralized configuration file defining the full image build matrix.
*   **`build.sh`**: The orchestration script that reads `build_config.yaml`, computes the build matrix, and executes the Docker builds.

### System Design Principles
Our design focuses on reliability and security:
*   **Minimal Overhead**: Final runtime images contain only the strictly required artifacts.
*   **Security**: Utilizes two‑stage builds and runs containers as a non‑root `pi` user to reduce the attack surface.
*   **Flexibility**: Supports easy addition of variants for specialized toolchains (`kubectl`, `dotnet`, etc.).

### Architecture Flow
The build process follows a deterministic path:
build_config.yaml (defines variants and steps) $\rightarrow$ build.sh (orchestration, converts steps and tests to RUN commands) $\rightarrow$ Dockerfile (multi-stage image generation) $\rightarrow$ Image artifacts
# 🚀 Quickstart

This guide provides a clear, sequential workflow for setting up and running Container My Pi.

### ⚙️ Step 1: Prerequisites

Before starting, ensure the following dependencies are met:

1. Docker or Podman is installed and running.
2. Bash is available to run the build script.
3. `yq` and `jq` are recommended for local variant inspection (the build script checks for it).

### 🏗️ Step 2: Building Variants

To build a specific image variant, use `build.sh`. This script orchestrates the Docker build process using the configuration in `build_config.yaml`.

**Example (Standard Variant):**

```bash
# Build the 'standard' variant
./build.sh standard
```

You can build other defined variants by replacing `standard` with their name (e.g., `kubectl-tools`, `dotnet-dev`).

### ▶️ Step 3: Running the Image

Once the image is built (e.g., `container-my-pi-standard:latest`), you can run it using `podman run`.

**Example Run Command:**

```bash
podman run --rm -it \
  -e LLAMA_CPP_BASE_URL=<our llama.cpp server url> \
  -e LLAMA_CPP_API_KEY="" \
  -v "$(pwd):/workspace:z" \
  -v "$(pwd)/.omp:/home/pi/.omp" \
  --userns=keep-id \
  container-my-pi-standard:a5552ef
```

or for an existing image

```bash
 podman run --rm -it \
  -e LLAMA_CPP_BASE_URL=<our llama.cpp server url>  \
  -e LLAMA_CPP_API_KEY="" \
  -v "$(pwd):/workspace:z" \
  -v "$(pwd)/.omp:/home/pi/.omp" \
  --userns=keep-id \
  ghcr.io/whitebahamut/container-my-pi/container-my-pi-standard:a5552ef
```


### Image Naming Convention

The standard image naming format is:
```
container-my-pi-<variant-name>:<tag>
```

`build_config.yaml` is the single source of truth for all image configurations. Each variant entry must define:

**Structure of `build_config.yaml`:**

### ⚙️ Example `build_config.yaml`

The configuration is a list of variants, each defining its name, tag, and required steps:

```yaml
variants:
  - name: standard
    description: Core environment with essential utilities
    steps:
      - dnf install -y wget vim
    tests:
      - curl --version
  - name: kubectl-tools
    description: Kubernetes CLI and cluster management tools
    steps:
      - dnf install -y kubectl
    tests:
      - kubectl version --client
```

The file is a YAML list of variant objects. Each object must include:

*   **`name`**: (string) A unique, lowercase identifier used by `build.sh` (e.g., `standard`, `kubectl-tools`).
*   **`description`**: (string) A short, human-readable purpose of the variant.
*   **`steps`**: (list[string]) A list of shell commands or tool identifiers. These steps are executed during the Docker build process to install required dependencies (e.g., `dnf install -y wget`). Multiline yaml is possible.
*   **`tests`**: (list[string]) A list of shell commands to test the image (e.g. simple `curl --version`). These steps are executed during the Docker build process _after_ the steps have been executed. Multiline yaml is possible.

**Usage:**

1. **Define**: Add or modify an object in `build_config.yaml` to define a new variant.
2. **Build**: Run `./build.sh [variant name from config]` to generate the corresponding image.

For detailed dependency management, refer to the `tools` list in the respective variant's configuration.


### Testing and Validation

Manual validation, which involves running the produced container and verifying tool functionality, is necessary for full integration testing.


## 🤝 Contributing and Governance

### How to Contribute

* Open an issue
* for feature requests or bug reports.  
  **Note:** Issues and PRs are reviewed **infrequently** and often in batches, so response times may vary.
* Submit pull requests with a clear description and tests where applicable.  
  PRs may remain open until the next review cycle.
* Follow conventional commits to support automated changelog generation.



### Code of Conduct
Be respectful and constructive. Follow the repository’s code of conduct.

## License

MIT. See [LICENSE](LICENSE).