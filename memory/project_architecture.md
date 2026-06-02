---
name: project-architecture
description: "Архитектура n8n workflow v2 (AI Agent), инфраструктура, команды запуска и открытые вопросы HR-ассистента"
metadata:
  type: project
---

## Инфраструктура (всё локально, macOS M3)

| Сервис | Команда | Статус |
|--------|---------|--------|
| PostgreSQL 16 | `brew services start postgresql@16` | ✅ Авто-старт |
| Ollama | `brew services start ollama` | ✅ Авто-старт |
| n8n 2.10.3 | `n8n start` | ▶️ Ручной запуск |
| qwen2.5:7b | уже скачана в Ollama | ✅ Готова |
| nomic-embed-text | уже в Ollama | ✅ Готова |

**Единая команда запуска всего окружения:**
```bash
cd ~/Documents/Projects/hr-consultant && ./start.sh
```
Скрипт также поддерживает: `./start.sh stop`, `./start.sh status`, `./start.sh import`

**Why:** n8n запускается вручную, brew-сервисы стартуют автоматически.

**How to apply:** В начале каждой сессии проверять через `./start.sh status`. Если n8n не запущен — `./start.sh start`.

---

## Подключения

- **Ollama:** `http://127.0.0.1:11434` (не localhost — macOS резолвит в IPv6 ::1, Ollama слушает только IPv4)
- **PostgreSQL:** `host=localhost port=5432 dbname=hr_assistant user=olegkluev` (без пароля, зарезервирована)
- **n8n:** `http://localhost:5678`
- **GitHub:** https://github.com/Jojokora135791/hr-consultant

---

## Архитектура v2 — AI Agent (текущая)

**Принцип:** один LangChain AI Agent управляет диалогом. Инструменты вызываются по необходимости.

```
00_main_agent.json (точка входа, Chat Trigger)
    ↓
AI Agent (qwen2.5:7b через Ollama)
    ├── Tool: check_dates     → lib_check_dates.json (проверка сроков ТК ст.193)
    └── Tool: get_rag_context → lib_rag_context.json (выдержки из НПА)
    ↓ (когда фактура собрана и тип определён)
scenarios/sc1–sc8 (генерация документов)
    ↓
lib_build_sz.json / lib_final_pack.json
```

**Что изменилось от v1:**
- Нет state machine (START → CHECK_DATES → ...) — агент сам решает что спрашивать
- Нет PostgreSQL для сессий — используется Window Buffer Memory (20 сообщений, in-memory)
- Нет lib_session и lib_llm_call — перенесены в archive/
- Точка входа: `00_main_agent.json` вместо `00_router.json`

**Импорт в n8n:**
```bash
./start.sh import
```
или вручную по порядку из SETUP.md.

**Credential после импорта:** создать в n8n → Settings → Credentials → Ollama API:
- Base URL: `http://127.0.0.1:11434`
- Заменить `REPLACE_ME_OLLAMA` в ноде "Ollama qwen2.5:7b"

---

## Сценарии

| Ключ | Файл | Статус |
|------|------|--------|
| `progul_ochny` | sc1_progul_ochny.json | 🔄 Требует доработки под v2 |
| `progul_distant` | sc2_progul_distant.json | ⏳ Заглушка |
| `progul_unclear` | sc3_progul_unclear.json | ⏳ Заглушка |
| `ndo` | sc4_ndo.json | ⏳ Заглушка |
| `etika` | sc5_etika.json | ⏳ Заглушка |
| `opyanenie` | sc6_opyanenie.json | ⏳ Заглушка |
| `ispytanie` | sc7_ispytanie.json | ⏳ Заглушка |
| `ib_kt` | sc8_ib_kt.json | ⏳ Заглушка → юр.служба |

---

## RAG-слот

`lib_rag_context.json` — Switch по `rag_topic`, возвращает `context` — выдержки из НПА.
Вызывается агентом как Tool. Сейчас захардкожен.

Заменить: открыть lib_rag_context, добавить Qdrant-нод или HTTP Request к Контур.Норматив вместо Code-нод.

Topics: `check_dates | progul | ndo | opyanenie | ispytanie | ib_kt | etika | sz_structure`

---

## Следующие шаги (очерёдность)

1. Настроить credential Ollama API в n8n, протестировать AI Agent в чате
2. Переработать sc1 — принимать контекст от агента, генерировать акт и СЗ
3. Получить шаблоны документов (DS-03 акт, DS-04 СЗ) от Черепановой/Касмыниной
4. Реализовать sc2 (прогул дистант)
5. Подключить реальный RAG (Qdrant или Контур.Норматив)

---

## Открытые вопросы

| Вопрос | К кому | Статус |
|--------|--------|--------|
| API у Контур.Норматив? | Команда Норматива | Не проверено |
| Источник НПА для RAG: Норматив / КП / Гарант | Клюев О. | Открыто |
| Шаблон акта об отсутствии (DS-03) | Черепанова / Касмынина | Нужно получить |
| Шаблон служебной записки (DS-04) | Черепанова / Касмынина | Нужно получить |
| «Самодельный дистант» — алгоритм | Касмынина О. | Открыто |
| Передача СЗ: текст в чате или выгрузка в файл? | Клюев О. | Открыто |
| RAG-AAS ЦИИ интеграция с n8n | Вова Поздняков | Планируется (июль 2026) |

---

## Связанные контакты

- RAG-AAS интеграция с n8n: Вова Поздняков
- n8n + RAG кейс: Яков Фуртиков
- ЛНА пилот: Дмитрий Воробьёв (RAG-AAS ЦИИ + КД, старт июль 2026)
- Эксперты кадрового учёта: Черепанова Т., Касмынина О.
