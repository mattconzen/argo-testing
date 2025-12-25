#!/bin/bash
set -euo pipefail

echo "=== Testing S3 CMP Sync ==="

# Force ArgoCD to refresh the application
echo "Triggering hard refresh..."
kubectl patch application s3-demo-app -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Wait a moment for refresh to start
sleep 2

# Check sync status
echo ""
echo "Application status:"
kubectl get application s3-demo-app -n argocd \
  -o jsonpath='{.status.sync.status}' && echo ""

echo ""
echo "Health status:"
kubectl get application s3-demo-app -n argocd \
  -o jsonpath='{.status.health.status}' && echo ""

echo ""
echo "Recent sync result:"
kubectl get application s3-demo-app -n argocd \
  -o jsonpath='{.status.operationState.message}' && echo ""

echo ""
echo "Pods in demo-app namespace:"
kubectl get pods -n demo-app

echo ""
echo "=== Sync test complete ==="
