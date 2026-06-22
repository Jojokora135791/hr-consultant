#!/usr/bin/env bash
# One-shot деплой HR-консультанта. Запускать НА СЕРВЕРE (SSH или веб-консоль Timeweb).
# Секреты передаются через переменные окружения — в git их нет.
#
# Пример запуска:
#   DOMAIN=hr-kontur.ru POSTGRES_PASSWORD=ПАРОЛЬ \
#     bash <(curl -fsSL https://raw.githubusercontent.com/Jojokora135791/hr-consultant/main/deploy/bootstrap.sh)
set -euo pipefail

DOMAIN="${DOMAIN:?Укажи DOMAIN, напр. DOMAIN=hr-kontur.ru}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?Укажи POSTGRES_PASSWORD}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
TZ_VAL="${TZ:-Asia/Yerevan}"
REPO="https://github.com/Jojokora135791/hr-consultant.git"

echo "==> [1/4] Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version

echo "==> [2/4] Код проекта"
mkdir -p /opt && cd /opt
if [ -d hr-consultant/.git ]; then
  cd hr-consultant && git pull --ff-only
else
  git clone "$REPO" && cd hr-consultant
fi
cd deploy

echo "==> [3/4] .env"
cat > .env <<EOF
DOMAIN=$DOMAIN
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
TZ=$TZ_VAL
EOF
chmod 600 .env

echo "==> [4/4] Сборка и запуск стека"
docker compose up -d --build
sleep 5
docker compose ps

cat <<NOTE

==================================================================
Стек поднят. Дальше — вручную в браузере:
  1. Проверь A-запись: $DOMAIN  →  IP этого сервера.
  2. Открой https://$DOMAIN  (Caddy выпустит TLS автоматически).
  3. Создай owner-аккаунт n8n.
  4. Заведи credentials: Anthropic, Telegram, Postgres (host=postgres,
     db=hr_assistant, user=$POSTGRES_USER), Google Drive (N8N-kontur).
  5. Импортируй workflow из /opt/hr-consultant/n8n/workflows/.
  6. Активируй workflow → Telegram webhook на https://$DOMAIN.
Подробно: /opt/hr-consultant/deploy/README.md
==================================================================
NOTE
