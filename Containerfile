# -------- Stage 1: Build minimal JRE --------
FROM alpine:latest as builder
RUN apk add --no-cache openjdk21-jdk binutils zstd

ENV MODULES="java.base,java.logging,java.management,java.instrument,jdk.unsupported,java.xml,java.naming"
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk

RUN jlink \
    --module-path "$JAVA_HOME/jmods" \
    --verbose \
    --strip-debug \
    --no-header-files \
    --compress zip-0 \
    --no-man-pages \
    --add-modules $MODULES \
    --output /opt/jre-minimal

WORKDIR /opt
RUN tar -cf jre-minimal.tar jre-minimal
RUN zstd --ultra -22 /opt/jre-minimal.tar

# -------- Stage 2: Final image --------
FROM alpine:latest

RUN apk add --no-cache zstd bash podman-remote podman-compose git coreutils docker-cli docker-cli-compose

COPY --from=builder /opt/jre-minimal.tar.zst /opt/jre-minimal.tar.zst

WORKDIR /app
ENV JAVA_HOME=/opt/jre-minimal
ENV PATH="$PATH:$JAVA_HOME/bin"

COPY ./misc/entrypoint.sh /entrypoint.sh
COPY ./misc/deploy-all-changed.sh /deploy-all-changed.sh
COPY ./misc/redeploy-and-update.sh /redeploy-and-update.sh
COPY ./misc/self-update.sh /self-update.sh
COPY ./misc/updater-overrides.yml /updater-overrides.yml

RUN chmod +x /entrypoint.sh
RUN chmod +x /deploy-all-changed.sh
RUN chmod +x /redeploy-and-update.sh
RUN chmod +x /self-update.sh

ENTRYPOINT ["/entrypoint.sh"]
