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
    printf '%s\n' '#!/bin/bash' 'set -e' 'cp /usr/local/etc/haproxy/haproxy.cfg.template /usr/local/etc/haproxy/haproxy.cfg' 'rm -f /etc/haproxy/ssl/proxy.whatsapp.net.pem' 'echo "[PROXYHOST] HAProxy listen ports: 80/tcp, 8080/tcp, 443/tcp, 8443/tcp, 5222/tcp, 8222/tcp, 8199/tcp, 587/tcp, 7777/tcp"' 'exec /usr/local/bin/set_public_ip_and_start.sh' > /usr/local/bin/start_with_cfg_reset.sh; \
    chmod +x /usr/local/bin/start_with_cfg_reset.sh; \
    mkdir -p /etc/haproxy/ssl /root/certs; \
    sed -i 's|/home/haproxy/certs|/root/certs|g' /usr/local/bin/set_public_ip_and_start.sh; \
    sed -i '/chown haproxy:haproxy/d' /usr/local/bin/set_public_ip_and_start.sh; \
    cat > /usr/local/bin/set_public_ip_and_start.sh <<'EOF'
#!/bin/bash
set -e

CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"

function fetch() {
  curl --silent --show-error --fail --ipv4 --max-time 2 "$@"
}

if [[ $PUBLIC_IP == '' ]]
then
    echo "[PROXYHOST] No public IP address was supplied as an environment variable."
fi

if [[ $PUBLIC_IP == '' ]]
then
    PUBLIC_IP=$(fetch http://169.254.169.254/latest/meta-data/public-ipv4 || true)
    if [[ $PUBLIC_IP == '' ]]
    then
        echo "[PROXYHOST] Failed to retrieve public ip address from AWS URI within 2s"
    fi
fi

if [[ $PUBLIC_IP == '' ]]
then
    urls=(
        'https://icanhazip.com/'
        'https://ipinfo.io/ip'
        'https://domains.google.com/checkip'
    )
    for url in "${urls[@]}"; do
        PUBLIC_IP="$(fetch "${url}")" && break
    done
    if [[ $PUBLIC_IP == '' ]]
    then
        echo "[PROXYHOST] Failed to retrieve public ip address from third-party sources within 2s"
    fi
fi

PUBLIC_IP="$(echo -n "$PUBLIC_IP" | tr -d '\r\n' | xargs)"

if [[ -n "$PUBLIC_IP" ]]
then
    if [[ "$PUBLIC_IP" == *:* ]]
    then
        DST_LINE="tcp-request connection set-dst ipv6($PUBLIC_IP)"
    else
        DST_LINE="tcp-request connection set-dst ipv4($PUBLIC_IP)"
    fi
    echo "[PROXYHOST] Public IP address ($PUBLIC_IP) in-place replacement occurring on $CONFIG_FILE"
    sed -i "s/#PUBLIC\_IP/${DST_LINE}/g" "$CONFIG_FILE"
fi

pushd /root/certs
/usr/local/bin/generate-certs.sh
mv proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem
popd

haproxy -f "$CONFIG_FILE"
EOF

RUN chmod +x /usr/local/bin/set_public_ip_and_start.sh

HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/start_with_cfg_reset.sh"]
