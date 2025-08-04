#!/bin/bash
set -e

# Export CONTAINER_HOST for podman-compose to use remote connection
export CONTAINER_HOST=unix:///run/user/1000/podman/podman.sock

echo "[GitOps] Switching to env-repo..."
cd /env-repo

echo "[GitOps] Pulling latest changes..."
git pull

# Set up podman remote connection if not already done
if ! podman system connection exists host 2>/dev/null; then
    echo "[GitOps] Setting up podman remote connection..."
    podman system connection add host unix:///run/user/1000/podman/podman.sock
    podman system connection default host
fi

# Test connection
echo "[GitOps] Testing podman connection..."
if ! podman --remote info >/dev/null 2>&1; then
    echo "[GitOps] ERROR: Cannot connect to podman on host"
    echo "[GitOps] Make sure podman.socket is running: systemctl --user enable --now podman.socket"
    exit 1
fi

for dir in services/*; do
  svc_name=$(basename "$dir")
  echo "[GitOps] Checking service: $svc_name"

  pushd "$dir" >/dev/null

  # Build hash from compose + env + any config
  CURRENT_HASH=$(cat podman-compose.yml .env 2>/dev/null | sha256sum | awk '{print $1}')
  LAST_HASH_FILE=".last-deploy-hash"

  if [[ ! -f "$LAST_HASH_FILE" ]] || [[ "$CURRENT_HASH" != "$(cat $LAST_HASH_FILE)" ]]; then
    echo "[GitOps] → Changes detected. Restarting $svc_name..."

    # Use remote connection via CONTAINER_HOST
    podman-compose down
    podman-compose up -d

    echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
  else
    echo "[GitOps] → No changes. Skipping $svc_name."
  fi

  popd >/dev/null
done

echo "[GitOps] Deployment complete."