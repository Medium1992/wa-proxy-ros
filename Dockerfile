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
CONFIG_TEMPLATE="/usr/local/etc/haproxy/haproxy.cfg.template"
PID_FILE="/run/haproxy.pid"
IP_CHECK_INTERVAL="${IP_CHECK_INTERVAL:-15}"
IP_CHANGE_STABLE_SECONDS="${IP_CHANGE_STABLE_SECONDS:-45}"
PUBLIC_IP_MODE="${PUBLIC_IP_MODE:-auto}"

function fetch() {
  curl --silent --show-error --fail --ipv4 --max-time 2 "$@"
}

function log() {
  echo "$@" >&2
}

function detect_public_ip() {
  local detected_ip=""
  if [[ "${PUBLIC_IP_MODE}" == "fixed" && -n "${PUBLIC_IP}" ]]; then
      detected_ip="${PUBLIC_IP}"
      detected_ip="$(echo -n "${detected_ip}" | tr -d '\r\n' | xargs)"
      echo "${detected_ip}"
      return 0
  fi

  if [[ -z "${detected_ip}" ]]; then
      detected_ip="$(fetch http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
      if [[ -z "${detected_ip}" ]]; then
          log "[PROXYHOST] Failed to retrieve public ip address from AWS URI within 2s"
      fi
  fi

  if [[ -z "${detected_ip}" ]]; then
      local urls=(
          'https://icanhazip.com/'
          'https://ipinfo.io/ip'
          'https://domains.google.com/checkip'
      )
      local url
      for url in "${urls[@]}"; do
          detected_ip="$(fetch "${url}" || true)"
          if [[ -n "${detected_ip}" ]]; then
              break
          fi
      done
      if [[ -z "${detected_ip}" ]]; then
          log "[PROXYHOST] Failed to retrieve public ip address from third-party sources within 2s"
      fi
  fi

  if [[ -z "${detected_ip}" && -n "${PUBLIC_IP}" ]]; then
      detected_ip="${PUBLIC_IP}"
      log "[PROXYHOST] Falling back to PUBLIC_IP from environment"
  fi

  detected_ip="$(echo -n "${detected_ip}" | tr -d '\r\n' | xargs)"
  echo "${detected_ip}"
}

function render_haproxy_config() {
  local ip="$1"
  cp "${CONFIG_TEMPLATE}" "${CONFIG_FILE}"
  if [[ -n "${ip}" ]]; then
      local dst_line=""
      local escaped_dst_line=""
      if [[ "${ip}" == *:* ]]; then
          dst_line="tcp-request connection set-dst ipv6(${ip})"
      else
          dst_line="tcp-request connection set-dst ipv4(${ip})"
      fi
      escaped_dst_line="$(printf '%s' "${dst_line}" | sed 's/[&|]/\\&/g')"
      sed -i "s|#PUBLIC\_IP|${escaped_dst_line}|g" "${CONFIG_FILE}"
  else
      sed -i "s|#PUBLIC\_IP||g" "${CONFIG_FILE}"
  fi
}

function start_haproxy() {
  echo "[PROXYHOST] Starting HAProxy"
  haproxy -D -f "${CONFIG_FILE}" -p "${PID_FILE}"
}

function reload_haproxy() {
  local old_pid
  old_pid="$(cat "${PID_FILE}")"
  echo "[PROXYHOST] Reloading HAProxy (old pid ${old_pid})"
  haproxy -D -f "${CONFIG_FILE}" -p "${PID_FILE}" -sf "${old_pid}"
}

pushd /root/certs
/usr/local/bin/generate-certs.sh
mv proxy.whatsapp.net.pem /etc/haproxy/ssl/proxy.whatsapp.net.pem
popd

current_ip="$(detect_public_ip)"
log "[PROXYHOST] Initial detected public IP: ${current_ip:-<empty>}"
render_haproxy_config "${current_ip}"
start_haproxy

candidate_ip=""
candidate_since=0

while true; do
  sleep "${IP_CHECK_INTERVAL}"

  if [[ ! -s "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
      echo "[PROXYHOST] HAProxy process not found, starting again"
      render_haproxy_config "${current_ip}"
      start_haproxy
  fi

  latest_ip="$(detect_public_ip)"

  if [[ "${latest_ip}" == "${current_ip}" ]]; then
      candidate_ip=""
      candidate_since=0
      continue
  fi

  now="$(date +%s)"
  if [[ "${latest_ip}" != "${candidate_ip}" ]]; then
      candidate_ip="${latest_ip}"
      candidate_since="${now}"
      log "[PROXYHOST] IP change candidate detected: ${current_ip:-<empty>} -> ${candidate_ip:-<empty>}"
      continue
  fi

  elapsed=$((now - candidate_since))
  if (( elapsed < IP_CHANGE_STABLE_SECONDS )); then
      continue
  fi

  log "[PROXYHOST] IP change confirmed after ${elapsed}s: ${current_ip:-<empty>} -> ${latest_ip:-<empty>}"
  render_haproxy_config "${latest_ip}"
  if [[ -s "${PID_FILE}" ]]; then
      reload_haproxy
  else
      start_haproxy
  fi
  current_ip="${latest_ip}"
  candidate_ip=""
  candidate_since=0
done
EOF

RUN chmod +x /usr/local/bin/set_public_ip_and_start.sh

HEALTHCHECK --interval=10s --start-period=5s CMD bash /usr/local/bin/healthcheck.sh
CMD ["/usr/local/bin/start_with_cfg_reset.sh"]
