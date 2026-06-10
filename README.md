[English](/README.md) | [Russian](/README_RU.md) | [Telegram](https://t.me/+96HVPF3Ww6o3YTNi)

# wa-proxy-ros

Multi-arch Docker container for **MikroTik RouterOS** based on the official [WhatsApp Proxy](https://github.com/WhatsApp/proxy) project.

This image keeps the container RouterOS-friendly: HAProxy starts as root, certificates are generated under `/root/certs`, and the original upstream scripts are adapted so RouterOS can expose privileged ports such as `80`, `443` and `587`.

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/wa-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/wa-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/wa-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7-blue)
[![Telegram](https://img.shields.io/badge/Telegram-group-blue?logo=telegram)](https://t.me/+96HVPF3Ww6o3YTNi)

## ✨ Features

- Multi-arch image: `amd64`, `arm64`, `arm/v7`.
- Based on the latest WhatsApp Proxy release tracked in `VERSIONS`.
- Runs HAProxy as root for RouterOS privileged-port publishing.
- Supports IPv4 and IPv6 public IP detection for HAProxy `set-dst`.
- Can monitor public IP changes and softly reload HAProxy after the new IP is stable.
- Resets `haproxy.cfg` from the template on every container start.

## 🐳 Image Tags

Images are published to:

- `ghcr.io/medium1992/wa-proxy-ros`
- `medium1992/wa-proxy-ros`

Available tags:

| Tag | Purpose |
|---|---|
| `latest` | Latest built WhatsApp Proxy release for RouterOS. |
| `whatsapp-proxy-chart-X.Y.Z` | Image built from a specific upstream WhatsApp Proxy release tag. |

The GitHub Actions workflow publishes images to GHCR and Docker Hub only when a new upstream version appears or when the workflow is started manually.

## 🔌 Ports

HAProxy listens on:

| Port | Purpose |
|---|---|
| `80/tcp` | HTTP proxy frontend. |
| `8080/tcp` | HTTP frontend with PROXY protocol. |
| `443/tcp` | HTTPS proxy frontend. |
| `8443/tcp` | HTTPS frontend with PROXY protocol. |
| `5222/tcp` | XMPP frontend. |
| `8222/tcp` | XMPP frontend with PROXY protocol. |
| `587/tcp` | WhatsApp.net frontend. |
| `7777/tcp` | WhatsApp.net alternative frontend. |
| `8199/tcp` | HAProxy stats and healthcheck endpoint. |

Expose only the ports you need from the WAN side. Keep `8199` private unless you intentionally need stats access.

## ⚙️ Environment Variables

| ENV | Default | Description |
|---|---|---|
| `PUBLIC_IP_MODE` | `auto` | `auto` detects the current public IP and reloads HAProxy when it changes. `fixed` always uses `PUBLIC_IP`. |
| `PUBLIC_IP` | empty | Fixed public IP or fallback value when automatic detection fails. IPv4 are supported. |
| `IP_CHECK_INTERVAL` | `15` | Seconds between public IP checks in `auto` mode. |
| `IP_CHANGE_STABLE_SECONDS` | `45` | New IP must stay unchanged for this many seconds before HAProxy reload. |
| `SSL_DNS` | empty | Optional DNS SAN values passed to upstream certificate generation. |
| `SSL_IP` | empty | Optional IP SAN values passed to upstream certificate generation. |
| `DEBUG` | `1` | Upstream certificate script debug mode. |

If no public IP can be detected and `PUBLIC_IP` is empty, the container starts HAProxy without the `set-dst` rule instead of failing.

## 🛠 RouterOS Install

Enable container support first:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

Confirm the change by power-cycling the device or pressing the physical confirmation button.

Example container interface and environment:

```routeros
/interface/veth/add name=WaProxyRoS address=192.168.255.22/30 gateway=192.168.255.21
/ip/address/add address=192.168.255.21/30 interface=WaProxyRoS

/container/envs/add list=WaProxyRoS key=PUBLIC_IP_MODE value=auto
/container/envs/add list=WaProxyRoS key=IP_CHECK_INTERVAL value=15
/container/envs/add list=WaProxyRoS key=IP_CHANGE_STABLE_SECONDS value=45

/container/add remote-image=ghcr.io/medium1992/wa-proxy-ros:latest interface=WaProxyRoS envlists=WaProxyRoS root-dir=/Containers/WaProxyRoS start-on-boot=yes comment="WaProxyRoS"
```

The main intended scenario is local network use: clients inside your LAN connect to the container through the RouterOS veth address or through local RouterOS forwarding rules.

If you need access to this proxy from outside your local network, publish only the required WAN ports to the container IP with your normal RouterOS firewall/NAT rules.

For a static public IP, use:

```routeros
/container/envs/set [find list=WaProxyRoS key=PUBLIC_IP_MODE] value=fixed
/container/envs/add list=WaProxyRoS key=PUBLIC_IP value=203.0.113.10
```

## 📝 Notes

- `PUBLIC_IP` does not make HAProxy listen on that address. It controls HAProxy `tcp-request connection set-dst ...`, which helps when traffic is forwarded through NAT, a load balancer, or another edge path.
- In `auto` mode the image detects public IPv4 through common check-IP services. If your environment is IPv6-only, set `PUBLIC_IP_MODE=fixed` and provide `PUBLIC_IP`.
- HAProxy reload is soft: new connections move to the new process, while existing sessions are allowed to drain.
- The image follows upstream WhatsApp Proxy config, but keeps process ownership and paths suitable for RouterOS containers.

## 💖 Support

If this project saved you time configuring MikroTik:

- **USDT (TRC20):** `TWDDYD1nk5JnG6FxvEu2fyFqMCY9PcdEsJ`
- [boosty.to/petersolomon/donate](https://boosty.to/petersolomon/donate)

<img width="150" height="150" alt="petersolomon-donate" src="https://github.com/user-attachments/assets/fcf40baa-a09e-4188-a036-7ad3a77f06ea" />
