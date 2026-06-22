# Деплой HR-консультанта на VPS (Docker)

Стек: **n8n** (свои данные в SQLite) + **Postgres 16** (бизнес-БД `hr_assistant`) + **Caddy** (авто-HTTPS).
Ollama и GPU не нужны: диалог — Claude (облако), генерация — детерминированная (petrovich/fallback).

## 0. Предусловия
- VPS (Ubuntu 22/24), 2 vCPU / 2–4 ГБ. Без GPU.
- Домен/поддомен с **A-записью на IP VPS** (напр. `hr-kontur.xyz` или бесплатный `*.duckdns.org`).
- Открыты порты **80** и **443**.

## 1. Установить Docker
```bash
curl -fsSL https://get.docker.com | sh
```

## 2. Получить код
```bash
git clone https://github.com/Jojokora135791/hr-consultant.git
cd hr-consultant/deploy
```

## 3. Настроить .env
```bash
cp .env.example .env
nano .env   # DOMAIN=твой-домен, POSTGRES_PASSWORD=длинный-пароль
```
Секреты Anthropic / Telegram / Google вводятся позже в n8n UI — в `.env` их НЕТ.

## 4. Поднять стек
```bash
docker compose up -d --build
```
- Postgres при первом старте применит `db/schema.sql` (таблицы `hr_cases`, `hr_evidence`).
- Caddy выпустит TLS-сертификат для `DOMAIN` (нужны рабочие 80/443 и A-запись).

Проверка:
```bash
docker compose ps          # все healthy
docker compose logs -f caddy   # сертификат выпущен
```

## 5. Настроить n8n (в браузере)
Открой `https://<DOMAIN>`:
1. Создай owner-аккаунт n8n.
2. **Credentials** (Settings → Credentials):
   - **Anthropic** — API-ключ (Base URL `https://api.anthropic.com`).
   - **Telegram** — токен бота от @BotFather.
   - **Postgres** — host `postgres`, port `5432`, db `hr_assistant`, user/пароль из `.env`.
   - **Google Drive (Service Account)** `N8N-kontur` — JSON ключ. Шаблоны акта/СЗ и чеклист
     должны быть **расшарены** на e-mail Service Account.
3. Импортируй оба workflow (`HR-агент`, `Генерация документов`) из `n8n/workflows/`.
4. В ноде `Генерация документов` (tool в HR-агенте) проверь, что `workflowId` указывает
   на импортированную «Генерацию документов».
5. Активируй оба workflow → Telegram webhook зарегистрируется на `https://<DOMAIN>`.

## 6. Проверка
- Бот в Telegram отвечает.
- Сценарий прогула: диалог → сроки → подтверждение → акт + СЗ файлами.
- Фото → в СЗ вставлен «Скриншот N».
- `docker compose restart` / ребут VPS → всё поднимается само, webhook не слетает (домен постоянный).

## Обновление
```bash
cd hr-consultant && git pull && cd deploy
docker compose up -d --build
```
Workflow обновляются через повторный импорт в UI (или n8n CLI).

## Бэкапы
- Postgres: `docker compose exec postgres pg_dump -U $POSTGRES_USER hr_assistant > backup.sql`
- n8n (workflow+credentials): том `n8n_data` (`/home/node/.n8n`).
