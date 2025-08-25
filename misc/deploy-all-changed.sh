#!/bin/bash
set -x

# Export CONTAINER_HOST for podman-compose to use remote connection
export CONTAINER_HOST=unix:///run/podman/podman.sock

echo "[GitOps] Switching to env-repo..."
cd /env-repo || exit 1

if [[ -f "secrets/ghcr.cred" ]]; then
  podman login ghcr.io -u "$GHCR_USER" --password-stdin < secrets/ghcr.cred
fi

echo "[GitOps] Pulling latest changes..."
git pull

# Set up podman remote connection if not already done
if ! podman system connection exists host 2>/dev/null; then
    echo "[GitOps] Setting up podman remote connection..."
    podman system connection add host $CONTAINER_HOST
    podman system connection default host
fi

# Test connection
echo "[GitOps] Testing podman connection..."
if ! podman --remote info >/dev/null 2>&1; then
    echo "[GitOps] ERROR: Cannot connect to podman on host"
    echo "[GitOps] Make sure podman.socket is running: systemctl --user enable --now podman.socket"
    exit 1
fi

# Process all services except gitops-deploy-server
for dir in services/*; do
  svc_name=$(basename "$dir")
  if [[ "$svc_name" == "gitops-deploy-server" ]]; then
    continue
  fi

  echo "[GitOps] Checking service: $svc_name"
  pushd "$dir" >/dev/null || exit 1

  # Build hash from compose + env + any config
  CURRENT_HASH=$(cat podman-compose.yml .env .podman-compose.env 2>/dev/null | sha256sum | awk '{print $1}')
  LAST_HASH_FILE=".last-deploy-hash"

  if [[ ! -f "$LAST_HASH_FILE" ]] || [[ "$CURRENT_HASH" != "$(cat $LAST_HASH_FILE)" ]]; then
    echo "[GitOps] → Changes detected. Restarting $svc_name..."
    podman-compose down
    podman-compose up -d
    echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
  else
    echo "[GitOps] → No changes. Skipping $svc_name."
  fi

  popd >/dev/null || exit 1
done

# --- Special handling for gitops-deploy-server (A/B self-update) ---
GITOPS_DIR="services/gitops-deploy-server"
if [[ ! -d "$GITOPS_DIR" ]]; then
  echo "[GitOps] Skipping $GITOPS_DIR: directory does not exist."
else
  INSTANCE_FILE=".active-instance"
  APP_NAME="gitops-deploy-server"

  echo "[GitOps] Checking service: $APP_NAME"
  pushd "$GITOPS_DIR" >/dev/null || exit 1

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

  popd >/dev/null || exit 1
fi

echo "[GitOps] Deployment complete."