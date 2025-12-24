#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Verification Checklist ===${NC}"
echo ""

ERRORS=0

# Check KIND cluster
echo -n "1. KIND cluster 'argo-dev' exists: "
if kind get clusters | grep -q "argo-dev"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check kubectl context
echo -n "2. kubectl context set correctly: "
if kubectl config current-context | grep -q "kind-argo-dev"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check nodes
echo -n "3. All nodes are Ready: "
NOT_READY=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l | tr -d ' ')
if [ "$NOT_READY" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL (${NOT_READY} nodes not ready)${NC}"
    ((ERRORS++))
fi

# Check ArgoCD namespace
echo -n "4. ArgoCD namespace exists: "
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check ArgoCD pods
echo -n "5. ArgoCD pods are running: "
ARGOCD_NOT_RUNNING=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -v "Running" | wc -l | tr -d ' ')
if [ "$ARGOCD_NOT_RUNNING" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL (${ARGOCD_NOT_RUNNING} pods not running)${NC}"
    ((ERRORS++))
fi

# Check Argo Rollouts namespace
echo -n "6. Argo Rollouts namespace exists: "
if kubectl get namespace argo-rollouts &> /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check Argo Rollouts pods
echo -n "7. Argo Rollouts pods are running: "
ROLLOUTS_NOT_RUNNING=$(kubectl get pods -n argo-rollouts --no-headers 2>/dev/null | grep -v "Running" | wc -l | tr -d ' ')
if [ "$ROLLOUTS_NOT_RUNNING" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL (${ROLLOUTS_NOT_RUNNING} pods not running)${NC}"
    ((ERRORS++))
fi

# Check ArgoCD CRDs
echo -n "8. ArgoCD CRDs installed: "
if kubectl get crd applications.argoproj.io &> /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check Argo Rollouts CRDs
echo -n "9. Argo Rollouts CRDs installed: "
if kubectl get crd rollouts.argoproj.io &> /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

# Check ArgoCD server accessibility
echo -n "10. ArgoCD server accessible: "
if kubectl get svc argocd-server -n argocd &> /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((ERRORS++))
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All verification checks passed!${NC}"
else
    echo -e "${RED}${ERRORS} verification check(s) failed.${NC}"
    exit 1
fi
