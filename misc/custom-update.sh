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

cd $1

podman compose run \
          --rm \
          -e UPDATE_MODE=TRUE \
          -f podman-compose.yml \
          -f /updater-overrides.yml \
          --name gitops-updater \
          gitops-deploy-server
