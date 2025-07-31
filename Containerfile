# -------- Stage 1: Build minimal JRE --------
FROM alpine:latest as builder
RUN apk add --no-cache openjdk21-jdk binutils zstd dos2unix

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

COPY ./misc/entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh

# -------- Stage 2: Final image --------
FROM alpine:latest

RUN apk add --no-cache zstd bash
COPY --from=builder /opt/jre-minimal.tar.zst /opt/jre-minimal.tar.zst

WORKDIR /app
ENV JAVA_HOME=/opt/jre-minimal
ENV PATH="$PATH:$JAVA_HOME/bin"

COPY ./build/libs/gitops-deploy-server-all.jar /app/app.jar
COPY --from=builder /entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
