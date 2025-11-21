#!/bin/bash
set -xeou pipefail

export CONTAINER_HOST=unix:///run/user/1000/podman/podman.sock

if ! podman system connection exists host 2>/dev/null; then
  echo "[GitOps] Setting up podman remote connection..."
  podman system connection add host $CONTAINER_HOST
  podman system connection default host
fi

echo "[GitOps] Testing podman connection..."
if ! podman --remote info >/dev/null 2>&1; then
  echo "[GitOps] ERROR: Cannot connect to podman on host"
  exit 1
fi

INSTANCE_FILE=".active-instance"
APP_NAME=${DEPLOY_SERVER_NAME:-gitops-deploy-server}
echo "Special handling for gitops deploy server"
CURRENT_HASH=$(cat podman-compose.yml .env 2>/dev/null | sha256sum | awk '{print $1}')
LAST_HASH_FILE=".last-deploy-hash"

echo "[GitOps] Performing A/B self-update..."

# Determine current and next instance
if [[ -f "$INSTANCE_FILE" ]]; then
  CURRENT_INSTANCE=$(cat "$INSTANCE_FILE")
else
  CURRENT_INSTANCE="A"
fi
if [[ "$CURRENT_INSTANCE" == "A" ]]; then
  NEXT_INSTANCE="B"
else
  NEXT_INSTANCE="A"
fi

NEXT_CONTAINER="${APP_NAME}-${NEXT_INSTANCE}"

if [[ "$NEXT_INSTANCE" == "A" ]]; then
  export HOST_PORT=1337
else
  export HOST_PORT=1338
fi

# Update active instance file and hash
echo "$NEXT_INSTANCE" > "$INSTANCE_FILE"
echo "$CURRENT_HASH" > "$LAST_HASH_FILE"

# Start new instance
echo "[GitOps] Starting new instance: $NEXT_CONTAINER"
podman-compose down
podman-compose -p "$NEXT_CONTAINER" up -d
