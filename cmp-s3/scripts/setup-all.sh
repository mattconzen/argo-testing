#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  S3 CMP Full Setup"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl cannot connect to cluster."
  echo "Make sure your KIND cluster is running: ./scripts/setup.sh"
  exit 1
fi

if ! kubectl get namespace argocd &>/dev/null; then
  echo "ERROR: ArgoCD namespace not found."
  echo "Make sure ArgoCD is installed: ./scripts/setup.sh"
  exit 1
fi

echo "Prerequisites OK"
echo ""

# Step 1: Setup LocalStack
echo "[1/4] Setting up LocalStack..."
"$SCRIPT_DIR/setup-localstack.sh"
echo ""

# Step 2: Build plugin
echo "[2/4] Building S3 CMP plugin..."
"$SCRIPT_DIR/build-plugin.sh"
echo ""

# Step 3: Patch ArgoCD
echo "[3/4] Patching ArgoCD with S3 CMP sidecar..."
"$SCRIPT_DIR/patch-argocd.sh"
echo ""

# Step 4: Upload sample manifests
echo "[4/4] Uploading sample manifests to S3..."
"$SCRIPT_DIR/upload-manifests.sh"
echo ""

echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Deploy the demo application:"
echo "   ./cmp-s3/scripts/deploy-app.sh"
echo ""
echo "2. Check application status:"
echo "   kubectl get application s3-demo-app -n argocd"
echo ""
echo "3. Test the deployed app:"
echo "   kubectl port-forward svc/demo-app -n demo-app 8081:80"
echo "   curl http://localhost:8081"
echo ""
echo "4. Update manifests and sync:"
echo "   # Edit cmp-s3/sample-manifests/*.yaml"
echo "   ./cmp-s3/scripts/upload-manifests.sh"
echo "   ./cmp-s3/scripts/test-sync.sh"
