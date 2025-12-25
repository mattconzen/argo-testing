#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Setting up LocalStack ==="

# Deploy LocalStack
echo "Deploying LocalStack to cluster..."
kubectl apply -f "$CMP_DIR/localstack/deployment.yaml"

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/localstack -n localstack

# Wait a few more seconds for S3 service to initialize
sleep 5

# Create the test bucket
echo "Creating S3 bucket..."
kubectl run --rm -i --restart=Never aws-cli \
  --image=amazon/aws-cli:2.15.0 \
  --namespace=localstack \
  --env="AWS_ACCESS_KEY_ID=test" \
  --env="AWS_SECRET_ACCESS_KEY=test" \
  --env="AWS_DEFAULT_REGION=us-east-1" \
  --command -- \
  aws --endpoint-url http://localstack:4566 \
  s3 mb s3://test-bucket \
  2>/dev/null || echo "Bucket may already exist"

echo "=== LocalStack setup complete ==="
echo ""
echo "LocalStack is available at:"
echo "  - In-cluster: http://localstack.localstack.svc.cluster.local:4566"
echo "  - Port-forward: kubectl port-forward -n localstack svc/localstack 4566:4566"
