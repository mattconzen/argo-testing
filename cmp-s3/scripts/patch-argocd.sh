#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Patching ArgoCD repo-server with S3 CMP sidecar ==="

# Check if patch is already applied by looking for the s3-cmp container
if kubectl get deployment argocd-repo-server -n argocd -o jsonpath='{.spec.template.spec.containers[*].name}' | grep -q 's3-cmp'; then
  echo "S3 CMP sidecar already present. Restarting to pick up any changes..."
  kubectl rollout restart deployment/argocd-repo-server -n argocd
else
  echo "Applying patch..."
  kubectl patch deployment argocd-repo-server -n argocd \
    --patch-file "$CMP_DIR/argocd-patch/repo-server-patch.yaml"
fi

# Wait for rollout
echo "Waiting for repo-server rollout..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s

# Verify sidecar is running
echo ""
echo "Verifying sidecar..."
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server -o wide

echo ""
echo "Checking containers in repo-server pod..."
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server \
  -o jsonpath='{range .items[0].spec.containers[*]}{.name}{"\n"}{end}'

echo ""
echo "=== Patch complete ==="
