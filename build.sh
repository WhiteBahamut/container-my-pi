#!/usr/bin/env bash
set -euo pipefail

# ====================================================
# Oh My Pi Docker Build Script
# ====================================================
# Purpose:
#   Deterministically build container images for each
#   variant defined in build_config.yaml. For every
#   variant, two images are produced:
#     - Standard image
#     - TTYD-enabled image
#
# Key behavior:
#   - build_config.yaml uses a `steps` list per variant.
#   - Each steps[] item becomes one Dockerfile line:
#       RUN <step content as in YAML>
#     injected verbatim (no modification).
#   - Multi-line steps are preserved exactly as written in YAML.
#   - The script does NOT read or substitute any base image.
#     Dockerfile templates must include their own FROM line.
#   - Variant `name` is used as the image tag (no separate tag field).
#
# Required files:
#   - build_config.yaml
#     (variants: list of objects with `name` and `steps`)
#   - Dockerfile (template) containing the placeholder:
#       {{ template for variant goes here }}
#     and a FROM line (script will not inject FROM).
#   - Dockerfile.ttyd (template) containing the same placeholder
#
# Dependencies:
#   - docker
#   - yq (v4+ recommended)
#   - jq
#   - base64 (GNU or BSD compatible)
#
# Usage:
#   ./build.sh <variant-name> [registry]
#
# Output:
#   The script prints a CI-parsable image list block:
#     === IMAGE_LIST_BEGIN ===
#     <image1>
#     <image2>
#     === IMAGE_LIST_END ===
#
# Notes:
#   - The script preserves step content exactly. If you want
#     shell flags (e.g., set -eux) or continuations (&& \),
#     include them in the YAML step content.
#   - To inspect generated temporary Dockerfiles for debugging,
#     temporarily comment out the `rm -f "$temp"` line in
#     build_variant() to keep the file.
# ====================================================

CONFIG_FILE="./build_config.yaml"
DOCKERFILE="./Dockerfile"
TTYD_DOCKERFILE="./Dockerfile.ttyd"
COMMIT_HASH="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

BUILT_IMAGES=()

# ----------------------------------------------------
# Dependency check
# ----------------------------------------------------
check_deps() {
  for dep in docker yq jq base64; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "ERROR: Missing dependency: $dep" >&2
      exit 1
    fi
  done
}

# ----------------------------------------------------
# Read a scalar field from a variant (name, etc.)
# ----------------------------------------------------
get_variant_field() {
  local variant="$1"
  local field="$2"
  yq -r ".variants[] | select(.name == \"${variant}\") | .${field} // \"\"" "$CONFIG_FILE"
}

# ----------------------------------------------------
# Read steps array for a variant as JSON
# ----------------------------------------------------
get_variant_steps_json() {
  local variant="$1"
  local fieldName="$2"
  # returns JSON array (possibly empty)
  yq -o=json ".variants[] | select(.name == \"${variant}\") | .${fieldName} // []" "$CONFIG_FILE"
}

# ----------------------------------------------------
# Convert steps JSON -> verbatim RUN blocks
# Each array element becomes one "RUN <step content>" block.
# We base64-encode JSON elements in jq and decode in bash to
# preserve newlines and exact content without jq/bourne quoting issues.
# ----------------------------------------------------
steps_json_to_run_block() {
  # stdin: JSON array of steps
  # output: block of text with each step prefixed by "RUN " and preserved verbatim
  jq -r 'map(@base64) | .[]' | while IFS= read -r b64; do
    # Try GNU base64 decode first, fallback to BSD (-D)
    if ! step="$(printf '%s' "$b64" | base64 --decode 2>/dev/null)"; then
      step="$(printf '%s' "$b64" | base64 -D 2>/dev/null || true)"
    fi

    # If decoding failed, skip
    if [ -z "${step+x}" ]; then
      continue
    fi

    # Emit RUN followed by the step content exactly as in YAML.
    # If the step contains multiple lines, the first line will be on the same line as RUN,
    # and subsequent lines will follow unchanged.
    printf 'RUN %s\n\n' "$step"
  done
}

# ----------------------------------------------------
# Build a single image (standard or ttyd)
# ----------------------------------------------------
build_variant() {
  local variant="$1"
  local dockerfile_template="$2"
  local tag="$3"
  local steps_json="$4"
  local tests_json="$5"
  local temp="/tmp/Dockerfile.${variant}.$$"

  # Generate injected block (verbatim RUN <step content> per steps item)
  injected_block="$(
    {
      printf '%s' "$steps_json" | steps_json_to_run_block
      printf '\n'
      printf '%s' "$tests_json" | steps_json_to_run_block
    }
  )"

  # Inject into template at the placeholder line
  awk -v block="$injected_block" '
    /{{ template for variant goes here }}/ {
      print block
      next
    }
    { print }
  ' "$dockerfile_template" > "$temp"

  echo "-> Building: $tag"

  if command -v podman; then
    envArgs="--build-arg-file .image.env"
    engine=podman
  else
    envArgs="--env-file .image.env"
    engine=docker
  fi

  $engine build $envArgs --pull -t "$tag" -f "$temp" .

  BUILT_IMAGES+=("$tag")

  rm -f "$temp"
}

# ----------------------------------------------------
# Main
# ----------------------------------------------------
main() {
  check_deps

  if [ -z "${1:-}" ]; then
    echo "Usage: $0 <variant-name> [registry]" >&2
    exit 1
  fi

  VARIANT="$1"
  REGISTRY="${2:-}"

  # Use variant name as tag (no separate tag field)
  TAG="${VARIANT}"

  STEPS_JSON="$(get_variant_steps_json "$VARIANT" steps)"
  TESTS_JSON="$(get_variant_steps_json "$VARIANT" tests)"

  if [ -z "$STEPS_JSON" ] || [ "$STEPS_JSON" = "null" ]; then
    echo "ERROR: Variant '$VARIANT' not found or missing steps in $CONFIG_FILE" >&2
    exit 1
  fi

  echo "=== Building variant: $VARIANT ==="
  echo "Tag: $TAG"

  if [ -n "$REGISTRY" ]; then
    PREFIX="${REGISTRY}/"
  else
    PREFIX=""
  fi

  STD_TAG="${PREFIX}container-my-pi-${TAG}:${COMMIT_HASH}"
  TTYD_TAG="${PREFIX}container-my-pi-${TAG}-ttyd:${COMMIT_HASH}"

  tmp_std_template="/tmp/Dockerfile.template.std.$$"
  tmp_ttyd_template="/tmp/Dockerfile.template.ttyd.$$"

  # Do not substitute any base image; templates must include FROM line themselves
  cp "$DOCKERFILE" "$tmp_std_template"
  cp "$TTYD_DOCKERFILE" "$tmp_ttyd_template"

  build_variant "$VARIANT" "$tmp_std_template" "$STD_TAG" "$STEPS_JSON" "$TESTS_JSON"
  build_variant "$VARIANT" "$tmp_ttyd_template" "$TTYD_TAG" "$STEPS_JSON" "$TESTS_JSON"

  rm -f "$tmp_std_template" "$tmp_ttyd_template"

  echo "=== Build complete for $VARIANT ==="

# ------------------------------------------------
# CI-CRITICAL MACHINE-READABLE OUTPUT
# DO NOT MODIFY THIS FORMAT.
# ------------------------------------------------
echo "=== IMAGE_LIST_BEGIN ==="
# Print BUILT_IMAGES as a compact JSON array
# Uses jq (already a script dependency)
printf '%s\n' "${BUILT_IMAGES[@]}" | jq -R -s -c 'split("\n")[:-1]'
echo "=== IMAGE_LIST_END ==="
}

main "$@"
