#!/bin/sh

echo "Unpacking JRE"
zstd --decompress /opt/jre-minimal.tar.zst
tar -xf /opt/jre-minimal.tar -C /opt
rm /opt/jre-minimal.tar /opt/jre-minimal.tar.zst

export JAVA_HOME=/opt/jre-minimal
export PATH=$JAVA_HOME/bin:$PATH

echo "Starting webhook service..."
exec java -jar /app/app.jar
