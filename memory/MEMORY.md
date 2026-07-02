# Memory Index

- [Project: HR-консультант](project_hr_assistant.md) — ИИ-ассистент по служебным запискам для руководителей, реализуется в n8n
- [Architecture decisions](project_architecture.md) — n8n v8: Mattermost (бот mmpy_bot) + HR-агент на KonturGPT (внутри контура) + идентификация через Staff + детерминированная генерация .docx (petrovich) из Drive, calc_deadlines (относительные даты + сроки). Актуальный источник правды — CLAUDE.md
- [Интеграции с контуром Контура](kontur-integrations.md) — АКТУАЛЬНОЕ: Паспорт (OAuth Basic → токен), Mattermost вход через mmpy_bot (свой Node-WS рвётся 1006, connector удалён), Staff API, Postgres hr_disciplinary_assistant (🔴 блокер: права DBA + pg_hba, SSL=disable); статус отладки
- [Деплой в Нидерландах](deploy-prod-netherlands.md) — ⚠️ УСТАРЕЛО: пилот Docker/Anthropic, переехали внутрь контура на KonturGPT. Уроки MTU/VPN, Docker rate-limit — исторические
- [n8n: вложенные агенты падают](n8n-nested-agent-engine-request.md) — agentTool в агенте даёт «engine request not supported»; логику саб-агента переносить на toolCode/toolWorkflow
- [n8n: .first() vs .item](n8n-first-vs-item-far-refs.md) — far-ссылки после Telegram/HTTP-нод только через .first(), иначе теряются chat_id/флаги/поля
