#!/bin/bash
set -euo pipefail

echo "=== Tearing down OCI Artifacts components ==="

# Delete the ArgoCD Application
echo "Deleting ArgoCD Application..."
kubectl delete application oci-demo-app -n argocd --ignore-not-found

# Wait for app deletion to clean up resources
sleep 5

# Delete demo-app namespace
echo "Deleting oci-demo-app namespace..."
kubectl delete namespace oci-demo-app --ignore-not-found

# Optionally remove the registry (commented out by default to preserve for other tests)
# echo "Stopping local registry..."
# docker stop kind-registry 2>/dev/null || true
# docker rm kind-registry 2>/dev/null || true

echo ""
echo "=== Teardown complete ==="
echo ""
echo "Note: The local registry (kind-registry) is still running."
echo "To remove it completely:"
echo "  docker stop kind-registry && docker rm kind-registry"
