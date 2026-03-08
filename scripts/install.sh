#!/usr/bin/env bash
# Installs the pre-built nvidia.raw sysext on a running TrueNAS system.
# All driver compilation happens on GitHub Actions — this script only
# downloads and places the pre-built nvidia.raw file.
#
# Usage: curl -fsSL <release-url>/install.sh | sudo bash
#    or: sudo ./install.sh [path-to-nvidia.raw]

set -euo pipefail

REPO="scyto/truenas-nvidia-blackwell"
SYSEXT_DIR="/usr/share/truenas/sysext-extensions"
NVIDIA_RAW="${SYSEXT_DIR}/nvidia.raw"

cleanup() {
    rm -f /tmp/nvidia.raw /tmp/nvidia.raw.sha256
    rm -rf /tmp/nvidia-sysext-unpack
}
trap cleanup EXIT

# If a local path is provided, use it; otherwise download from GitHub releases
if [ "${1:-}" != "" ] && [ -f "${1:-}" ]; then
    echo "Using local nvidia.raw: $1"
    cp "$1" /tmp/nvidia.raw
else
    # Detect TrueNAS version
    VERSION=$(midclt call system.info | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    echo "Detected TrueNAS version: ${VERSION}"

    # Find matching release
    echo "Searching for matching release..."
    RELEASE_TAG=$(curl -sf "https://api.github.com/repos/${REPO}/releases" \
        | python3 -c "
import sys, json
releases = json.load(sys.stdin)
version = '${VERSION}'
matches = [r for r in releases if version in r['tag_name']]
if not matches:
    print('', end='')
else:
    print(matches[0]['tag_name'], end='')
")

    if [ -z "$RELEASE_TAG" ]; then
        echo "ERROR: No release found for TrueNAS version ${VERSION}"
        echo "Available releases:"
        curl -sf "https://api.github.com/repos/${REPO}/releases" \
            | python3 -c "import sys,json; [print(f'  {r[\"tag_name\"]}') for r in json.load(sys.stdin)]"
        exit 1
    fi

    echo "Found release: ${RELEASE_TAG}"

    # Download nvidia.raw and checksum
    BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"
    echo "Downloading nvidia.raw..."
    curl -fSL "${BASE_URL}/nvidia.raw" -o /tmp/nvidia.raw
    curl -fSL "${BASE_URL}/nvidia.raw.sha256" -o /tmp/nvidia.raw.sha256

    # Verify checksum
    echo "Verifying checksum..."
    cd /tmp
    if ! sha256sum -c nvidia.raw.sha256; then
        echo "ERROR: Checksum verification failed!"
        exit 1
    fi
    cd -
    echo "Checksum OK"
fi

# Inject displaymodeselector into nvidia.raw if found in user's home directory
CALLER_HOME=$(eval echo "~${SUDO_USER:-root}")
DMS_SRC=""
for candidate in "${CALLER_HOME}/displaymodeselector" "${CALLER_HOME}/DisplayModeSelector"; do
    if [ -f "$candidate" ]; then
        DMS_SRC="$candidate"
        break
    fi
done

if [ -n "$DMS_SRC" ]; then
    if command -v unsquashfs &>/dev/null && command -v mksquashfs &>/dev/null; then
        echo "Found displaymodeselector at ${DMS_SRC}, injecting into nvidia.raw..."
        unsquashfs -d /tmp/nvidia-sysext-unpack /tmp/nvidia.raw
        cp "$DMS_SRC" /tmp/nvidia-sysext-unpack/usr/bin/displaymodeselector
        chmod +x /tmp/nvidia-sysext-unpack/usr/bin/displaymodeselector
        mksquashfs /tmp/nvidia-sysext-unpack /tmp/nvidia.raw -noappend -comp zstd
        rm -rf /tmp/nvidia-sysext-unpack
        echo "displaymodeselector injected into nvidia.raw"
    else
        echo "WARNING: squashfs-tools not found, cannot inject displaymodeselector into sysext"
        echo "  Install squashfs-tools or include displaymodeselector via the build workflow"
    fi
else
    echo ""
    echo "NOTE: displaymodeselector not found in ${CALLER_HOME}/"
    echo "  MIG requires displaymodeselector to switch to compute display mode."
    echo "  Download it from https://developer.nvidia.com/displaymodeselector"
    echo "  Place it in your home directory and re-run this script to include it."
fi

echo ""
echo "=== Installing nvidia.raw ==="

# Disable NVIDIA support temporarily
echo "Disabling NVIDIA support..."
midclt call docker.update '{"nvidia": false}'
systemd-sysext unmerge

# Make /usr writable
USR_DATASET=$(zfs list -H -o name /usr)
echo "Setting ${USR_DATASET} to writable..."
zfs set readonly=off "${USR_DATASET}"

# Backup existing nvidia.raw
if [ -f "${NVIDIA_RAW}" ]; then
    echo "Backing up existing nvidia.raw..."
    cp "${NVIDIA_RAW}" "${NVIDIA_RAW}.bak"
fi

# Install new nvidia.raw
echo "Installing new nvidia.raw..."
cp /tmp/nvidia.raw "${NVIDIA_RAW}"

# Restore read-only
zfs set readonly=on "${USR_DATASET}"

# Re-enable NVIDIA support
echo "Merging sysext and re-enabling NVIDIA..."
systemd-sysext merge
midclt call docker.update '{"nvidia": true}'

echo ""
echo "=== Installation complete ==="
echo ""

# Verify
if command -v nvidia-smi &>/dev/null; then
    echo "Driver version:"
    nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "(nvidia-smi not yet available — may need service restart)"
    echo ""
    echo "MIG capability:"
    nvidia-smi --query-gpu=mig.mode.current,mig.mode.pending --format=csv 2>/dev/null || true
else
    echo "nvidia-smi not found — you may need to restart Docker services"
fi
