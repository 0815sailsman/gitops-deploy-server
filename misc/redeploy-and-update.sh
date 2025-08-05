#!/bin/bash
set -e

export CONTAINER_HOST=unix:///run/podman/podman.sock

if [[ -z "$1" ]]; then
  echo "[GitOps] ERROR: No service name provided"
  exit 1
fi

echo "[GitOps] Switching to env-repo..."
cd /env-repo

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
pushd "$SERVICE_DIR" >/dev/null

echo "[GitOps] Restarting and updating desired service: $1"
podman-compose down
podman-compose pull
podman-compose up -d

popd >/dev/null

echo "[GitOps] Deployment complete."
