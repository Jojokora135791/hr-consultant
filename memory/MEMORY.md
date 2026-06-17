# Memory Index

- [Project: HR-консультант](project_hr_assistant.md) — ИИ-ассистент по служебным запискам для руководителей, реализуется в n8n
- [Architecture decisions](project_architecture.md) — n8n v6: Telegram-бот + HR-агент на Claude Opus 4.8 (облако) + Генерация на Ollama (локаль) с рендером .docx из Google Drive (adm-zip), Postgres память/кейсы, calc_deadlines прямой тул, ст.193 только в main
- [n8n: вложенные агенты падают](n8n-nested-agent-engine-request.md) — agentTool в агенте даёт «engine request not supported»; логику саб-агента переносить на toolCode/toolWorkflow
