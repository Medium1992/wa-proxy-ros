[English](/README.md) | [Русский](/README_RU.md) | [Telegram](https://t.me/+96HVPF3Ww6o3YTNi)

# wa-proxy-ros

Multi-arch Docker-контейнер для **MikroTik RouterOS** на базе официального проекта [WhatsApp Proxy](https://github.com/WhatsApp/proxy).

Образ адаптирован под RouterOS: HAProxy стартует от root, сертификаты генерируются в `/root/certs`, а upstream-скрипты изменены так, чтобы RouterOS мог пробрасывать привилегированные порты вроде `80`, `443` и `587`.

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/wa-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/wa-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/wa-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7-blue)
[![Telegram](https://img.shields.io/badge/Telegram-group-blue?logo=telegram)](https://t.me/+96HVPF3Ww6o3YTNi)

## ✨ Возможности

- Multi-arch образ: `amd64`, `arm64`, `arm/v7`.
- Сборка из актуального релиза WhatsApp Proxy, который записан в `VERSIONS`.
- HAProxy запускается от root, чтобы RouterOS корректно работал с портами ниже `1024`.
- Поддерживается IPv4 и IPv6 для HAProxy `set-dst`.
- В `auto` режиме образ отслеживает смену public IP и мягко перезагружает HAProxy после стабилизации нового адреса.
- При каждом старте `haproxy.cfg` восстанавливается из шаблона.

## 🐳 Теги Образов

Образы публикуются в:

- `ghcr.io/medium1992/wa-proxy-ros`
- `medium1992/wa-proxy-ros`

Доступные теги:

| Тег | Назначение |
|---|---|
| `latest` | Последний собранный релиз WhatsApp Proxy для RouterOS. |
| `whatsapp-proxy-chart-X.Y.Z` | Образ, собранный из конкретного upstream-тега WhatsApp Proxy. |

GitHub Actions публикует образы в GHCR и Docker Hub только при появлении новой upstream-версии или при ручном запуске workflow.

## 🔌 Порты

Для обычного подключения клиента WhatsApp к прокси обычно достаточно указывать IP контейнера в настройках WhatsApp. Открывать все порты наружу не требуется.

| Порт | Для чего используется |
|---|---|
| `443/tcp` | Основной порт WhatsApp Proxy для чатов. |
| `587/tcp` | Порт WhatsApp Proxy для медиа. |
| `80/tcp` | Дополнительный HTTP-вход, оставлен для совместимости с upstream-конфигом. |
| `5222/tcp` | Дополнительный XMPP-вход, оставлен для совместимости с upstream-конфигом. |
| `7777/tcp` | Альтернативный вход для `whatsapp.net`, оставлен upstream-проектом. |
| `8080/tcp`, `8443/tcp`, `8222/tcp` | Варианты входов с PROXY protocol. Обычным клиентам WhatsApp они не нужны. |
| `8199/tcp` | HAProxy stats и healthcheck. Не публикуйте наружу. |

Основной сценарий этого образа - работа внутри локальной сети. Если нужен доступ к прокси извне LAN, пробрасывайте наружу только те порты, которые действительно нужны вашим клиентам, обычно `443/tcp` и `587/tcp`. `8199/tcp` оставляйте доступным только локально.

## ⚙️ Переменные Окружения

| ENV | По умолчанию | Описание |
|---|---|---|
| `PUBLIC_IP_MODE` | `fixed` | `fixed` всегда использует `PUBLIC_IP` и отключает внешние проверки IP. `auto` периодически определяет текущий public IP и делает reload HAProxy, если непустой IP изменился. |
| `PUBLIC_IP` | пусто | Фиксированный public IP или fallback, если автоопределение не сработало. Поддерживаются IPv4 и IPv6. |
| `IP_CHECK_INTERVAL` | `15` | Интервал проверки public IP в секундах. |
| `IP_CHANGE_STABLE_SECONDS` | `45` | Сколько секунд новый IP должен быть стабильным перед reload HAProxy. |
| `SSL_DNS` | пусто | Дополнительные DNS SAN для upstream-скрипта генерации сертификата. |
| `SSL_IP` | пусто | Дополнительные IP SAN для upstream-скрипта генерации сертификата. |
| `DEBUG` | `1` | Debug-режим upstream-скрипта генерации сертификата. |

Если public IP не удалось определить и `PUBLIC_IP` не задан, контейнер запускает HAProxy без правила `set-dst`, а не падает.

Для использования только внутри локальной сети без определения public IP оставьте значение по умолчанию `PUBLIC_IP_MODE=fixed` и не задавайте `PUBLIC_IP`.

## 🛠 Установка В RouterOS

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

/container/envs/add list=WaProxyRoS key=IP_CHECK_INTERVAL value=15
/container/envs/add list=WaProxyRoS key=IP_CHANGE_STABLE_SECONDS value=45

/container/add remote-image=ghcr.io/medium1992/wa-proxy-ros:latest interface=WaProxyRoS envlists=WaProxyRoS root-dir=/Containers/WaProxyRoS start-on-boot=yes comment="WaProxyRoS"
```

Основной сценарий использования контейнера - внутри локальной сети: клиенты LAN подключаются к контейнеру через veth-адрес RouterOS или через локальные правила проброса.

Если нужен доступ к этому прокси-контейнеру извне локальной сети, пробросьте только необходимые WAN-порты на IP контейнера обычными правилами firewall/NAT в RouterOS.

Для фиксированного public IP:

```routeros
/container/envs/set [find list=WaProxyRoS key=PUBLIC_IP_MODE] value=fixed
/container/envs/add list=WaProxyRoS key=PUBLIC_IP value=203.0.113.10
```

Для динамического определения public IP задайте:

```routeros
/container/envs/add list=WaProxyRoS key=PUBLIC_IP_MODE value=auto
```

## 📝 Заметки

- `PUBLIC_IP` не заставляет HAProxy слушать на этом адресе. Он управляет правилом HAProxy `tcp-request connection set-dst ...`, которое полезно при NAT, load balancer или другом внешнем входе.
- В WhatsApp указывайте адрес контейнера или внешний адрес проброса в `Настройки -> Данные и хранилище -> Прокси-сервер`.
- WhatsApp Proxy рассчитан на чаты и медиа; работу звонков этот образ не обещает.
- В `auto` режиме public IP определяется через IPv4 check-IP сервисы каждые `IP_CHECK_INTERVAL` секунд. Если детект вернул пустое значение, текущий конфиг HAProxy остается без изменений.
- Если среда IPv6-only, лучше задать `PUBLIC_IP_MODE=fixed` и указать `PUBLIC_IP`.
- HAProxy намеренно запускается от root для RouterOS и портов ниже `1024`; в конфиге явно указаны `user root` и `chroot /`, чтобы убрать вводящие в заблуждение startup warning.
- Reload HAProxy мягкий: новые подключения идут в новый процесс, существующие соединения доживают в старом.
- Образ сохраняет upstream-конфиг WhatsApp Proxy, но меняет права/пути/старт процессов под RouterOS.

## 💖 Поддержка Проекта

Если проект сэкономил время на настройке MikroTik:

- **USDT (TRC20):** `TWDDYD1nk5JnG6FxvEu2fyFqMCY9PcdEsJ`
- [boosty.to/petersolomon/donate](https://boosty.to/petersolomon/donate)

<img width="150" height="150" alt="petersolomon-donate" src="https://github.com/user-attachments/assets/fcf40baa-a09e-4188-a036-7ad3a77f06ea" />
