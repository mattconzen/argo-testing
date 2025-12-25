#!/bin/bash
set -euo pipefail

VERSION="${1:-}"

echo "=== Testing OCI Artifacts Sync ==="

# Update the Application's targetRevision if version provided
if [ -n "$VERSION" ]; then
  echo "Updating Application to version: ${VERSION}"
  kubectl patch application oci-demo-app -n argocd --type merge \
    -p "{\"spec\":{\"source\":{\"targetRevision\":\"${VERSION}\"}}}"
fi

# Force ArgoCD to refresh the application
echo "Triggering hard refresh..."
kubectl patch application oci-demo-app -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Wait a moment for refresh to start
sleep 3

# Check sync status
echo ""
echo "Application status:"
kubectl get application oci-demo-app -n argocd \
  -o jsonpath='Sync: {.status.sync.status}, Health: {.status.health.status}' && echo ""

echo ""
echo "Source info:"
kubectl get application oci-demo-app -n argocd \
  -o jsonpath='Repo: {.spec.source.repoURL}, Revision: {.status.sync.revision}' && echo ""

echo ""
echo "Pods in oci-demo-app namespace:"
kubectl get pods -n oci-demo-app

echo ""
echo "=== Sync test complete ==="
