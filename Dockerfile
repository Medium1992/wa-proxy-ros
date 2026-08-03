FROM alpine:latest AS source

ARG UPSTREAM_REPO="https://github.com/WhatsApp/proxy.git"
ARG UPSTREAM_REF="main"

RUN apk add --no-cache git ca-certificates \
 && set -eux; \
    test -n "${UPSTREAM_REF}"; \
    git init /src/repo; \
    cd /src/repo; \
    git remote add origin "${UPSTREAM_REPO}"; \
    git fetch --depth 1 origin "${UPSTREAM_REF}"; \
    git checkout --detach FETCH_HEAD

FROM haproxy:lts-alpine

USER root
RUN apk --no-cache add curl openssl jq bash

RUN --mount=from=source,src=/src/repo/proxy/src,target=/tmp/src \
    set -eux; \
    install -Dm755 /tmp/src/generate-certs.sh /usr/local/bin/generate-certs.sh; \
    install -Dm755 /tmp/src/start.sh /usr/local/bin/start.sh; \
    install -Dm755 /tmp/src/healthcheck.sh /usr/local/bin/healthcheck.sh; \
    install -Dm644 /tmp/src/proxy_config.cfg /usr/local/etc/haproxy/haproxy.cfg; \
    mkdir -p /certs /etc/haproxy/ssl /home/haproxy/certs; \
    cd /certs; \
    /usr/local/bin/generate-certs.sh; \
    mv proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem; \
    chown -R haproxy:haproxy /etc/haproxy /home/haproxy/certs; \
    haproxy -c -V -f /usr/local/etc/haproxy/haproxy.cfg

USER root

HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/start.sh"]
