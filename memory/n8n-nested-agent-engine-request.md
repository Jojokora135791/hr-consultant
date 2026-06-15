---
name: n8n-nested-agent-engine-request
description: "n8n: вложенный AI Agent (agentTool) внутри агента падает с 'engine request not supported in Agents' — не вкладывать агентов"
metadata:
  type: reference
---

В n8n **нельзя вкладывать AI Agent в AI Agent** через тип `agentTool` (саб-агент со своими
слотами Chat Model / Memory / Tool). При вызове родительским агентом вложенный возвращает
внутренний «engine request», который родитель принять не может:

```
Error: The Tool attempted to return an engine request, which is not supported in Agents
```

**Why:** n8n не умеет возвращать результат вложенного агента обратно в родительский агент.

**How to apply:** Логику саб-агента переноси на инструменты прямого типа — `toolCode` (Code Tool),
`toolWorkflow` (Execute Workflow Tool), HTTP Request Tool. Их результат — обычный текст/JSON, агент
принимает нормально. В hr-consultant именно так убрали саб-агента «Ресерчёр по срокам» и повесили
`calc_deadlines` (toolCode) прямым тулом на агента. См. [[project-architecture]].

**Коварство:** на слабой локальной модели (qwen2.5:7b) баг может не всплывать — модель просто не
вызывает тул корректно. Сильная модель (Claude) вызывает правильно и обнажает проблему. То есть
ошибка появляется «вдруг» после смены модели, хотя причина — в архитектуре инструментов.
