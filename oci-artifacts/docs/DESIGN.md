# OCI Artifacts Approach Design

## Problem Statement

Same as the S3 CMP approach: CI/CD workflows produce deployment artifacts that need to be deployed by Argo CD without committing manifests to Git.

## Solution: OCI Artifacts

Argo CD natively supports OCI artifacts as a source type (since v2.4). This allows:
- Packaging Kubernetes manifests as OCI artifacts
- Pushing to any OCI-compliant registry
- Argo CD pulling and deploying directly

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  KIND Cluster                                                   │
│                                                                 │
│  ┌──────────────────┐      ┌─────────────────────────────────┐  │
│  │  Local Registry  │◄─────│  ArgoCD                         │  │
│  │  (port 5000)     │      │  (native OCI support)           │  │
│  │                  │      │                                 │  │
│  │  demo-app:v1.0.0 │      │  Application:                   │  │
│  │  demo-app:latest │      │    source: oci://registry:5000  │  │
│  └──────────────────┘      └─────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         ▲
         │ oras push
         │
    CI Pipeline (simulated)
```

### Components

| Component | Purpose |
|-----------|---------|
| Local Registry | OCI-compliant registry running alongside KIND |
| ORAS CLI | Tool for pushing OCI artifacts (non-container content) |
| ArgoCD Application | Uses native `oci://` source type |

### Flow

1. CI packages manifests using `oras push`
2. Pushes to `registry:5000/demo-app:v1.0.0`
3. ArgoCD Application references `oci://registry:5000/demo-app`
4. Argo pulls artifact, extracts manifests, applies to cluster

## Comparison with S3 CMP Approach

| Aspect | S3 CMP | OCI Artifacts |
|--------|--------|---------------|
| Custom plugin | Required | Not needed |
| ArgoCD patching | Yes (sidecar) | No |
| Trigger mechanism | Git file | Direct polling |
| Tooling | AWS CLI | ORAS CLI |
| Native support | No | Yes (v2.4+) |
| Complexity | High | Low |

## Design Decisions

### Why OCI Artifacts?

1. **Native support** — No custom plugins or sidecars needed
2. **Standard tooling** — ORAS is a CNCF project, widely adopted
3. **Registry reuse** — Use existing container registry infrastructure
4. **Versioning** — Tags and digests provide clear versioning

### Why Local Registry?

- No external dependencies for local testing
- KIND has documented patterns for local registry integration
- Fast iteration without network latency

### Versioning Strategy

- **Tagged releases** (`v1.0.0`) — For production deployments
- **Latest tag** — For dev environments, Argo detects digest changes
- **Digest pinning** — For immutable deployments

## OCI Artifact Format

Using ORAS to push raw YAML files:

```bash
oras push registry:5000/demo-app:v1.0.0 \
  --config /dev/null:application/vnd.oci.empty.v1+json \
  ./:application/vnd.oci.image.layer.v1.tar+gzip
```

Argo CD expects the artifact to contain Kubernetes manifests at the root or in the specified path.

## Future Improvements

1. **Helm chart packaging** — Push Helm charts as OCI artifacts
2. **Signature verification** — Use cosign for artifact signing
3. **Multi-arch support** — Index manifests for different clusters
4. **SBOM attachment** — Attach software bill of materials
