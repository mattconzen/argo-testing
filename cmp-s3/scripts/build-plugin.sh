#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME="argocd-s3-cmp"
IMAGE_TAG="${1:-local}"

# Auto-detect KIND cluster name
CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1)
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: No KIND clusters found"
  exit 1
fi

echo "=== Building S3 CMP Plugin Image ==="
echo "Using KIND cluster: $CLUSTER_NAME"

# Build the Docker image
echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "$CMP_DIR/plugin"

# Load into KIND cluster
echo "Loading image into KIND cluster..."
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "$CLUSTER_NAME"

echo "=== Build complete ==="
echo ""
echo "Image loaded into KIND cluster: ${IMAGE_NAME}:${IMAGE_TAG}"
