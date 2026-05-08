#!/bin/bash
set -euo pipefail

# ====================================================
# Oh My Pi Docker Build Script
#
# This script builds two images per variant:
#   - Standard image
#   - TTYD-enabled image
#
# IMPORTANT — CI CONTRACT:
# ----------------------------------------------------
# The GitHub Actions workflow (ci.yml) *parses the output*
# of this script to extract the list of built images.
#
# The following block MUST remain exactly as-is:
#
#   === IMAGE_LIST_BEGIN ===
#   <image1>
#   <image2>
#   ...
#   === IMAGE_LIST_END ===
#
# The CI pipeline depends on this exact format.
# DO NOT REMOVE, RENAME, OR MODIFY THESE MARKERS.
# ----------------------------------------------------
#
# The markers are consumed by:
#   sed -n '/IMAGE_LIST_BEGIN/,/IMAGE_LIST_END/p'
#
# Any change will break CI image publishing.
# ====================================================

CONFIG_FILE="./build_config.yaml"
DOCKERFILE="./Dockerfile"
TTYD_DOCKERFILE="./Dockerfile.ttyd"
COMMIT_HASH="$(git rev-parse --short HEAD)"

BUILT_IMAGES=()   # Collected for machine-readable CI output

# ----------------------------------------------------
# Dependency check
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
# ----------------------------------------------------
get_variant_field() {
    local variant="$1"
    local field="$2"
    yq -r ".variants[] | select(.name == \"$variant\") | .$field" "$CONFIG_FILE"
}

# ----------------------------------------------------
# Build a single image (standard or ttyd)
# ----------------------------------------------------
build_variant() {
    local variant="$1"
    local dockerfile="$2"
    local tag="$3"
    local command="$4"

    local temp="/tmp/Dockerfile.${variant}.$$"

    # Inject variant commands into Dockerfile template.
    # AWK is used because it safely handles multiline blocks.
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
# Main
# ----------------------------------------------------
main() {
    check_deps

    if [ -z "${1:-}" ]; then
        echo "Usage: $0 <variant>" >&2
        exit 1
    fi

    VARIANT="$1"

    COMMAND=$(get_variant_field "$VARIANT" "command")
    TAG=$(get_variant_field "$VARIANT" "tag")

    if [ -z "$COMMAND" ] || [ -z "$TAG" ] || [ "$COMMAND" = "null" ] || [ "$TAG" = "null" ]; then
        echo "ERROR: Variant '$VARIANT' not found in $CONFIG_FILE" >&2
        exit 1
    fi

    echo "=== Building variant: $VARIANT ==="
    echo "Command: $COMMAND"
    echo "Tag: $TAG"

    # Build standard image
    STD_TAG="container-my-pi-${TAG}:${COMMIT_HASH}"
    build_variant "$VARIANT" "$DOCKERFILE" "$STD_TAG" "$COMMAND"

    # Build ttyd image
    TTYD_TAG="container-my-pi-${TAG}-ttyd:${COMMIT_HASH}"
    build_variant "$VARIANT" "$TTYD_DOCKERFILE" "$TTYD_TAG" "$COMMAND"

    echo "=== Build complete for $VARIANT ==="

    # ------------------------------------------------
    # CI-CRITICAL MACHINE-READABLE OUTPUT
    # ------------------------------------------------
    # DO NOT MODIFY THIS FORMAT.
    # GitHub Actions extracts this block to determine
    # which images must be pushed to GHCR.
    # ------------------------------------------------
    echo "=== IMAGE_LIST_BEGIN ==="
    for img in "${BUILT_IMAGES[@]}"; do
        echo "$img"
    done
    echo "=== IMAGE_LIST_END ==="
}

main "$@"
