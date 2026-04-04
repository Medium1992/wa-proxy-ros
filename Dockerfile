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

RUN apk add --no-cache haproxy curl openssl jq bash

COPY --from=source /src/repo/proxy/src/ /usr/local/bin/

WORKDIR /certs
RUN chmod +x /usr/local/bin/generate-certs.sh /usr/local/bin/set_public_ip_and_start.sh /usr/local/bin/healthcheck.sh \
 && /usr/local/bin/generate-certs.sh \
 && mkdir -p /etc/haproxy/ssl \
 && mv /certs/proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem \
 && mkdir -p /root/certs \
 && sed -i 's|/home/haproxy/certs|/root/certs|g' /usr/local/bin/set_public_ip_and_start.sh \
 && sed -i '/chown haproxy:haproxy/d' /usr/local/bin/set_public_ip_and_start.sh \
 && haproxy -c -V -f /usr/local/etc/haproxy/haproxy.cfg

USER root
HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/set_public_ip_and_start.sh"]
