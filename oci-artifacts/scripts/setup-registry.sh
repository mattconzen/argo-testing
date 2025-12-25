#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCI_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="${OCI_DIR}/certs"

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5000"

echo "=== Setting up Local OCI Registry with TLS ==="

# Create certs directory
mkdir -p "${CERT_DIR}"

# Generate self-signed cert if it doesn't exist
if [ ! -f "${CERT_DIR}/registry.crt" ]; then
  echo "Generating self-signed TLS certificate..."
  openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
    -keyout "${CERT_DIR}/registry.key" \
    -out "${CERT_DIR}/registry.crt" \
    -subj "/CN=kind-registry" \
    -addext "subjectAltName=DNS:kind-registry,DNS:localhost,IP:127.0.0.1" \
    2>/dev/null
  echo "Certificate generated at ${CERT_DIR}/registry.crt"
else
  echo "Using existing certificate at ${CERT_DIR}/registry.crt"
fi

# Stop and remove existing registry if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
  echo "Removing existing registry..."
  docker stop "${REGISTRY_NAME}" 2>/dev/null || true
  docker rm "${REGISTRY_NAME}" 2>/dev/null || true
fi

# Create registry with TLS
echo "Creating registry container with TLS..."
docker run -d \
  --restart=always \
  -p "${REGISTRY_PORT}:5000" \
  --name "${REGISTRY_NAME}" \
  -v "${CERT_DIR}:/certs" \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  registry:2

# Get KIND cluster name
CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1)
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: No KIND clusters found"
  exit 1
fi

# Connect registry to KIND network if not already connected
if ! docker network inspect kind | grep -q "${REGISTRY_NAME}"; then
  echo "Connecting registry to KIND network..."
  docker network connect kind "${REGISTRY_NAME}" 2>/dev/null || true
fi

# Configure KIND nodes to use the local registry
# This creates a ConfigMap that tells containerd about the registry
echo "Configuring KIND nodes to use local registry..."
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  # Add registry config to containerd
  docker exec "$node" bash -c "
    mkdir -p /etc/containerd/certs.d/localhost:${REGISTRY_PORT}
    cat > /etc/containerd/certs.d/localhost:${REGISTRY_PORT}/hosts.toml << EOF
[host.\"http://${REGISTRY_NAME}:5000\"]
EOF
  " 2>/dev/null || true

  # Also add to /etc/hosts for in-cluster access
  docker exec "$node" bash -c "
    grep -q '${REGISTRY_NAME}' /etc/hosts || echo '127.0.0.1 ${REGISTRY_NAME}' >> /etc/hosts
  " 2>/dev/null || true
done

# Create ConfigMap for registry discovery (used by some tools)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Add TLS cert to ArgoCD for registry trust
echo "Adding TLS certificate to ArgoCD..."
kubectl create configmap argocd-tls-certs-cm \
  --from-file=kind-registry="${CERT_DIR}/registry.crt" \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Add repository secret for OCI registry
echo "Configuring ArgoCD repository..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oci-registry
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: helm
  name: kind-registry
  url: kind-registry:5000
  enableOCI: "true"
  insecure: "true"
EOF

# Restart repo-server to pick up the cert
echo "Restarting ArgoCD repo-server..."
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s

echo ""
echo "=== Registry setup complete ==="
echo ""
echo "Registry available at:"
echo "  - From host: localhost:${REGISTRY_PORT} (HTTPS)"
echo "  - From cluster: ${REGISTRY_NAME}:5000 (HTTPS)"
echo ""
echo "Test with: curl -k https://localhost:${REGISTRY_PORT}/v2/_catalog"
