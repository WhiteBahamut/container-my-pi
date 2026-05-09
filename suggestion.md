# Workspace Review and Improvement Suggestions

This document provides a clear, step-by-step guide on how to improve the build system's reliability and maintainability. The changes are grouped by priority.

## 🛠️ Critical Architectural Gaps (High Priority)

### 1. Missing Build Templating Logic
**Goal**: Make the build process complete by automatically inserting the correct tool list into the Dockerfiles.
**Files Affected**: `Dockerfile`, `Dockerfile.ttyd`, `build_config.yaml`, `build.sh`.
**Step-by-Step Guide**:
1.  **In `build_config.yaml`**: Ensure each tool variant clearly lists all the required software packages (e.g., `bash`, `kubectl`, `dotnet-sdk-10`).
2.  **In `build.sh`**: Add a new step that reads `build_config.yaml`. This step must loop through every tool variant.
3.  **In `build.sh`**: For each variant, the script must dynamically generate the necessary `RUN` commands (the installation steps) and write them into the correct placeholder location (`#{{ template for variant goes here }}`) in both `Dockerfile` and `Dockerfile.ttyd`.
4.  **Verification**: Run the build script to confirm the Dockerfiles now contain the correct, variant-specific installation commands.

### 2. Fragile CI/CD Contract
**Goal**: Make the system's output reliable for automated testing (CI/CD).
**Files Affected**: `build.sh`, `ci.yml`.
**Step-by-Step Guide**:
1.  **In `build.sh`**: Locate the section that currently prints the list of built images using specific markers (`=== IMAGE_LIST_BEGIN ===`).
2.  **Replace the Markers**: Remove these markers entirely.
3.  **Implement JSON Output**: Replace the marker block with a single command that prints a structured JSON object containing all the built image names and tags. This allows automated systems to read the list reliably.
4.  **In `ci.yml`**: Update the CI workflow step that consumes the image list. Instead of using `sed` or regex to parse the fixed markers, this step must be updated to use a standard JSON parsing function (e.g., `jq` in GitHub Actions) to reliably extract the `images` array from the script's output.
**Verification**: Run the build script and confirm the final output is a single, valid JSON string, and that the CI workflow successfully parses this JSON output.

## ♻️ Maintainability and Robustness (Medium Priority)

### 3. Configuration Structure Improvement
**Goal**: Make the tool requirements easier to manage and validate.
**Files Affected**: `build_config.yaml`, `build.sh`.
**Step-by-Step Guide**:
1.  **In `build_config.yaml`**: Change the single `command` field for each variant into a list of simple `steps`. Each step should be one single command (e.g., `dnf install -y bash`).
2.  **In `build.sh`**: Update the script's logic to read this new `steps` list. Instead of treating the whole list as one command, the script must now execute each step sequentially, ensuring each step is run as a separate `RUN` instruction in the Dockerfile.
**Verification**: Check the generated Dockerfiles to ensure the installation steps are now broken down into multiple, distinct `RUN` commands.

**Clarification on Steps**: The `steps` list can contain multi-line commands. The build script must concatenate these multi-line steps into a single `RUN` instruction using shell continuation (`\`) or `&&` to ensure the entire set of commands executes as one atomic layer in the Dockerfile. This maintains the benefit of atomic layers while allowing complex, multi-line scripts.

**Example (kubectl-tools)**:
Instead of one complex command, the `kubectl-tools` variant will have multiple steps:
- `dnf install -y bash curl jq yq openssl git tar` && \ 
    `dnf clean all` 
- `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"` && \ 
    `chmod +x kubectl` && \ 
    `mkdir -p /usr/local/bin` && \ 
    `mv ./kubectl /usr/local/bin/kubectl`
**Example (dotnet-sdk)**:
 -`dnf install dotnet-sdk-10`
This approach makes the build process transparent and easy to debug, as each step is a distinct, verifiable action.

### 4. Base Image Minimization
**Goal**: Reduce the final image size and security risk.
**Files Affected**: `Dockerfile`, `Dockerfile.ttyd`.
**Step-by-Step Guide**:
1.  **In `Dockerfile` and `Dockerfile.ttyd`**: Change the base image for the final execution stage (the `runtime` stage) from the full `fedora:44` to a minimal version, such as `fedora-minimal:44`.
2.  **In `build.sh`**: Verify that the minimal image still contains all the necessary tools (like `dnf` or `curl`) or update the build script to install these minimal dependencies explicitly in the runtime stage.
**Verification**: Build the image and check its size against the previous version.

## ✨ General Best Practices (Low Priority)

### 5. Code Clarity in `build.sh`
**Goal**: Make the build script easier to test and understand by improving internal structure.
**Files Affected**: `build.sh`.
**Step-by-Step Guide**:
1.  **Refactor Functions**: Instead of extracting functions to a new file, refactor the existing helper functions (`check_deps`, `get_variant_field`, `build_variant`) within `build.sh` to be more modular and self-contained.
2.  **Improve Documentation**: Add detailed comments and internal documentation to explain the purpose, inputs, and outputs of each function, making the script self-documenting.
3.  **Isolate Concerns**: Group related functions logically (e.g., all YAML parsing functions together, all Docker build execution functions together).
**Verification**: Ensure the script's flow is clear and that the functions are designed to be easily unit-tested (even if testing is done via shell scripting).