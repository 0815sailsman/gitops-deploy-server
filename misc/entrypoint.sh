#!/bin/bash
set -x

export CONTAINER_HOST=unix:///run/user/1000/podman/podman.sock

# Step 1: Check and enter the directory
if [ -d "/env-repo/services/gitops-deploy-server" ]; then
  cd /env-repo/services/gitops-deploy-server || exit 1

  # Step 2: Determine active and inactive instance
  if [ -f ".active-instance" ]; then
    echo "active instance exists..."
    ACTIVE_INSTANCE=$(cat .active-instance)
    echo "has value $ACTIVE_INSTANCE"
    if [ "$ACTIVE_INSTANCE" = "A" ]; then
      INACTIVE_INSTANCE="B"
    else
      INACTIVE_INSTANCE="A"
    fi

    echo "inactive instance set to $INACTIVE_INSTANCE"

    # Step 3: Stop and remove the inactive instance
    echo "Stopping..."
    podman-compose -p "gitops-deploy-server-$INACTIVE_INSTANCE" down || true
    echo "Done"
  fi

  cd - > /dev/null || exit 1
fi

echo "Unpacking JRE"
zstd --decompress /opt/jre-minimal.tar.zst
tar -xf /opt/jre-minimal.tar -C /opt
rm /opt/jre-minimal.tar /opt/jre-minimal.tar.zst

export JAVA_HOME=/opt/jre-minimal
export PATH=$JAVA_HOME/bin:$PATH

echo "Starting webhook service..."
exec java -jar /app/app.jar
