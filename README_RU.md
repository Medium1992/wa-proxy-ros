[English](/README.md) | [Русский](/README_RU.md) | [Telegram](https://t.me/+96HVPF3Ww6o3YTNi)

# wa-proxy-ros

Multi-arch Docker-контейнер для **MikroTik RouterOS** на базе официального проекта [WhatsApp Proxy](https://github.com/WhatsApp/proxy).

Образ адаптирован под RouterOS: HAProxy стартует от root, сертификаты генерируются в `/root/certs`, а upstream-скрипты изменены так, чтобы RouterOS мог пробрасывать привилегированные порты вроде `80`, `443` и `587`.

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/wa-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/wa-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/wa-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7-blue)
[![Telegram](https://img.shields.io/badge/Telegram-group-blue?logo=telegram)](https://t.me/+96HVPF3Ww6o3YTNi)

## Возможности

- Multi-arch образ: `amd64`, `arm64`, `arm/v7`.
- Сборка из актуального релиза WhatsApp Proxy, который записан в `VERSIONS`.
- HAProxy запускается от root, чтобы RouterOS корректно работал с портами ниже `1024`.
- Поддерживается IPv4 и IPv6 для HAProxy `set-dst`.
- В `auto` режиме образ отслеживает смену public IP и мягко перезагружает HAProxy после стабилизации нового адреса.
- При каждом старте `haproxy.cfg` восстанавливается из шаблона.
- Образы публикуются в GHCR и Docker Hub.
- GitHub Actions собирает образ только при новой upstream-версии или ручном запуске workflow.

## Теги Образов

Образы публикуются в:

- `ghcr.io/medium1992/wa-proxy-ros`
- `medium1992/wa-proxy-ros`

Доступные теги:

| Тег | Назначение |
|---|---|
| `latest` | Последний собранный релиз WhatsApp Proxy для RouterOS. |
| `whatsapp-proxy-chart-X.Y.Z` | Образ, собранный из конкретного upstream-тега WhatsApp Proxy. |

## Порты

HAProxy слушает:

| Порт | Назначение |
|---|---|
| `80/tcp` | HTTP frontend. |
| `8080/tcp` | HTTP frontend с PROXY protocol. |
| `443/tcp` | HTTPS frontend. |
| `8443/tcp` | HTTPS frontend с PROXY protocol. |
| `5222/tcp` | XMPP frontend. |
| `8222/tcp` | XMPP frontend с PROXY protocol. |
| `587/tcp` | WhatsApp.net frontend. |
| `7777/tcp` | Альтернативный WhatsApp.net frontend. |
| `8199/tcp` | HAProxy stats и healthcheck. |

Снаружи открывайте только нужные порты. `8199` лучше оставлять доступным только из локальной сети.

## Переменные Окружения

| ENV | По умолчанию | Описание |
|---|---|---|
| `PUBLIC_IP_MODE` | `auto` | `auto` определяет текущий public IP и делает reload HAProxy при смене. `fixed` всегда использует `PUBLIC_IP`. |
| `PUBLIC_IP` | пусто | Фиксированный public IP или fallback, если автоопределение не сработало. Поддерживаются IPv4 и IPv6. |
| `IP_CHECK_INTERVAL` | `15` | Интервал проверки public IP в секундах. |
| `IP_CHANGE_STABLE_SECONDS` | `45` | Сколько секунд новый IP должен быть стабильным перед reload HAProxy. |
| `SSL_DNS` | пусто | Дополнительные DNS SAN для upstream-скрипта генерации сертификата. |
| `SSL_IP` | пусто | Дополнительные IP SAN для upstream-скрипта генерации сертификата. |
| `DEBUG` | `1` | Debug-режим upstream-скрипта генерации сертификата. |

Если public IP не удалось определить и `PUBLIC_IP` не задан, контейнер запускает HAProxy без правила `set-dst`, а не падает.

## Установка В RouterOS

Сначала включите поддержку контейнеров:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

После команды подтвердите изменение перезагрузкой питания или физической кнопкой на устройстве.

Пример интерфейса контейнера и переменных:

```routeros
/interface/veth/add name=WaProxyRoS address=192.168.255.22/30 gateway=192.168.255.21
/ip/address/add address=192.168.255.21/30 interface=WaProxyRoS

/container/envs/add list=WaProxyRoS key=PUBLIC_IP_MODE value=auto
/container/envs/add list=WaProxyRoS key=IP_CHECK_INTERVAL value=15
/container/envs/add list=WaProxyRoS key=IP_CHANGE_STABLE_SECONDS value=45

/container/add remote-image=ghcr.io/medium1992/wa-proxy-ros:latest interface=WaProxyRoS envlists=WaProxyRoS root-dir=/Containers/WaProxyRoS start-on-boot=yes comment="WaProxyRoS"
```

После этого пробросьте нужные WAN-порты на IP контейнера обычными правилами firewall/NAT в RouterOS.

Для фиксированного public IP:

```routeros
/container/envs/set [find list=WaProxyRoS key=PUBLIC_IP_MODE] value=fixed
/container/envs/add list=WaProxyRoS key=PUBLIC_IP value=203.0.113.10
```

## Заметки

- `PUBLIC_IP` не заставляет HAProxy слушать на этом адресе. Он управляет правилом HAProxy `tcp-request connection set-dst ...`, которое полезно при NAT, load balancer или другом внешнем входе.
- В `auto` режиме public IP определяется через IPv4 check-IP сервисы. Если среда IPv6-only, лучше задать `PUBLIC_IP_MODE=fixed` и указать `PUBLIC_IP`.
- Reload HAProxy мягкий: новые подключения идут в новый процесс, существующие соединения доживают в старом.
- Образ сохраняет upstream-конфиг WhatsApp Proxy, но меняет права/пути/старт процессов под RouterOS.

## Поддержка Проекта

Если проект сэкономил время на настройке MikroTik:

- **USDT (TRC20):** `TWDDYD1nk5JnG6FxvEu2fyFqMCY9PcdEsJ`
- [boosty.to/petersolomon/donate](https://boosty.to/petersolomon/donate)

<img width="150" height="150" alt="petersolomon-donate" src="https://github.com/user-attachments/assets/fcf40baa-a09e-4188-a036-7ad3a77f06ea" />
