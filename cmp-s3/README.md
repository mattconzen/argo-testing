# S3 Config Management Plugin for Argo CD

Deploy Kubernetes manifests from S3 buckets instead of Git repositories using an Argo CD Config Management Plugin (CMP).

## Overview

This approach uses a CMP sidecar that:
1. Detects a trigger file (`s3-source.yaml`) in a Git repository
2. Downloads manifests from the specified S3 bucket/path
3. Outputs the manifests for Argo CD to apply

```
┌─────────────────────────────────────────────────────────────────┐
│  KIND Cluster                                                   │
│                                                                 │
│  ┌──────────────┐      ┌─────────────────────────────────────┐  │
│  │  LocalStack  │◄─────│  argocd-repo-server                 │  │
│  │  (S3 mock)   │      │  ┌─────────────┐ ┌───────────────┐  │  │
│  │              │      │  │ repo-server │ │ s3-cmp sidecar│  │  │
│  └──────────────┘      │  └─────────────┘ └───────────────┘  │  │
│                        └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- KIND cluster with ArgoCD installed (run `./scripts/setup.sh` from repo root)
- Docker (for building the CMP image)
- kubectl configured to access the cluster

## Quick Start

```bash
# From the repo root, ensure ArgoCD is running
./scripts/setup.sh

# Setup everything (LocalStack, CMP sidecar, sample manifests)
./cmp-s3/scripts/setup-all.sh

# Deploy the demo application
./cmp-s3/scripts/deploy-app.sh

# Check it's working
kubectl get application s3-demo-app -n argocd
kubectl get pods -n demo-app
```

## Step-by-Step Setup

### 1. Deploy LocalStack (S3 mock)

```bash
./cmp-s3/scripts/setup-localstack.sh
```

This deploys LocalStack in the `localstack` namespace and creates the `test-bucket` S3 bucket.

### 2. Build the CMP Plugin Image

```bash
./cmp-s3/scripts/build-plugin.sh
```

Builds the Docker image with AWS CLI and plugin configuration, then loads it into the KIND cluster.

### 3. Patch ArgoCD with the CMP Sidecar

```bash
./cmp-s3/scripts/patch-argocd.sh
```

Adds the S3 CMP sidecar container to the `argocd-repo-server` deployment.

### 4. Upload Sample Manifests to S3

```bash
./cmp-s3/scripts/upload-manifests.sh
```

Uploads the sample manifests from `sample-manifests/` to `s3://test-bucket/apps/demo-app/`.

### 5. Deploy the ArgoCD Application

```bash
./cmp-s3/scripts/deploy-app.sh
```

Creates an ArgoCD Application that uses the S3 CMP plugin.

## Testing Changes

### Update manifests and sync

```bash
# Edit the sample manifests
vim cmp-s3/sample-manifests/deployment.yaml

# Upload new versions to S3
./cmp-s3/scripts/upload-manifests.sh

# Trigger a sync
./cmp-s3/scripts/test-sync.sh
```

### View the deployed application

```bash
kubectl port-forward svc/demo-app -n demo-app 8081:80
curl http://localhost:8081
```

## How It Works

### The Trigger File

The `s3-source.yaml` file tells the CMP where to fetch manifests:

```yaml
bucket: test-bucket
path: apps/demo-app
version: v1.0.0  # Optional, for tracking
```

When Argo CD sees this file in a Git repo, the CMP plugin activates and fetches from S3.

### Plugin Lifecycle

1. **Discover**: CMP detects `s3-source.yaml` in the Git repo
2. **Init**: Downloads all `*.yaml` files from the S3 path
3. **Generate**: Outputs the downloaded manifests to stdout
4. Argo CD applies the manifests to the cluster

### Updating Deployments

Two ways to trigger a new deployment:

1. **Update S3 content**: Upload new manifests, then trigger a hard refresh
2. **Update trigger file**: Change the `version` field in `s3-source.yaml` and commit

## Directory Structure

```
cmp-s3/
├── README.md                     # This file
├── docs/
│   └── DESIGN.md                 # Technical design document
├── localstack/
│   └── deployment.yaml           # LocalStack Kubernetes manifests
├── plugin/
│   ├── Dockerfile                # CMP sidecar image
│   └── plugin.yaml               # CMP configuration
├── argocd-patch/
│   └── repo-server-patch.yaml    # Sidecar injection patch
├── trigger-repo/
│   └── demo-app/
│       └── s3-source.yaml        # Trigger file for demo app
├── sample-manifests/
│   ├── namespace.yaml            # Demo app namespace
│   ├── deployment.yaml           # Demo app deployment
│   └── service.yaml              # Demo app service
└── scripts/
    ├── setup-all.sh              # Complete setup (recommended)
    ├── setup-localstack.sh       # Deploy LocalStack
    ├── build-plugin.sh           # Build CMP image
    ├── patch-argocd.sh           # Add sidecar to repo-server
    ├── upload-manifests.sh       # Upload manifests to S3
    ├── deploy-app.sh             # Create ArgoCD Application
    ├── test-sync.sh              # Trigger sync and verify
    └── teardown.sh               # Remove all components
```

## Troubleshooting

### CMP not detecting the trigger file

Check that the sidecar is running:
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].spec.containers[*].name}'
```

Should output: `argocd-repo-server s3-cmp`

### S3 download fails

Check LocalStack is running:
```bash
kubectl get pods -n localstack
```

Verify the bucket exists:
```bash
kubectl run --rm -i aws-cli --image=amazon/aws-cli:2.15.0 -n localstack --restart=Never --command -- \
  aws --endpoint-url http://localstack:4566 s3 ls
```

### View CMP logs

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -c s3-cmp
```

### Application stuck in "Unknown" state

The CMP might be failing. Check the repo-server logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -c argocd-repo-server
```

## Cleanup

```bash
./cmp-s3/scripts/teardown.sh
```

## Production Considerations

This setup uses LocalStack for local testing. For production:

1. **Authentication**: Use IRSA (IAM Roles for Service Accounts) instead of static credentials
2. **Endpoint**: Remove `S3_ENDPOINT` env var to use real AWS S3
3. **Versioning**: Enable S3 bucket versioning for audit trail
4. **Encryption**: Enable S3 server-side encryption
5. **Webhooks**: Consider S3 event notifications for faster sync triggers

See `docs/DESIGN.md` for more details on design decisions and trade-offs.
