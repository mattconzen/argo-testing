# OCI Artifacts Approach for Argo CD

Deploy Kubernetes manifests from OCI registries using Argo CD's native OCI support.

## Overview

This approach packages Kubernetes manifests as OCI artifacts and pushes them to a container registry. Argo CD natively pulls and deploys them — **no custom plugins required**.

```
┌─────────────────────────────────────────────────────────────────┐
│  KIND Cluster                                                   │
│                                                                 │
│  ┌──────────────────┐      ┌─────────────────────────────────┐  │
│  │  Local Registry  │◄─────│  ArgoCD                         │  │
│  │  (TLS, port 5000)│      │  (native OCI support)           │  │
│  │                  │      │                                 │  │
│  │  demo-app:v1.0.0 │      │  source: oci://registry:5000    │  │
│  └──────────────────┘      └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         ▲
         │ oras push (with CA cert)
         │
    CI Pipeline (simulated)
```

## Comparison with S3 CMP Approach

| Aspect | S3 CMP | OCI Artifacts |
|--------|--------|---------------|
| Custom plugin | Required | **Not needed** |
| ArgoCD patching | Yes (sidecar) | **No** |
| Trigger mechanism | Git file | **Direct polling** |
| Tooling | AWS CLI | ORAS CLI |
| Native support | No | **Yes (v2.4+)** |
| Complexity | High | **Low** |

## Prerequisites

- KIND cluster with ArgoCD installed (run `./scripts/setup.sh` from repo root)
- Docker (for local registry)
- ORAS CLI (auto-installed by scripts if missing)
- OpenSSL (for TLS certificate generation)

## Quick Start

```bash
# From the repo root, ensure ArgoCD is running
./scripts/setup.sh

# Setup everything (registry + push manifests + deploy app)
./oci-artifacts/scripts/setup-all.sh

# Check it's working
kubectl get application oci-demo-app -n argocd
kubectl get pods -n oci-demo-app
```

## Step-by-Step Setup

### 1. Setup Local Registry with TLS

```bash
./oci-artifacts/scripts/setup-registry.sh
```

This script:
- Generates a self-signed TLS certificate
- Creates a `registry:2` container with TLS enabled
- Connects it to the KIND network
- Adds the CA certificate to ArgoCD's trust store

### 2. Push Manifests to Registry

```bash
./oci-artifacts/scripts/push-manifests.sh v1.0.0
```

Packages `sample-manifests/*.yaml` into a tarball and pushes as OCI artifact using ORAS.

### 3. Deploy ArgoCD Application

```bash
./oci-artifacts/scripts/deploy-app.sh v1.0.0
```

Creates an ArgoCD Application with `oci://` source type.

## Testing Changes

### Update manifests and redeploy

```bash
# Edit manifests
vim oci-artifacts/sample-manifests/deployment.yaml

# Push new version
./oci-artifacts/scripts/push-manifests.sh v1.1.0

# Update Application to new version and sync
./oci-artifacts/scripts/test-sync.sh v1.1.0
```

### View the deployed application

```bash
kubectl port-forward svc/oci-demo-app -n oci-demo-app 8082:80
curl http://localhost:8082
```

## How It Works

### TLS Requirements

**ArgoCD requires HTTPS for OCI registries.** The local setup uses:
- Self-signed certificate with SANs for `kind-registry`, `localhost`, and `127.0.0.1`
- CA certificate added to ArgoCD's `argocd-tls-certs-cm` ConfigMap
- ORAS uses `--ca-file` to trust the registry's certificate

### Pushing with ORAS

[ORAS](https://oras.land/) (OCI Registry As Storage) pushes non-container artifacts to OCI registries:

```bash
# ArgoCD expects a single tarball layer
tar -cvf manifests.tar -C sample-manifests .

# Push with TLS (use IP address to force HTTPS)
oras push --ca-file certs/registry.crt \
  127.0.0.1:5000/demo-app:v1.0.0 \
  manifests.tar:application/vnd.oci.image.layer.v1.tar
```

**Important notes:**
- Use `127.0.0.1` instead of `localhost` — ORAS defaults to HTTP for `localhost`
- ArgoCD expects a **single tarball layer**, not multiple files
- The `--ca-file` flag tells ORAS to trust the self-signed certificate

### ArgoCD Application

The Application uses the native OCI source type:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oci-demo-app
spec:
  source:
    repoURL: oci://kind-registry:5000/oci-demo-app  # OCI registry with oci:// prefix
    targetRevision: v1.0.0                          # Tag or digest
  destination:
    server: https://kubernetes.default.svc
    namespace: oci-demo-app
```

### Versioning Options

1. **Tagged releases** (`v1.0.0`) — Explicit version in `targetRevision`
2. **Latest tag** — Use `targetRevision: latest`, Argo polls for digest changes
3. **Digest pinning** — Use `targetRevision: sha256:...` for immutable deployments

## Directory Structure

```
oci-artifacts/
├── README.md                 # This file
├── .gitignore                # Excludes certs directory
├── docs/
│   └── DESIGN.md             # Technical design document
├── certs/                    # Generated TLS certs (gitignored)
│   ├── registry.crt
│   └── registry.key
├── sample-manifests/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── scripts/
    ├── setup-all.sh          # Complete setup (recommended)
    ├── setup-registry.sh     # Deploy local registry with TLS
    ├── push-manifests.sh     # Package & push to registry
    ├── deploy-app.sh         # Create ArgoCD Application
    ├── test-sync.sh          # Update version and sync
    └── teardown.sh           # Clean up
```

## Troubleshooting

### ORAS using HTTP instead of HTTPS

ORAS defaults to HTTP for `localhost`. Use the IP address instead:

```bash
# Wrong - uses HTTP
oras push localhost:5000/demo-app:v1.0.0 ...

# Correct - uses HTTPS
oras push --ca-file certs/registry.crt 127.0.0.1:5000/demo-app:v1.0.0 ...
```

### "expected only a single oci content layer, got 0"

ArgoCD expects manifests packaged as a single tarball:

```bash
# Wrong - multiple layers
oras push registry/app:v1 file1.yaml file2.yaml file3.yaml

# Correct - single tarball layer
tar -cvf manifests.tar *.yaml
oras push registry/app:v1 manifests.tar:application/vnd.oci.image.layer.v1.tar
```

### Certificate errors

Ensure the CA cert is added to ArgoCD:

```bash
kubectl create configmap argocd-tls-certs-cm \
  --from-file=kind-registry=certs/registry.crt \
  -n argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/argocd-repo-server -n argocd
```

### ORAS not found

The `push-manifests.sh` script auto-installs ORAS on macOS (via brew) and Linux. For manual installation:

```bash
# macOS
brew install oras

# Linux
curl -LO https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
tar -xzf oras_1.1.0_linux_amd64.tar.gz -C /usr/local/bin oras
```

### Registry not accessible from cluster

Ensure the registry is connected to the KIND network:

```bash
docker network connect kind kind-registry
```

### View ArgoCD logs

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Cleanup

```bash
./oci-artifacts/scripts/teardown.sh

# To also remove the registry:
docker stop kind-registry && docker rm kind-registry
```

## Production Considerations

For production deployments:

1. **Use a real registry** — Docker Hub, GHCR, ECR, GCR, Harbor
2. **Proper TLS** — Use certificates from a trusted CA
3. **Authentication** — Configure `imagePullSecrets` in ArgoCD
4. **Signing** — Use `cosign` to sign artifacts
5. **SBOM** — Attach software bill of materials

See `docs/DESIGN.md` for more details.
