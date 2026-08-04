# syntax=docker/dockerfile:1.7
FROM --platform=$BUILDPLATFORM alpine:latest AS source

ARG UPSTREAM_REPO="https://github.com/WhatsApp/proxy.git"
ARG UPSTREAM_REF="main"

RUN apk add --no-cache git ca-certificates \
 && set -eux; \
    test -n "${UPSTREAM_REF}"; \
    git init /src/repo; \
    cd /src/repo; \
    git remote add origin "${UPSTREAM_REPO}"; \
    git fetch --depth 1 origin "${UPSTREAM_REF}"; \
    git checkout --detach FETCH_HEAD; \
    sed -i '/^chown haproxy:haproxy /d' proxy/src/start.sh; \
    mkdir -p /runtime/usr/local/bin /runtime/usr/local/etc/haproxy \
             /runtime/certs /runtime/etc/haproxy/ssl /runtime/home/haproxy/certs; \
    cp proxy/src/generate-certs.sh /runtime/usr/local/bin/generate-certs.sh; \
    cp proxy/src/start.sh /runtime/usr/local/bin/start.sh; \
    cp proxy/src/healthcheck.sh /runtime/usr/local/bin/healthcheck.sh; \
    cp proxy/src/proxy_config.cfg /runtime/usr/local/etc/haproxy/haproxy.cfg; \
    printf '%s\n' \
      '#!/bin/sh' \
      'SHUTTING_DOWN=0' \
      'fast_shutdown() {' \
      '  trap - TERM INT' \
      '  [ "$SHUTTING_DOWN" = 1 ] && exit 0' \
      '  SHUTTING_DOWN=1' \
      '  exit 0' \
      '}' \
      'trap fast_shutdown TERM INT' \
      '/usr/local/bin/start.sh &' \
      'PROXY_PID=$!' \
      'wait "$PROXY_PID"' \
      'exit $?' > /runtime/usr/local/bin/entrypoint.sh; \
    chmod 755 /runtime/usr/local/bin/*.sh

FROM --platform=linux/amd64 alpine:latest AS linux-amd64
RUN apk add --no-cache haproxy curl openssl jq bash

FROM --platform=linux/arm64 alpine:latest AS linux-arm64
RUN apk add --no-cache haproxy curl openssl jq bash

FROM --platform=linux/arm/v7 alpine:latest AS linux-armv7
RUN apk add --no-cache haproxy curl openssl jq bash

FROM --platform=linux/arm/v5 scratch AS linux-armv5
ADD rootfs.tar /

FROM ${TARGETOS}-${TARGETARCH}${TARGETVARIANT}
USER root
COPY --from=source /runtime/ /

HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/entrypoint.sh"]
