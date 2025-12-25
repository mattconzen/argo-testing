#!/bin/bash
set -euo pipefail

VERSION="${1:-v1.0.0}"
REGISTRY_HOST="kind-registry:5000"  # In-cluster registry address

echo "=== Deploying OCI Artifacts Demo Application ==="
echo "Using OCI source: oci://${REGISTRY_HOST}/oci-demo-app:${VERSION}"
echo ""

# Create the ArgoCD Application
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oci-demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: oci://${REGISTRY_HOST}/oci-demo-app
    targetRevision: "${VERSION}"
    path: "."
  destination:
    server: https://kubernetes.default.svc
    namespace: oci-demo-app
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
echo "  kubectl get application oci-demo-app -n argocd"
echo ""
echo "View deployed app:"
echo "  kubectl get pods -n oci-demo-app"
echo "  kubectl port-forward svc/oci-demo-app -n oci-demo-app 8082:80"
echo "  curl http://localhost:8082"
