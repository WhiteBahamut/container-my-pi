#!/bin/bash
set -euo pipefail

# ====================================================
# Oh My Pi Docker Build Script
#
# PURPOSE:
#   Deterministically build container images for each
#   variant defined in build_config.yaml. For every
#   variant, two images are produced:
#     - Standard image
#     - TTYD-enabled image
#
#   The script optionally accepts a container registry
#   prefix. If provided, all emitted image tags are
#   prefixed with "<registry>/...".
#
#   Example:
#       ./build.sh standard
#       ./build.sh standard ghcr.io/wayne/oh-my-pi
#
# CI CONTRACT:
# ----------------------------------------------------
# GitHub Actions parses the output of this script to
# determine which images must be pushed. The following
# block MUST remain byte-for-byte identical:
#
#   === IMAGE_LIST_BEGIN ===
#   <image1>
#   <image2>
#   ...
#   === IMAGE_LIST_END ===
#
# DO NOT MODIFY THESE MARKERS.
# ====================================================

CONFIG_FILE="./build_config.yaml"
DOCKERFILE="./Dockerfile"
TTYD_DOCKERFILE="./Dockerfile.ttyd"
COMMIT_HASH="$(git rev-parse --short HEAD)"

# Array collecting all built image tags for CI output
BUILT_IMAGES=()

# ----------------------------------------------------
# Dependency check
# Ensures required tools exist before continuing.
# ----------------------------------------------------
check_deps() {
    for dep in docker yq; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "ERROR: Missing dependency: $dep" >&2
            exit 1
        fi
    done
}

# ----------------------------------------------------
# Helper: read a field from a variant in build_config.yaml
# This isolates YAML parsing and avoids duplication.
# ----------------------------------------------------
get_variant_field() {
    local variant="$1"
    local field="$2"
    yq -r ".variants[] | select(.name == \"$variant\") | .$field" "$CONFIG_FILE"
}

# ----------------------------------------------------
# Build a single image (standard or ttyd)
#
# Steps:
#   1. Create a temporary Dockerfile with injected
#      variant-specific commands.
#   2. Build the image with docker build.
#   3. Append the resulting tag to BUILT_IMAGES.
#
# AWK is used for safe multiline template injection.
# ----------------------------------------------------
build_variant() {
    local variant="$1"
    local dockerfile="$2"
    local tag="$3"
    local command="$4"

    local temp="/tmp/Dockerfile.${variant}.$$"

    # Inject variant commands into the Dockerfile template
    awk -v block="$command" '
        /{{ template for variant goes here }}/ {
            print block
            next
        }
        { print }
    ' "$dockerfile" > "$temp"

    echo "-> Building: $tag"
    docker build --pull -t "$tag" -f "$temp" .

    BUILT_IMAGES+=("$tag")

    rm -f "$temp"
}

# ----------------------------------------------------
# Main entry point
#
# Arguments:
#   $1 = variant name (required)
#   $2 = registry prefix (optional)
#
# Behavior:
#   - Validates variant exists in YAML.
#   - Builds standard + ttyd images.
#   - Emits CI machine-readable image list.
# ----------------------------------------------------
main() {
    check_deps

    if [ -z "${1:-}" ]; then
        echo "Usage: $0 <variant> [registry]" >&2
        exit 1
    fi

    VARIANT="$1"
    REGISTRY="${2:-}"

    COMMAND=$(get_variant_field "$VARIANT" "command")
    TAG=$(get_variant_field "$VARIANT" "tag")

    # Validate variant definition
    if [ -z "$COMMAND" ] || [ -z "$TAG" ] || [ "$COMMAND" = "null" ] || [ "$TAG" = "null" ]; then
        echo "ERROR: Variant '$VARIANT' not found in $CONFIG_FILE" >&2
        exit 1
    fi

    echo "=== Building variant: $VARIANT ==="
    echo "Command: $COMMAND"
    echo "Tag: $TAG"

    # Optional registry prefix
    if [ -n "$REGISTRY" ]; then
        PREFIX="${REGISTRY}/"
    else
        PREFIX=""
    fi

    # Construct deterministic tags
    STD_TAG="${PREFIX}container-my-pi-${TAG}:${COMMIT_HASH}"
    TTYD_TAG="${PREFIX}container-my-pi-${TAG}-ttyd:${COMMIT_HASH}"

    # Build both images
    build_variant "$VARIANT" "$DOCKERFILE" "$STD_TAG" "$COMMAND"
    build_variant "$VARIANT" "$TTYD_DOCKERFILE" "$TTYD_TAG" "$COMMAND"

    echo "=== Build complete for $VARIANT ==="

    # ------------------------------------------------
    # CI-CRITICAL MACHINE-READABLE OUTPUT
    # DO NOT MODIFY THIS FORMAT.
    # ------------------------------------------------
    echo "=== IMAGE_LIST_BEGIN ==="
    for img in "${BUILT_IMAGES[@]}"; do
        echo "$img"
    done
    echo "=== IMAGE_LIST_END ==="
}

main "$@"
