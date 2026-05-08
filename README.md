# Oh My Pi Docker Build System

[![Build Status](https://img.shields.io/badge/Build-passing-brightgreen)](LINK_TO_CI)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)](CHANGELOG.md)

## ✨ Overview

## 🧩 Core Components
The OMP project is structured around three core files that define and execute the container build system:

*   `Dockerfile`: Defines the low-level multi-stage Docker build process. It specifies the base images, the builder stage for installing dependencies, and the minimal runtime stage for execution.
*   `build_config.yaml`: Acts as the single source of truth for image variants. It defines the purpose, tags, and required tools for every specialized image (e.g., `standard`, `kubectl-tools`).
*   `build.sh`: The orchestration script. It reads `build_config.yaml`, iterates over all defined variants, and executes the necessary Docker builds according to the configuration.

[Oh My Pi (OMP)](https://github.com/can1357/oh-my-pi) is a **terminal‑native AI coding agent** built for fast, precise, and reliable development workflows. Unlike simple chat wrappers, OMP provides a complete agent runtime with:

- **[Hash‑anchored edits](ca://s?q=Explain_hash_anchored_edits)** for exact, low‑token code manipulation  
- **[Multi‑provider LLM support](ca://s?q=Explain_multi_model_support_in_OMP)** through a unified streaming interface  
- **A powerful tool harness** (file ops, shell execution, LSP, Python, browser automation, sub‑agents)  
- **Session persistence** with branching, compaction, and long‑running context management  
- **Extensibility** via custom tools, slash commands, and MCP servers  

This repository adds a **flexible, multi‑variant Docker build system** that produces minimal, specialized container images tailored to specific operational needs. Each variant is purpose‑built, ensuring:

- **Minimal overhead**  
- **Maximum security**  
- **Only the required tools included** (e.g., `kubectl`, `helm`, `dotnet-sdk`)  
- **Reproducible builds** suitable for home‑lab, CI, and development environments  

Together, OMP’s advanced agent capabilities and this modular container architecture create a **high‑performance, customizable AI‑powered development environment** that integrates cleanly into modern workflows.

---

## 💡 Key Features

Beyond the dynamic image build system, OMP includes a powerful **AI‑powered Commit Tool** that elevates repository hygiene and commit quality:

- **Intelligent Change Analysis**: Uses specialized git inspection tools (`git-overview`, `git-file-diff`, `git-hunk`) to deeply understand change context.  
- **[Atomic Committing](ca://s?q=Explain_atomic_commits)**: Automatically splits unrelated changes into isolated commits with correct dependency ordering.  
- **Fine‑Grained Staging**: Supports staging individual hunks when changes span multiple logical concerns.  
- **Changelog Automation**: Generates structured entries for `CHANGELOG.md`.  
- **Commit Validation**: Enforces conventional commit format and flags filler/meta‑phrases.  
- **Usage**: Run via `omp commit` with options such as `--push` or `--dry-run`.

---

## 🏗️ Build System Architecture

This repository employs a highly modular, multi-variant Docker build system designed for high reliability and security. The system is orchestrated through three key components:

*   `Dockerfile`: Defines the multi-stage build logic (builder and runtime), specifying how dependencies are installed and how the final, minimal image is constructed.
*   `build_config.yaml`: Functions as the single source of truth, defining all available image variants, their required tools, and associated tags.
*   `build.sh`: The orchestration script that reads `build_config.yaml`, dynamically determines the build matrix, and executes the Docker build process against the logic in `Dockerfile`.

```ascii
[ build_config.yaml (Variants) ]
       |
       v
[ build.sh (Orchestration) ] ---> [ Dockerfile (Multi-Stage Logic) ]
       |                 |
       +-----> [ Image Artifacts (e.g., standard, dotnet-dev) ]
```

### ⚙️ Two-Stage Build Process

1. **Builder Stage (`builder`)**: This initial stage installs all necessary system dependencies, including `bash`, `curl`, `jq`, `git`, and the `bun` package manager. It also installs the core Oh My Pi Agent (`@oh-my-pi/pi-coding-agent`) within the non-root `pi` user.
2. **Runtime Stage (`runtime`)**: This final, minimal stage is designed for execution. It starts from the same `fedora:44` base image but only copies essential artifacts (like the Bun installation) from the builder stage. This ensures the final image contains *only* the runtime environment and necessary tools, dramatically reducing attack surface and image size.

### 🛠️ Variant Configuration (`build_config.yaml`)

The `build_config.yaml` file serves as the **single source of truth** for all image variants. Each variant defines a specific purpose, an image `tag`, and a list of required tool installations.

Examples of available variants include:

* **`standard`**: The core environment, including essential utilities for general development.
* **`kubectl-tools`**: Includes specialized Kubernetes utilities (e.g., `kubectl`) for cluster management.
* **`dotnet-dev`**: Includes the full .NET SDK for development tasks.

The build script dynamically reads this file to determine which tools and commands need to be executed for each variant.
---

## 🚀 Usage and Execution Flow

The entire build process is orchestrated by the `build.sh` script, which manages the building of specific, named image variants based on configuration.

### Step-by-Step Execution

1. **Check Dependencies**: `build.sh` verifies necessary dependencies (`yq`, `docker`).
2. **Variant Discovery**: The script uses `yq` to parse `build_config.yaml` and extract all defined variants.
3. **Build Loop**: It iterates through the configured variants and executes the Docker build command for each one, applying the specific tool installation commands defined for that variant.
4. **Image Output**: Upon completion, images are named using the convention:

`oh-my-pi-<variant-name>:<tag>`

### Prerequisites

Ensure the following are installed:

* **Docker** — container runtime
* **Bash** — execution environment for the build script

### Building a image

To build a specific image variant, run:

```bash
./build.sh <variant_name>
```