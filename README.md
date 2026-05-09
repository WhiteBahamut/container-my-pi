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
The process follows this path:
`build_config.yaml` (variants) $\rightarrow$ `build.sh` (orchestration) $\rightarrow$ `Dockerfile` (multi-stage) $\rightarrow$ Image artifacts

## 🚀 Quickstart

### Prerequisites

*   Docker installed and running.
*   Bash available to run the build script.
*   `yq` recommended for local variant inspection (the build script checks for it).

### Building Variants

**Build a single variant:**

To build a specific image variant, pass its name as an argument to the script:

```bash
# Build the 'standard' variant
./build.sh standard
```

Then run the image

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

The file is a YAML list of variant objects. Each object must include:

*   **`name`**: (string) A unique, lowercase identifier used by `build.sh` (e.g., `standard`, `kubectl-tools`).
*   **`tag`**: (string) The image tag to use when building this variant (e.g., `latest`, `k8s`).
*   **`description`**: (string) A short, human-readable purpose of the variant.
*   **`steps`**: (list[string]) A list of shell commands or tool identifiers. These steps are executed during the Docker build process to install required dependencies (e.g., `dnf install -y wget`). Multiline yaml is possible.

**Usage:**

1. **Define**: Add or modify an object in `build_config.yaml` to define a new variant.
2. **Build**: Run `./build.sh [name_from_config]` to generate the corresponding image.

For detailed dependency management, refer to the `tools` list in the respective variant's configuration.

### Recommended Variant Table

| Variant | Tag | Purpose |
| :--- | :--- | :--- |
| `standard` | `latest` | Core environment with essential utilities |
| `kubectl-tools` | `k8s` | Kubernetes CLI and cluster management tools |
| `dotnet-dev` | `dotnet` | Full .NET SDK for development |

*   Keep each variant focused and minimal.
*   Prefer scripted, idempotent install steps.
*   Pin versions for deterministic builds.

### Testing and Validation

While CI/CD handles automated checks, manual validation is necessary for integration testing.

**Run Unit Tests:**
```bash
./test.sh
```



## 🤝 Contributing and Governance

### How to Contribute

*   Open an issue for feature requests or bugs.
*   Submit pull requests with a clear description and tests where applicable.
*   Follow conventional commits for changelog automation.


### Code of Conduct
Be respectful and constructive. Follow the repository’s code of conduct.

## License

MIT. See [LICENSE](LICENSE).