FROM alpine:latest AS source

ARG UPSTREAM_REPO="https://github.com/WhatsApp/proxy.git"
ARG UPSTREAM_REF="main"

RUN apk add --no-cache git ca-certificates \
 && set -eux; \
    REF="${UPSTREAM_REF}"; \
    test -n "${REF}"; \
    git init /src/repo; \
    cd /src/repo; \
    git remote add origin "$UPSTREAM_REPO"; \
    git fetch --depth 1 origin "$REF"; \
    git checkout --detach FETCH_HEAD

FROM alpine:latest

RUN --mount=from=source,src=/src/repo/proxy/src,target=/tmp/src \
    set -eux; \
    apk add --no-cache haproxy curl openssl jq bash; \
    install -Dm755 /tmp/src/generate-certs.sh /usr/local/bin/generate-certs.sh; \
    install -Dm755 /tmp/src/set_public_ip_and_start.sh /usr/local/bin/set_public_ip_and_start.sh; \
    install -Dm755 /tmp/src/healthcheck.sh /usr/local/bin/healthcheck.sh; \
    install -Dm644 /tmp/src/proxy_config.cfg /usr/local/etc/haproxy/haproxy.cfg; \
    cp /usr/local/etc/haproxy/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg.template; \
    printf '%s\n' '#!/bin/bash' 'set -e' 'cp /usr/local/etc/haproxy/haproxy.cfg.template /usr/local/etc/haproxy/haproxy.cfg' 'exec /usr/local/bin/set_public_ip_and_start.sh' > /usr/local/bin/start_with_cfg_reset.sh; \
    chmod +x /usr/local/bin/start_with_cfg_reset.sh; \
    mkdir -p /work /etc/haproxy/ssl /root/certs; \
    cd /work; \
    /usr/local/bin/generate-certs.sh; \
    mv /work/proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem; \
    sed -i 's|/home/haproxy/certs|/root/certs|g' /usr/local/bin/set_public_ip_and_start.sh; \
    sed -i '/chown haproxy:haproxy/d' /usr/local/bin/set_public_ip_and_start.sh; \
    haproxy -c -V -f /usr/local/etc/haproxy/haproxy.cfg; \
    rm -rf /work

HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/start_with_cfg_reset.sh"]
