#!/bin/bash
set -x

# Directory where the GitOps services are defined, can be overridden by env var GITOPS_SERVICES_DIRECTORY
SERVICES_DIR="${GITOPS_SERVICES_DIRECTORY:-services}"

export CONTAINER_HOST=unix:///run/user/1000/podman/podman.sock

if [[ -z "$1" ]]; then
  echo "[GitOps] ERROR: No service name provided"
  exit 1
fi

echo "[GitOps] Switching to env-repo..."
cd /env-repo || exit 1

UPDATING_SERVICE_DIR="$SERVICES_DIR/$1"
if [[ ! -d "$UPDATING_SERVICE_DIR" ]]; then
  echo "[GitOps] ERROR: Service directory '$UPDATING_SERVICE_DIR' does not exist"
  exit 1
fi

if ! podman system connection exists host 2>/dev/null; then
  echo "[GitOps] Setting up podman remote connection..."
  podman system connection add host $CONTAINER_HOST
  podman system connection default host
fi

# Set up Docker remote connection to the host
if [[ -n "$CONTAINER_HOST" ]]; then
    echo "[GitOps] Setting up Docker remote context..."
    export DOCKER_HOST=unix:///var/run/docker.sock
fi

echo "[GitOps] Testing podman connection..."
if ! podman --remote info >/dev/null 2>&1; then
  echo "[GitOps] ERROR: Cannot connect to podman on host"
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

echo "[GitOps] Switching to desired service: $1"
pushd "$UPDATING_SERVICE_DIR" >/dev/null || exit 1

if [ -f "$UPDATING_SERVICE_DIR/custom-update.sh" ]; then
  "/env-repo/$UPDATING_SERVICE_DIR/custom-update.sh" "/env-repo/$UPDATING_SERVICE_DIR/"
  exit
else
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

  echo "[GitOps] Restarting and updating desired service: $1"
  CURRENT_HASH=$(cat "$COMPOSE_FILE" "$ENV_FILES_TO_HASH" 2>/dev/null | sha256sum | awk '{print $1}')
  LAST_HASH_FILE=".last-deploy-hash"
  $COMPOSE_CMD down
  $COMPOSE_CMD pull
  $COMPOSE_CMD up -d

  echo "$CURRENT_HASH" > "$LAST_HASH_FILE"
fi

popd >/dev/null || exit 1

echo "[GitOps] Deployment complete."
