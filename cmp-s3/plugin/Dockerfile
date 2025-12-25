FROM alpine:3.19

# Install AWS CLI and required tools
RUN apk add --no-cache \
    aws-cli \
    bash \
    && rm -rf /var/cache/apk/*

# Copy plugin configuration
COPY plugin.yaml /home/argocd/cmp-server/config/plugin.yaml

# Create argocd user directory
RUN mkdir -p /home/argocd/cmp-server/plugins && \
    chown -R 999:999 /home/argocd

# Run as argocd user (UID 999)
USER 999

# The entrypoint is provided by the shared volume from argocd-repo-server
ENTRYPOINT ["/var/run/argocd/argocd-cmp-server"]
