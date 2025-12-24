# ArgoCD Local Development Environment

A fully local Kubernetes development environment with ArgoCD, Argo Rollouts, and Envoy for testing GitOps workflows.

## Prerequisites

- Docker Desktop
- kind v0.24.0+
- kubectl v1.34.1+
- helm v3.13.3+

## Quick Start

```bash
# Clone the repo
git clone https://github.com/mattconzen/argo-testing.git
cd argo-testing

# Start Docker if not running
open -a Docker

# Run setup (creates KIND cluster, installs ArgoCD + Argo Rollouts)
./scripts/setup.sh

# Verify installation
./scripts/verify.sh
```

## What Gets Installed

| Component | Namespace | Description |
|-----------|-----------|-------------|
| KIND Cluster | - | 3-node cluster (1 control-plane, 2 workers) |
| ArgoCD | argocd | GitOps continuous delivery |
| Argo Rollouts | argo-rollouts | Progressive delivery controller |

## Accessing UIs

### ArgoCD
- **URL**: http://localhost:8080
- **Username**: admin
- **Password**: Run `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

### Argo Rollouts Dashboard
```bash
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
# Visit http://localhost:3100
```

## Deploy Applications with ArgoCD

### Deploy Envoy (from this repo)
```bash
kubectl apply -f apps/envoy-app.yaml

# Test the endpoint
kubectl port-forward -n envoy svc/envoy 8080:8080
curl http://localhost:8080/
# Returns: {"message": "Hello from Envoy! CD is working!", "deployed_by": "ArgoCD", "updated": "2025-12-24"}
```

### Deploy Guestbook (from ArgoCD examples)
```bash
kubectl apply -f apps/guestbook-app.yaml
```

### Check Application Status
```bash
kubectl get applications -n argocd
```

## Testing Continuous Delivery

1. Edit a manifest (e.g., `apps/envoy/configmap.yaml`)
2. Update the `config-version` annotation in `apps/envoy/deployment.yaml`
3. Commit and push:
   ```bash
   git add . && git commit -m "Update config" && git push
   ```
4. ArgoCD will automatically sync the changes (or trigger manually):
   ```bash
   kubectl patch application envoy -n argocd --type merge \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

## Directory Structure

```
.
├── kind/
│   └── cluster-config.yaml      # KIND cluster configuration
├── helm/
│   ├── argocd-values.yaml       # ArgoCD Helm values
│   └── argo-rollouts-values.yaml
├── apps/
│   ├── envoy/                   # Envoy proxy manifests
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── envoy-app.yaml           # ArgoCD Application for Envoy
│   ├── guestbook-app.yaml       # ArgoCD Application for Guestbook
│   └── test-app/                # Test app with Argo Rollout
├── scripts/
│   ├── setup.sh                 # Full environment setup
│   ├── teardown.sh              # Clean teardown
│   └── verify.sh                # Health checks
└── README.md
```

## Teardown

```bash
./scripts/teardown.sh
```

## Troubleshooting

### Docker not running
```bash
open -a Docker
# Wait for Docker to start, then retry setup
```

### Pods not starting
```bash
kubectl describe pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### ArgoCD sync issues
```bash
# Force refresh
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check app details
kubectl describe application <app-name> -n argocd
```

### Port conflicts
The setup uses these ports:
- 80, 443: Ingress (mapped from NodePorts)
- 8080: ArgoCD UI
- 3100: Argo Rollouts Dashboard (via port-forward)
