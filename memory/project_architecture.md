---
name: project-architecture
description: "Архитектура n8n workflow, инфраструктура, команды запуска и открытые вопросы HR-ассистента"
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

- **PostgreSQL:** `host=localhost port=5432 dbname=hr_assistant user=olegkluev` (без пароля)
- **Ollama:** `http://localhost:11434`
- **n8n:** `http://localhost:5678`

---

## Архитектура workflow (n8n)

**Принцип:** один workflow = одна ответственность. Sub-workflows через `Execute Workflow`.

```
00_router.json (точка входа, Chat Trigger)
    ↓
lib_session.json      → создать/загрузить сессию из PG
lib_llm_call.json     → вызов Ollama + инъекция RAG-контекста
lib_rag_context.json  → RAG-заглушка (статичный ТК РФ → позже Qdrant)
lib_check_dates.json  → проверка сроков ТК ст.193
lib_build_sz.json     → составить служебную записку
    ↓
scenarios/sc1_progul_ochny.json  → Сц.1: Прогул офисник
```

**Импорт в n8n:** `./start.sh import` или по одному через `n8n import:workflow --input=file.json`.
ID-шники зашиты в JSON (формат `HR-LIB-*-01`), поэтому повторный импорт безопасен.

**Credential:** после импорта создать в n8n → Settings → Credentials → PostgreSQL:
- name: `hr_assistant PostgreSQL`
- host/port/db/user из таблицы выше

---

## Сценарии

| Ключ | Файл | Статус |
|------|------|--------|
| `progul_ochny` | sc1_progul_ochny.json | ✅ START + CHECK_DATES + EXPIRED |
| `progul_distant` | sc2 (нет) | ⏳ TODO |
| `progul_unclear` | sc3 (нет) | ⏳ TODO |
| `ndo` | sc4 (нет) | ⏳ TODO |
| `etika` | sc5 (нет) | ⏳ TODO |
| `opyanenie` | sc6 (нет) | ⏳ TODO |
| `ispytanie` | sc7 (нет) | ⏳ TODO |
| `ib_kt` | sc8 (нет) | ⏳ TODO → юр.служба |

**State machine:** `START → CHECK_DATES → INCIDENT_TYPE → SUBTYPE → VALIDATE_ABSENCE → BUILD_ACT → CHECK_ONGOING → BUILD_SZ → DONE` (+ `EXPIRED`)

---

## RAG-слот

`lib_rag_context.json` — Switch по `topic`, возвращает выдержки из ТК РФ.
Сейчас захардкожен. Заменить: открыть lib_rag_context, добавить Qdrant-нод вместо Code-нод.

Topics: `check_dates | progul | ndo | opyanenie | ispytanie | ib_kt | etika | sz_structure`

---

## Следующие шаги (очерёдность)

1. Создать credential PostgreSQL в n8n
2. Протестировать `START → CHECK_DATES` в чате n8n (qwen2.5:7b уже скачана)
3. Реализовать `INCIDENT_TYPE` — LLM классифицирует описание руководителя → определяет сценарий (ключ из таблицы выше)
4. Реализовать `SUBTYPE`, `VALIDATE_ABSENCE`, `BUILD_ACT`, `CHECK_ONGOING` для sc1
5. Получить шаблоны документов (DS-03 акт, DS-04 СЗ) от Черепановой/Касмыниной
6. Реализовать sc2 (прогул дистант) — большая часть кода sc1 переиспользуется

---

## Открытые вопросы

| Вопрос | К кому | Статус |
|--------|--------|--------|
| API у Контур.Норматив? | Команда Норматива | Не проверено |
| Источник НПА для RAG: Норматив / КП / Гарант | Клюев О. | Открыто |
| Шаблон акта об отсутствии (DS-03) | Черепанова / Касмынина | Нужно получить |
| Шаблон служебной записки (DS-04) | Черепанова / Касмынина | Нужно получить |
| «Самодельный дистант» — алгоритм | Касмынина О. | Открыто |
| Прогул продолжается: ассистент спрашивает или руководитель инициирует? | Клюев О. | Открыто |
| RAG-AAS ЦИИ интеграция с n8n | Вова Поздняков | Планируется |

---

## Связанные контакты

- RAG-AAS интеграция с n8n: Вова Поздняков
- n8n + RAG кейс: Яков Фуртиков
- ЛНА пилот: Дмитрий Воробьёв (RAG-AAS ЦИИ + КД, старт июль 2026)
- Эксперты кадрового учёта: Черепанова Т., Касмынина О.
