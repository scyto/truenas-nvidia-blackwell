#!/usr/bin/env bash
# Patches the NVIDIA driver version in scale-build's build manifest.
# This runs at build time on the GitHub Actions runner, NOT on TrueNAS.
#
# Usage: ./scripts/patch-driver-version.sh <scale-build-dir> <new-nvidia-version>

set -euo pipefail

SCALE_BUILD_DIR="$1"
NEW_NVIDIA_VERSION="$2"

MANIFEST="${SCALE_BUILD_DIR}/conf/build.manifest"

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: build.manifest not found at ${MANIFEST}"
    exit 1
fi

# Read current NVIDIA driver version from the manifest
# The YAML structure is: extensions.nvidia.current: "VERSION"
CURRENT_VERSION=$(python3 -c "
import yaml, sys
with open('${MANIFEST}') as f:
    m = yaml.safe_load(f)
print(m['extensions']['nvidia']['current'])
")

if [ -z "$CURRENT_VERSION" ]; then
    echo "ERROR: Could not read current NVIDIA driver version from manifest"
    exit 1
fi

echo "Current NVIDIA driver version: ${CURRENT_VERSION}"
echo "Target NVIDIA driver version:  ${NEW_NVIDIA_VERSION}"

if [ "$CURRENT_VERSION" = "$NEW_NVIDIA_VERSION" ]; then
    echo "Versions match — no patching needed"
    exit 0
fi

# Replace the version string in the manifest
sed -i "s|current: \"${CURRENT_VERSION}\"|current: \"${NEW_NVIDIA_VERSION}\"|" "$MANIFEST"

# Verify the change
VERIFY=$(python3 -c "
import yaml
with open('${MANIFEST}') as f:
    m = yaml.safe_load(f)
print(m['extensions']['nvidia']['current'])
")

if [ "$VERIFY" != "$NEW_NVIDIA_VERSION" ]; then
    echo "ERROR: Patch verification failed. Expected '${NEW_NVIDIA_VERSION}', got '${VERIFY}'"
    exit 1
fi

echo "Successfully patched NVIDIA driver version: ${CURRENT_VERSION} -> ${NEW_NVIDIA_VERSION}"
