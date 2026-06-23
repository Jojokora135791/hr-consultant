# Memory Index

- [Project: HR-консультант](project_hr_assistant.md) — ИИ-ассистент по служебным запискам для руководителей, реализуется в n8n
- [Architecture decisions](project_architecture.md) — n8n v7: Telegram-бот + HR-агент на Claude (облако) + детерминированная генерация .docx (petrovich, БЕЗ Ollama) из Google Drive (adm-zip), скриншоты в СЗ, Postgres память/кейсы/доказательства, calc_deadlines прямой тул. Актуальный источник правды — CLAUDE.md
- [Деплой: прод в Нидерландах](deploy-prod-netherlands.md) — Docker (n8n+Postgres+Caddy) на Timeweb VPS NL, домен hr-kontur.ru; Anthropic блочит РФ-IP (403) → сервер НЕ в РФ; уроки MTU/VPN, Docker rate-limit, swap
- [n8n: вложенные агенты падают](n8n-nested-agent-engine-request.md) — agentTool в агенте даёт «engine request not supported»; логику саб-агента переносить на toolCode/toolWorkflow
- [n8n: .first() vs .item](n8n-first-vs-item-far-refs.md) — far-ссылки после Telegram/HTTP-нод только через .first(), иначе теряются chat_id/флаги/поля
