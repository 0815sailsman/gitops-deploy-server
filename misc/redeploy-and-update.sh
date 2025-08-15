#!/bin/bash
set -x

export CONTAINER_HOST=unix:///run/podman/podman.sock

if [[ -z "$1" ]]; then
  echo "[GitOps] ERROR: No service name provided"
  exit 1
fi

echo "[GitOps] Switching to env-repo..."
cd /env-repo || exit 1

SERVICE_DIR="services/$1"
if [[ ! -d "$SERVICE_DIR" ]]; then
  echo "[GitOps] ERROR: Service directory '$SERVICE_DIR' does not exist"
  exit 1
fi

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

echo "[GitOps] Switching to desired service: $1"
pushd "$SERVICE_DIR" >/dev/null || exit 1

if [[ "$SERVICE_DIR" == "gitops-deploy-server" ]]; then
  echo "Special handling for gitops deploy server"
  CURRENT_HASH=$(cat podman-compose.yml .env 2>/dev/null | sha256sum | awk '{print $1}')
    LAST_HASH_FILE=".last-deploy-hash"

    if [[ ! -f "$LAST_HASH_FILE" ]] || [[ "$CURRENT_HASH" != "$(cat $LAST_HASH_FILE)" ]]; then
      echo "[GitOps] → Changes detected. Performing A/B self-update..."

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
      podman-compose -p "$NEXT_CONTAINER" up -d
    else
      echo "[GitOps] → No changes. Skipping $APP_NAME."
    fi
else
  export HOST_PORT=1338
fi

echo "[GitOps] Restarting and updating desired service: $1"
podman-compose down
podman-compose pull
podman-compose up -d

popd >/dev/null || exit 1

echo "[GitOps] Deployment complete."
