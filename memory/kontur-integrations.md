---
name: kontur-integrations
description: "Интеграции с внутренним контуром Контура — Паспорт (OAuth-токен), Mattermost (вход бота), Стафф API. Уроки авторизации и подключения."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1caea679-a39a-4939-a7b3-605653654fa8
---

Вход HR-ассистента переехал с Telegram на **внутренние сервисы Контура** (n8n на `n8n-common.testkontur.ru`,
диалог на KonturGPT). Deploy в Нидерландах ([[deploy-prod-netherlands]]) устарел.

> 🚦 **Статус отладки (02.07.2026):** отлажены вживую **Mattermost** (вход/выход) + **Паспорт** (токен) +
> переезд на KonturGPT. **НЕ протестированы**: идентификация Staff, относительные даты, генерация в MM.
> **Postgres — блокер** (права юзера + pg_hba, см. ниже).

## Контур Паспорт — получение токена (OAuth client_credentials)
- Приложение `SherpaHROrdersAPP` в Паспорте → `ClientId` + `ClientSecret`.
- `POST https://passport.skbkontur.ru/connect/token`, заголовок `Authorization: Basic base64(clientId:clientSecret)`,
  тело `grant_type=client_credentials`, **Content-Type: `application/x-www-form-urlencoded`** (не multipart!).
- В n8n HTTP-нода: Header Auth credential, **Name=`Authorization`, Value=`Basic <base64>`** (Fixed);
  Body Content Type = **Form Urlencoded**.
- Ответ: `access_token` (живёт `expires_in`=36000 сек = 10 ч), `aud` включает `staff.skbkontur.ru/api`.
- ⚠️ Уроки: `invalid_client` = битый/пустой Basic (частое: `__n8n_BLANK_VALUE_` = пустое поле в n8n,
  или base64 из `echo` без `-n`). Диагностика — прямой `curl -u 'id:secret' .../connect/token` (сразу
  видно, креды или n8n виноваты). В экспорте workflow токена НЕТ — только ссылка на credential (id).

## Mattermost — вход бота (свободный текст в ЛС)
- У Mattermost **нет n8n-триггера**; outgoing webhooks не работают в личках. Нужен бот на WebSocket.
- **Свой Node-WS (`ws`) НЕ работает** — рвётся `code 1006` сразу после auth (reverse-proxy Контура не
  держит сырой WebSocket, даже с Authorization-заголовком и SSL off). Вариант отвергнут, папка `connector/` **удалена**.
- **Рабочее решение — `mmpy_bot` (Python)**, как у коллег внутри. Лежит в `bot/` (`bot.py`+`plugin.py`).
  - `@listen_to('.*', direct_only=True)` → POST в n8n Webhook `{channel_id, user_id, sender_name, message, file_ids}`.
  - Ответ бот НЕ постит — постит сам n8n нодой `POST /api/v4/posts` (n8n на `n8n-common.testkontur.ru`
    до локально запущенного бота не достучится, поэтому двусторонняя схема через webhook бота не годится).
  - `SSL_VERIFY=False` (внутренний CA), `BOT_TEAM=Kontur`, порт 443.
  - ⚠️ **Python 3.14**: нужно `asyncio.new_event_loop()`+`set_event_loop()` ДО `bot.run()` — иначе
    `RuntimeError: There is no current event loop` (get_event_loop больше не создаёт loop сам).
- DM-канал через API: `POST /api/v4/channels/direct` тело `[bot_user_id, target_id]` — **первый id должен
  быть владельцем токена** (свой id узнать `GET /api/v4/users/me`), иначе 403.

## Стафф — данные сотрудников
- `GET https://staff.skbkontur.ru/api/users/email/{email}` и `/api/users/{id}`, заголовок `Bearer <access_token>` из Паспорта.
- ⚠️ В Стаффе **НЕТ больничных и командировок** — «чист ли свидетель в этот день» через Стафф не проверить, ручная сверка остаётся.

## Postgres Контура — 🔴 БЛОКЕР (права/сеть)
- Схема **`hr_disciplinary_assistant`** в общей БД `n8n` на `devof-pt-vxsa1.dev.kontur.ru:5432`,
  юзер `hr_disciplinary_assistant_user`. БД называется `n8n` (не ошибка). Схему DBA уже создал.
- ⚠️ **SSL = `disable`**, НЕ require! Сервер не отдаёт TLS: с `require` коннект падает, с `disable` —
  проходит. (`no encryption` в ошибке pg_hba — это описание попытки без шифрования, а НЕ требование его включить.)
- 🔴 **pg_hba: плавающие IP подов n8n.** Каждый execution уходит с другого egress-IP
  (видели 10.216.14.51, 10.218.4.163, 10.220.4.155), часть не в `pg_hba.conf` → коннект через раз.
  Ретраи НЕ помогают (в рамках одного execution IP стабилен). Фикс: DBA whitelist подсетей /16 или стабильный egress.
- 🔴 **Права юзера урезаны:** `CREATE SCHEMA` → `permission denied for database n8n` (схему и не надо —
  DBA создал). `search_path` пустой → нода Postgres Chat Memory не может создать `n8n_chat_histories`
  («no schema has been selected to create in»). Нужен пакет от DBA:
  `GRANT USAGE, CREATE ON SCHEMA hr_disciplinary_assistant TO hr_disciplinary_assistant_user;`
  `ALTER ROLE hr_disciplinary_assistant_user SET search_path = hr_disciplinary_assistant, public;`
- Workflow `Postgres_инициализация_схемы.json` создаёт таблицы (search_path + hr_cases + hr_evidence), подергать вручную.

Связано: [[deploy-prod-netherlands]], [[n8n-first-vs-item-far-refs]].
