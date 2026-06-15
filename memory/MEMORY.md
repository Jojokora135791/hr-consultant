# Memory Index

- [Project: HR-консультант](project_hr_assistant.md) — ИИ-ассистент по служебным запискам для руководителей, реализуется в n8n
- [Architecture decisions](project_architecture.md) — n8n v5: HR-агент на Claude Opus 4.8 (облако) + Генерация на Ollama (локаль), calc_deadlines прямой тул, саб-агент убран, файлы HR-агент.json/Генерация документов.json
- [n8n: вложенные агенты падают](n8n-nested-agent-engine-request.md) — agentTool в агенте даёт «engine request not supported»; логику саб-агента переносить на toolCode/toolWorkflow
