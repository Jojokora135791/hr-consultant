---
name: deploy-prod-netherlands
description: "Прод HR-консультанта — Docker (n8n+Postgres+Caddy) на Timeweb VPS в Нидерландах, домен hr-kontur.ru; Anthropic блочит РФ-IP, поэтому НЕ в РФ"
metadata:
  type: project
---

HR-консультант **развёрнут в проде** (пилот на условных данных, не реальные ПД).

## Где
- **Timeweb VPS, Нидерланды** (хост `hr-consultant-kontur-26-ned`, IP `64.188.58.229`).
- Домен **hr-kontur.ru** (A-запись → IP сервера), авто-HTTPS через Caddy/Let's Encrypt.
- Стек: Docker Compose в `/opt/hr-consultant/deploy/` — n8n + Postgres + Caddy.
- Доступ: SSH root (пароль у Олега, в git/memory НЕ хранится). n8n SQLite, Postgres — бизнес-БД.

## 🔴 Главный урок: Anthropic геоблокирует РФ
`api.anthropic.com` с **РФ-IP → HTTP 403** (моментальный отказ, геоблок). Первый сервер был в РФ
(Timeweb СПб) → Claude не работал. Пересоздали в **Нидерландах** → Anthropic отвечает (405 на пустой
GET = эндпоинт жив), Telegram (302) и Google Drive доступны. **Прод-сервер для этого проекта —
только не-РФ локация** (ЕС надёжнее; Казахстан не проверен — может тоже блочиться).

## Уроки деплоя
- **SSH через VPN виснет** на «banner exchange timed out» — MTU black hole (utun7, крупные key-exchange
  пакеты дропаются; `ping -s 1400` = 100% loss). Лечение: деплой через **веб-консоль Timeweb** (минует
  SSH) или снизить MTU клиента (`sudo ifconfig <iface> mtu 1300`). Без VPN SSH работает.
- **Docker Hub rate-limit** на анонимные pull (shared IP Timeweb) → зеркало `mirror.gcr.io` в
  `/etc/docker/daemon.json` + `systemctl restart docker`.
- **1 ГБ RAM мало** для `docker compose build` (n8n+petrovich) → добавить swap 2 ГБ.
- **petrovich в Docker** — ставится в образ (`Dockerfile: npm i -g petrovich`), без плясок с
  task-runner как на локали.
- DNS-резолвер Олега не видит `*.trycloudflare.com` (NXDOMAIN) — ещё одна причина уйти от
  quick-туннелей к постоянному домену.

## Деплой / обновление
One-shot (на сервере): `deploy/bootstrap.sh` — `DOMAIN=hr-kontur.ru POSTGRES_PASSWORD=… bash <(curl …)`.
Обновление: `cd /opt/hr-consultant && git pull && cd deploy && docker compose up -d --build`.
Credentials (Anthropic/Telegram/Postgres/Drive) — руками в n8n UI, не в файлах.

Связано: [[project-architecture]], [[n8n-first-vs-item-far-refs]].
