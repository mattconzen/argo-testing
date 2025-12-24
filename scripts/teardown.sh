#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Tearing Down ArgoCD Local Development Environment ===${NC}"

# Delete KIND cluster
if kind get clusters | grep -q "argo-dev"; then
    echo -e "${YELLOW}Deleting KIND cluster 'argo-dev'...${NC}"
    kind delete cluster --name argo-dev
    echo -e "${GREEN}Cluster deleted successfully!${NC}"
else
    echo -e "${YELLOW}Cluster 'argo-dev' not found.${NC}"
fi

echo -e "${GREEN}=== Teardown Complete! ===${NC}"
