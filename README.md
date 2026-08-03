[English](/README.md) | [Russian](/README_RU.md) | [Telegram](https://t.me/+96HVPF3Ww6o3YTNi)

# wa-proxy-ros

Multi-architecture Docker image for MikroTik RouterOS, built from the official [WhatsApp Proxy](https://github.com/WhatsApp/proxy) source.

The image tracks the upstream release named in `VERSIONS`. It retains the current upstream HAProxy configuration and startup script, but runs the container and HAProxy as `root` for RouterOS deployments.

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/wa-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/wa-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/wa-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7-blue)

## Features

- Multi-architecture images: `amd64`, `arm64`, and `arm/v7`.
- Uses the current upstream WhatsApp Proxy configuration, certificate generator, startup script, and health check.
- Runs as `root`, including the HAProxy process.
- Generates a self-signed certificate at container startup.
- No custom public-IP detection, `PUBLIC_IP`, or HAProxy `set-dst` rewriting.

## Image tags

Images are published to `ghcr.io/medium1992/wa-proxy-ros` and `medium1992/wa-proxy-ros`.

| Tag | Purpose |
|---|---|
| `latest` | Latest image built for this project. |
| `whatsapp-proxy-chart-X.Y.Z` | Image built from the matching upstream release tag. |

The workflow checks for a new upstream release on its schedule. Run it manually when you want to force a rebuild or publication.

## Ports

| Port | Purpose |
|---|---|
| `443/tcp` | Main WhatsApp Proxy port for chats. |
| `587/tcp` | WhatsApp Proxy port for media. |
| `80/tcp`, `5222/tcp`, `7777/tcp` | Additional upstream listeners. |
| `8080/tcp`, `8443/tcp`, `8222/tcp` | Listeners that expect the PROXY protocol. |
| `8199/tcp` | HAProxy stats and health check endpoint; do not expose it to the Internet. |

For most installations, publish only `443/tcp` and `587/tcp`. Keep `8199/tcp` reachable only from a trusted local network.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SSL_DNS` | empty | Comma-separated DNS SAN entries for the generated certificate. |
| `SSL_IP` | empty | Comma-separated IP SAN entries for the generated certificate. |
| `DEBUG` | `1` | Enables certificate-generator output. Set it to an empty value to suppress the certificate dump. |

`PUBLIC_IP`, `PUBLIC_IP_MODE`, `IP_CHECK_INTERVAL`, and `IP_CHANGE_STABLE_SECONDS` are not used by this image.

## RouterOS installation

Enable container support:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

Confirm the change by power-cycling the device or using its physical confirmation button.

Example configuration:

```routeros
/interface/veth/add name=WaProxyRoS address=192.168.255.22/30 gateway=192.168.255.21
/ip/address/add address=192.168.255.21/30 interface=WaProxyRoS

/container/add remote-image=ghcr.io/medium1992/wa-proxy-ros:latest interface=WaProxyRoS root-dir=/Containers/WaProxyRoS start-on-boot=yes comment="WaProxyRoS"
```

Point WhatsApp to the container address, or forward only the required ports to it with your regular RouterOS firewall and NAT rules.

## Notes

- The image is designed for WhatsApp chats and media; it does not claim support for WhatsApp calls.
- The runtime process is intentionally root for RouterOS compatibility.
- Upstream may change listener behavior and ports between releases; review the official project release notes before updating a production deployment.

## Support

- **USDT (TRC20):** `TWDDYD1nk5JnG6FxvEu2fyFqMCY9PcdEsJ`
- [boosty.to/petersolomon/donate](https://boosty.to/petersolomon/donate)

<img width="150" height="150" alt="petersolomon-donate" src="https://github.com/user-attachments/assets/fcf40baa-a09e-4188-a036-7ad3a77f06ea" />
