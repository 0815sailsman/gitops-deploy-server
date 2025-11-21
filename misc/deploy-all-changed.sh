#!/bin/bash
set -x

# Directory where the GitOps services are defined, can be overridden by env var GITOPS_SERVICES_DIRECTORY
SERVICES_DIR="${GITOPS_SERVICES_DIRECTORY:-services}"

# Export CONTAINER_HOST for podman-compose to use remote connection
export CONTAINER_HOST=unix:///run/user/1000/podman/podman.sock

echo "[GitOps] Switching to env-repo..."
cd /env-repo || exit 1

echo "[GitOps] Pulling latest changes..."
git pull

# Set up podman remote connection if not already done
if ! podman system connection exists host 2>/dev/null; then
    echo "[GitOps] Setting up podman remote connection..."
    podman system connection add host "$CONTAINER_HOST"
    podman system connection default host
fi

# Set up Docker remote connection to the host
if [[ -n "$CONTAINER_HOST" ]]; then
    echo "[GitOps] Setting up Docker remote context..."
    export DOCKER_HOST=unix:///var/run/docker.sock
fi


# Test connection
echo "[GitOps] Testing podman connection..."
if ! podman --remote info >/dev/null 2>&1; then
    echo "[GitOps] ERROR: Cannot connect to podman on host"
    echo "[GitOps] Make sure podman.socket is running: systemctl --user enable --now podman.socket"
    exit 1
fi

# Test Docker connection
echo "[GitOps] Testing Docker connection..."
if ! docker info >/dev/null 2>&1; then
    echo "[GitOps] WARNING: Cannot connect to Docker on host via DOCKER_HOST."
    echo "[GitOps] This is only an issue if you use docker-compose.yml files."
else
    echo "[GitOps] Docker connection successful."
fi

if [[ -f "secrets/ghcr.cred" ]]; then
  podman login ghcr.io -u "$GHCR_USER" --password-stdin < secrets/ghcr.cred
fi

# Process all services except gitops-deploy-server
for dir in "$SERVICES_DIR"/*; do
  svc_name=$(basename "$dir")
  if [[ "$svc_name" == "gitops-deploy-server" ]]; then
    continue
  fi

  echo "[GitOps] Checking service: $svc_name"
  pushd "$dir" >/dev/null || exit 1

  COMPOSE_CMD=""
  COMPOSE_FILE=""
  ENV_FILES_TO_HASH=".env" # .env is common

  # Detect which compose tool to use, preferring podman-compose
  if [[ -f "podman-compose.yml" ]]; then
    COMPOSE_CMD="podman-compose"
    COMPOSE_FILE="podman-compose.yml"
    ENV_FILES_TO_HASH=".env .podman-compose.env"
  elif [[ -f "docker-compose.yml" ]]; then
    COMPOSE_CMD="docker compose"
    COMPOSE_FILE="docker-compose.yml"
  fi

  if [[ -z "$COMPOSE_CMD" ]]; then
    echo "[GitOps] → No compose file found. Skipping $svc_name."
    popd >/dev/null || exit 1
    continue
  fi

  # Build hash from compose + env + any config
  CURRENT_HASH=$(cat "$COMPOSE_FILE" "$ENV_FILES_TO_HASH" 2>/dev/null | sha256sum | awk '{print $1}')
  LAST_HASH_FILE=".last-deploy-hash"

  if [[ ! -f "$LAST_HASH_FILE" ]] || [[ "$CURRENT_HASH" != "$(cat $LAST_HASH_FILE)" ]]; then
    echo "[GitOps] → Changes detected for $svc_name. Restarting with $COMPOSE_CMD..."
    $COMPOSE_CMD down
    $COMPOSE_CMD up -d
    echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
  else
    echo "[GitOps] → No changes. Skipping $svc_name."
  fi

  popd >/dev/null || exit 1
done

# --- Special handling for gitops-deploy-server (A/B self-update) ---
GITOPS_DIR="$SERVICES_DIR/${DEPLOY_SERVER_NAME:-gitops-deploy-server}"
if [[ ! -d "$GITOPS_DIR" ]]; then
  echo "[GitOps] Skipping $GITOPS_DIR: directory does not exist."
else
  INSTANCE_FILE=".active-instance"
  APP_NAME=${DEPLOY_SERVER_NAME:-gitops-deploy-server}

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
