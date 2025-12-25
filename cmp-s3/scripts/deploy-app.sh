#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$CMP_DIR")"

echo "=== Deploying S3 CMP Demo Application ==="

# Get the git remote URL for this repo
GIT_URL=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "https://github.com/mattconzen/argo-testing.git")

# Convert SSH URL to HTTPS if needed
if [[ "$GIT_URL" == git@* ]]; then
  GIT_URL=$(echo "$GIT_URL" | sed 's|git@github.com:|https://github.com/|')
fi

echo "Using Git repo: $GIT_URL"

# Create the ArgoCD Application
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: s3-demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${GIT_URL}
    targetRevision: HEAD
    path: cmp-s3/trigger-repo/demo-app
  destination:
    server: https://kubernetes.default.svc
    namespace: demo-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo ""
echo "=== Application created ==="
echo ""
echo "Check status:"
echo "  kubectl get application s3-demo-app -n argocd"
echo ""
echo "View in ArgoCD UI:"
echo "  1. kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open https://localhost:8080"
echo ""
echo "View deployed app:"
echo "  kubectl get pods -n demo-app"
echo "  kubectl port-forward svc/demo-app -n demo-app 8081:80"
echo "  curl http://localhost:8081"
