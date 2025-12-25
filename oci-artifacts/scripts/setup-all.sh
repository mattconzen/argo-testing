#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  OCI Artifacts Full Setup"
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

# Step 1: Setup local registry
echo "[1/3] Setting up local OCI registry..."
"$SCRIPT_DIR/setup-registry.sh"
echo ""

# Step 2: Push sample manifests
echo "[2/3] Pushing sample manifests to registry..."
"$SCRIPT_DIR/push-manifests.sh" v1.0.0
echo ""

# Step 3: Deploy ArgoCD Application
echo "[3/3] Deploying ArgoCD Application..."
"$SCRIPT_DIR/deploy-app.sh" v1.0.0
echo ""

echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Check application status:"
echo "   kubectl get application oci-demo-app -n argocd"
echo ""
echo "2. Wait for pods to be ready:"
echo "   kubectl get pods -n oci-demo-app -w"
echo ""
echo "3. Test the deployed app:"
echo "   kubectl port-forward svc/oci-demo-app -n oci-demo-app 8082:80"
echo "   curl http://localhost:8082"
echo ""
echo "4. Update and redeploy:"
echo "   # Edit oci-artifacts/sample-manifests/deployment.yaml"
echo "   ./oci-artifacts/scripts/push-manifests.sh v1.1.0"
echo "   ./oci-artifacts/scripts/test-sync.sh v1.1.0"
