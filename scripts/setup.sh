#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== ArgoCD Local Development Environment Setup ===${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in kind kubectl helm docker; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites met!${NC}"

# Create KIND cluster
echo -e "${YELLOW}Creating KIND cluster...${NC}"
if kind get clusters | grep -q "argo-dev"; then
    echo -e "${YELLOW}Cluster 'argo-dev' already exists. Deleting...${NC}"
    kind delete cluster --name argo-dev
fi

kind create cluster --config "${PROJECT_DIR}/kind/cluster-config.yaml"

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Add Helm repository
echo -e "${YELLOW}Adding Argo Helm repository...${NC}"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
echo -e "${YELLOW}Installing ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm install argocd argo/argo-cd \
    --namespace argocd \
    --values "${PROJECT_DIR}/helm/argocd-values.yaml" \
    --wait --timeout 5m

# Install Argo Rollouts
echo -e "${YELLOW}Installing Argo Rollouts...${NC}"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
helm install argo-rollouts argo/argo-rollouts \
    --namespace argo-rollouts \
    --values "${PROJECT_DIR}/helm/argo-rollouts-values.yaml" \
    --wait --timeout 3m

# Wait for ArgoCD pods to be ready
echo -e "${YELLOW}Waiting for ArgoCD pods to be ready...${NC}"
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Wait for Argo Rollouts pods to be ready
echo -e "${YELLOW}Waiting for Argo Rollouts pods to be ready...${NC}"
kubectl wait --for=condition=Ready pods --all -n argo-rollouts --timeout=120s

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo -e "${GREEN}ArgoCD UI:${NC}"
echo "  URL: http://localhost:8080"
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"
echo ""
echo -e "${GREEN}Argo Rollouts Dashboard:${NC}"
echo "  Run: kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100"
echo "  URL: http://localhost:3100"
echo ""
echo -e "${GREEN}To deploy test application:${NC}"
echo "  kubectl apply -f ${PROJECT_DIR}/apps/test-app/"
echo ""
