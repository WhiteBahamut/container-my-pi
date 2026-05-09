# Container My Pi Docker

A modular, multi‑variant Docker build system for [Oh My Pi (OMP)](https://github.com/can1357/oh-my-pi) — a terminal‑native AI coding agent.

## 🌟 System Overview

Container My Pi Docker delivers a **reproducible, minimal, and secure** foundation for development, CI, and home‑lab use. This architecture is driven by a modular approach:

*   **`Dockerfile`**: Defines the multi-stage build logic (builder and runtime) to ensure minimal image size.
*   **`build_config.yaml`**: The single source of truth, defining all image variants, their required tools, and tags.
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
```bash
# Build the 'standard' variant
./build.sh standard
```

### Image Naming Convention

The standard image naming format is:
```
oh-my-pi-<variant-name>:<tag>
```

## ⚙️ Configuration and Variants

`build_config.yaml` is the single source of truth for all image configurations. Each variant entry must define:

*   **`name`**: Variant identifier used by `build.sh`.
*   **`tag`**: Image tag.
*   **`tools`**: List of tools or install steps required for that variant.
*   **`description`**: Short, human-readable purpose.

### Recommended Variant Table

| Variant | Tag | Purpose |
| :--- | :--- | :--- |
| `standard` | `latest` | Core environment with essential utilities |
| `kubectl-tools` | `k8s` | Kubernetes CLI and cluster management tools |
| `dotnet-dev` | `dotnet` | Full .NET SDK for development |

### Best Practices
*   Keep each variant focused and minimal.
*   Prefer scripted, idempotent install steps.
*   Pin versions for deterministic builds.
*   Use build args and labels for metadata (e.g., `org.opencontainers.image.revision`).

## 🤝 Contributing and Governance

### How to Contribute
*   Open an issue for feature requests or bugs.
*   Submit pull requests with a clear description and tests where applicable.
*   Follow conventional commits for changelog automation.

### Repository Layout
*   **`Dockerfile`**: Multi‑stage build.
*   **`build_config.yaml`**: Variant definitions.
*   **`build.sh`**: Orchestration script.
*   **`CHANGELOG.md`**: Release notes.
*   **`LICENSE`**: MIT license.

### Code of Conduct
Be respectful and constructive. Follow the repository’s code of conduct.

## License

MIT. See [LICENSE](LICENSE).