#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Tearing down S3 CMP components ==="

# Delete the ArgoCD Application
echo "Deleting ArgoCD Application..."
kubectl delete application s3-demo-app -n argocd --ignore-not-found

# Wait for app deletion to clean up resources
sleep 5

# Delete demo-app namespace
echo "Deleting demo-app namespace..."
kubectl delete namespace demo-app --ignore-not-found

# Remove the sidecar from repo-server by scaling down and removing patch
# This is tricky - we'll restore the original deployment
echo "Removing S3 CMP sidecar from repo-server..."
echo "(Note: This requires manually removing the sidecar container)"
echo "For a clean reset, consider rerunning ./scripts/setup.sh"

# Delete LocalStack
echo "Deleting LocalStack..."
kubectl delete -f "$CMP_DIR/localstack/deployment.yaml" --ignore-not-found

echo ""
echo "=== Teardown complete ==="
echo ""
echo "Note: The repo-server sidecar patch remains. To fully reset ArgoCD:"
echo "  kubectl rollout restart deployment/argocd-repo-server -n argocd"
echo "  # Or reinstall ArgoCD completely"
