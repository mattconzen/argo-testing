#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP_DIR="$(dirname "$SCRIPT_DIR")"

S3_PATH="${1:-apps/demo-app}"
MANIFEST_DIR="${2:-$CMP_DIR/sample-manifests}"

echo "=== Uploading manifests to S3 ==="
echo "Source: $MANIFEST_DIR"
echo "Destination: s3://test-bucket/$S3_PATH/"

# Create a temporary pod to upload files
# We'll use a ConfigMap to hold the manifests, then upload from there

# First, create a ConfigMap with the manifests
echo "Creating temporary ConfigMap with manifests..."
kubectl create configmap manifest-upload \
  --namespace=localstack \
  --from-file="$MANIFEST_DIR" \
  --dry-run=client -o yaml | kubectl apply -f -

# Run upload job
echo "Uploading to S3..."
kubectl run --rm -i --restart=Never manifest-uploader \
  --image=amazon/aws-cli:2.15.0 \
  --namespace=localstack \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "manifest-uploader",
        "image": "amazon/aws-cli:2.15.0",
        "command": ["/bin/sh", "-c"],
        "args": ["for f in /manifests/*; do aws --endpoint-url http://localstack:4566 s3 cp \"$f\" \"s3://test-bucket/'"$S3_PATH"'/$(basename $f)\"; done && echo Done"],
        "env": [
          {"name": "AWS_ACCESS_KEY_ID", "value": "test"},
          {"name": "AWS_SECRET_ACCESS_KEY", "value": "test"},
          {"name": "AWS_DEFAULT_REGION", "value": "us-east-1"}
        ],
        "volumeMounts": [{
          "name": "manifests",
          "mountPath": "/manifests"
        }]
      }],
      "volumes": [{
        "name": "manifests",
        "configMap": {
          "name": "manifest-upload"
        }
      }]
    }
  }'

# Clean up ConfigMap
kubectl delete configmap manifest-upload -n localstack

# Verify upload
echo ""
echo "Verifying upload..."
kubectl run --rm -i --restart=Never s3-ls \
  --image=amazon/aws-cli:2.15.0 \
  --namespace=localstack \
  --env="AWS_ACCESS_KEY_ID=test" \
  --env="AWS_SECRET_ACCESS_KEY=test" \
  --env="AWS_DEFAULT_REGION=us-east-1" \
  --command -- \
  aws --endpoint-url http://localstack:4566 \
  s3 ls "s3://test-bucket/$S3_PATH/" --recursive

echo ""
echo "=== Upload complete ==="
