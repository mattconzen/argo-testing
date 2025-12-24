# ArgoCD Local Development Environment

A fully local ArgoCD development environment using KIND (Kubernetes in Docker).

## Prerequisites

- Docker Desktop
- kind v0.24.0+
- kubectl v1.34.1+
- helm v3.13.3+

## Quick Start

```bash
# Setup everything
./scripts/setup.sh

# Verify installation
./scripts/verify.sh
```

## Components

- **KIND Cluster**: 3-node cluster (1 control-plane, 2 workers)
- **ArgoCD**: GitOps continuous delivery tool
- **Argo Rollouts**: Progressive delivery controller

## Accessing UIs

### ArgoCD
- URL: http://localhost:8080
- Username: admin
- Get password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Argo Rollouts Dashboard
```bash
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
```
Then visit: http://localhost:3100

## Deploying Test Application

```bash
# Deploy the test app
kubectl apply -f apps/test-app/

# Check deployment status
kubectl get pods -l app=test-app

# Deploy rollout example
kubectl apply -f apps/test-app/rollout.yaml

# Watch the rollout (requires kubectl-argo-rollouts plugin)
kubectl argo rollouts get rollout test-app-rollout -w
```

## Teardown

```bash
./scripts/teardown.sh
```

## Directory Structure

```
.
├── kind/
│   └── cluster-config.yaml    # KIND cluster configuration
├── helm/
│   ├── argocd-values.yaml     # ArgoCD Helm values
│   └── argo-rollouts-values.yaml  # Argo Rollouts Helm values
├── apps/
│   └── test-app/              # Sample test application
│       ├── deployment.yaml
│       ├── service.yaml
│       └── rollout.yaml
├── scripts/
│   ├── setup.sh               # Full setup script
│   ├── teardown.sh            # Cleanup script
│   └── verify.sh              # Verification script
└── README.md
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Can't access ArgoCD UI
```bash
# Check service status
kubectl get svc -n argocd

# Use port-forward as alternative
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
