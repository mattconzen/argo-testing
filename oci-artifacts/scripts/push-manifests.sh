#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCI_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST_DIR="${OCI_DIR}/sample-manifests"
CERT_DIR="${OCI_DIR}/certs"

VERSION="${1:-v1.0.0}"
REGISTRY="127.0.0.1:5000"  # Use IP to force HTTPS (ORAS defaults to HTTP for localhost)
REPO="oci-demo-app"

echo "=== Pushing Manifests as OCI Artifact ==="
echo "Version: ${VERSION}"
echo "Registry: ${REGISTRY}"
echo "Repository: ${REPO}"
echo ""

# Check if oras is installed
if ! command -v oras &> /dev/null; then
  echo "ORAS CLI not found. Installing..."

  # Detect OS and install
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install oras
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Download latest release
    ORAS_VERSION="1.1.0"
    curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz"
    tar -xzf "oras_${ORAS_VERSION}_linux_amd64.tar.gz" -C /tmp
    sudo mv /tmp/oras /usr/local/bin/
    rm "oras_${ORAS_VERSION}_linux_amd64.tar.gz"
  else
    echo "ERROR: Please install ORAS manually: https://oras.land/docs/installation"
    exit 1
  fi
fi

echo "Using ORAS version: $(oras version | head -1)"
echo ""

# Create a temporary directory for packaging
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create a tarball of manifests (ArgoCD expects a single layer with tar)
echo "Creating manifests tarball..."
tar -cvf "${TEMP_DIR}/manifests.tar" -C "${MANIFEST_DIR}" .
echo ""

# Set up CA file argument if certs exist
CA_ARG=""
if [ -f "${CERT_DIR}/registry.crt" ]; then
  CA_ARG="--ca-file ${CERT_DIR}/registry.crt"
  echo "Using CA file: ${CERT_DIR}/registry.crt"
fi

# Push using oras with tarball as single layer
echo "Pushing to ${REGISTRY}/${REPO}:${VERSION}..."
cd "${TEMP_DIR}"

oras push ${CA_ARG} \
  "${REGISTRY}/${REPO}:${VERSION}" \
  manifests.tar:application/vnd.oci.image.layer.v1.tar

# Also tag as latest if this is a release
if [[ "$VERSION" != "latest" ]]; then
  echo ""
  echo "Also tagging as latest..."
  oras tag ${CA_ARG} "${REGISTRY}/${REPO}:${VERSION}" latest
fi

echo ""
echo "=== Push complete ==="
echo ""
echo "Verify with:"
echo "  oras manifest fetch ${CA_ARG} ${REGISTRY}/${REPO}:${VERSION}"
echo "  curl -k https://localhost:5000/v2/${REPO}/tags/list"
