# S3 Config Management Plugin Design

## Problem Statement

Argo CD natively supports Git, Helm, and OCI repositories as manifest sources. However, some CI/CD workflows produce deployment artifacts that are stored in S3 rather than committed to Git. This creates a gap where:

- CI pipelines build and validate manifests
- Manifests are stored in S3 as versioned artifacts
- Argo CD cannot directly consume these artifacts

## Use Case

**Artifact Pipeline Output**: CI builds Kubernetes manifests, stores them in S3, and Argo CD deploys them. This decouples deployment artifacts from Git commit history.

## Solution: Config Management Plugin (CMP)

We implement an Argo CD Config Management Plugin that:

1. Detects a trigger file (`s3-source.yaml`) in a Git repository
2. Downloads manifests from the specified S3 bucket/path
3. Outputs the manifests for Argo CD to apply

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  KIND Cluster                                                   │
│                                                                 │
│  ┌──────────────┐      ┌─────────────────────────────────────┐  │
│  │  LocalStack  │      │  argocd-repo-server                 │  │
│  │  (S3 mock)   │◄─────│  ┌─────────────┐ ┌───────────────┐  │  │
│  │              │      │  │ repo-server │ │ s3-cmp sidecar│  │  │
│  │  Port: 4566  │      │  │   (main)    │ │  - aws cli    │  │  │
│  └──────────────┘      │  └─────────────┘ └───────────────┘  │  │
│         ▲              └─────────────────────────────────────┘  │
│         │                                                       │
│    s3://test-bucket/                                            │
│    └── apps/                                                    │
│        └── demo-app/                                            │
│            ├── deployment.yaml                                  │
│            └── service.yaml                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Purpose |
|-----------|---------|
| LocalStack | In-cluster S3-compatible storage for local testing |
| S3 CMP Sidecar | Container with AWS CLI, runs alongside argocd-repo-server |
| plugin.yaml | Defines discover, init, and generate hooks |
| s3-source.yaml | Trigger file specifying S3 bucket and path |

### Flow

1. CI (simulated) uploads manifests to `s3://test-bucket/apps/demo-app/`
2. Argo Application references a Git repo containing `s3-source.yaml`
3. CMP sidecar detects the trigger file, runs `init` to download from S3
4. CMP runs `generate` to output manifests to stdout
5. Argo applies manifests to cluster

## Design Decisions

### Why CMP over other approaches?

| Approach | Pros | Cons |
|----------|------|------|
| **CMP (chosen)** | Native Argo integration, real-time | Requires sidecar, trigger file in Git |
| S3-to-Git sync | Pure GitOps, simpler | Latency, extra infrastructure |
| Custom controller | Full control | Complex, maintenance burden |

### Why LocalStack for testing?

- No AWS credentials needed for local development
- Runs in-cluster, no external dependencies
- Easy to reset/recreate buckets

### Why polling over webhooks?

- Simpler setup (no external infrastructure)
- Argo already has built-in refresh intervals
- Sufficient for most use cases (3-minute default)

### Error Handling

- **Empty bucket/path**: Fail the sync (strict behavior)
- **S3 unreachable**: Fail the sync with clear error message
- **Invalid YAML**: Argo's normal validation catches this

## Trigger File Format

```yaml
# s3-source.yaml
bucket: test-bucket
path: apps/demo-app
version: v1.0.0  # Optional, for tracking/cache-busting
```

The `version` field is informational. Changing it in Git triggers a new sync even if S3 content hasn't changed, useful for forcing re-deploys.

## Future Improvements

1. **Real AWS support**: Add IRSA/Pod Identity authentication
2. **Webhook triggers**: S3 event notifications → Argo refresh
3. **Tarball support**: Extract `.tar.gz` archives
4. **Helm chart support**: Fetch and template Helm charts from S3
5. **Multi-path support**: Multiple S3 sources in one trigger file
