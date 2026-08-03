[English](/README.md) | [Русский](/README_RU.md) | [Telegram](https://t.me/+96HVPF3Ww6o3YTNi)

# wa-proxy-ros

Мультиархитектурный Docker-образ для MikroTik RouterOS, собираемый из официального исходного кода [WhatsApp Proxy](https://github.com/WhatsApp/proxy).

Образ отслеживает upstream-релиз, указанный в `VERSIONS`. В нём сохранены актуальные конфиг HAProxy, скрипт запуска, генератор сертификата и healthcheck из upstream, но сам контейнер и HAProxy запускаются от `root` для совместимости с RouterOS.

[![Docker Pulls](https://img.shields.io/docker/pulls/medium1992/wa-proxy-ros?logo=docker&label=docker%20pulls)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/medium1992/wa-proxy-ros/latest?logo=docker&label=image%20size)](https://hub.docker.com/r/medium1992/wa-proxy-ros)
[![License](https://img.shields.io/github/license/Medium1992/wa-proxy-ros)](./LICENSE)
![Platforms](https://img.shields.io/badge/arch-amd64%20%7C%20arm64%20%7C%20armv7-blue)

## Возможности

- Образы для `amd64`, `arm64` и `arm/v7`.
- Используются актуальные upstream-конфиг WhatsApp Proxy, скрипт запуска, генератор сертификата и healthcheck.
- Контейнер и процесс HAProxy работают от `root`.
- Самоподписанный сертификат генерируется при старте контейнера.
- Нет кастомного определения public IP, переменных `PUBLIC_IP` и подстановки HAProxy `set-dst`.

## Теги образов

Образы публикуются в `ghcr.io/medium1992/wa-proxy-ros` и `medium1992/wa-proxy-ros`.

| Тег | Назначение |
|---|---|
| `latest` | Последний образ, собранный для этого проекта. |
| `whatsapp-proxy-chart-X.Y.Z` | Образ из соответствующего upstream-релиза. |

Workflow по расписанию проверяет новый upstream-релиз. Для принудительной пересборки или публикации запускайте workflow вручную.

## Порты

| Порт | Назначение |
|---|---|
| `443/tcp` | Основной порт WhatsApp Proxy для чатов. |
| `587/tcp` | Порт WhatsApp Proxy для медиа. |
| `80/tcp`, `5222/tcp`, `7777/tcp` | Дополнительные upstream-слушатели. |
| `8080/tcp`, `8443/tcp`, `8222/tcp` | Слушатели, ожидающие PROXY protocol. |
| `8199/tcp` | Статистика и healthcheck HAProxy; не публикуйте его в Интернет. |

Обычно достаточно открыть только `443/tcp` и `587/tcp`. Порт `8199/tcp` оставляйте доступным лишь в доверенной локальной сети.

## Переменные окружения

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `SSL_DNS` | пусто | DNS SAN для генерируемого сертификата, через запятую. |
| `SSL_IP` | пусто | IP SAN для генерируемого сертификата, через запятую. |
| `DEBUG` | `1` | Вывод генератора сертификата. Пустое значение отключает дамп сертификата. |

`PUBLIC_IP`, `PUBLIC_IP_MODE`, `IP_CHECK_INTERVAL` и `IP_CHANGE_STABLE_SECONDS` больше не используются.

## Установка в RouterOS

Включите поддержку контейнеров:

```routeros
/system/device-mode/print
/system/device-mode/update mode=advanced container=yes
```

Подтвердите изменение перезапуском питания устройства или его физической кнопкой подтверждения.

Пример настройки:

```routeros
/interface/veth/add name=WaProxyRoS address=192.168.255.22/30 gateway=192.168.255.21
/ip/address/add address=192.168.255.21/30 interface=WaProxyRoS

/container/add remote-image=ghcr.io/medium1992/wa-proxy-ros:latest interface=WaProxyRoS root-dir=/Containers/WaProxyRoS start-on-boot=yes comment="WaProxyRoS"
```

Укажите в WhatsApp адрес контейнера либо пробросьте к нему только нужные порты обычными правилами RouterOS firewall/NAT.

## Примечания

- Образ предназначен для чатов и медиа WhatsApp; поддержка звонков не заявляется.
- Процесс намеренно работает от root ради совместимости с RouterOS.
- Upstream может менять поведение слушателей и порты между релизами; перед обновлением production-инсталляции проверяйте заметки к релизу официального проекта.

## Поддержка проекта

- **USDT (TRC20):** `TWDDYD1nk5JnG6FxvEu2fyFqMCY9PcdEsJ`
- [boosty.to/petersolomon/donate](https://boosty.to/petersolomon/donate)

<img width="150" height="150" alt="petersolomon-donate" src="https://github.com/user-attachments/assets/fcf40baa-a09e-4188-a036-7ad3a77f06ea" />
