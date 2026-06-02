# Архитектура n8n workflows — HR-ассистент (v2)

## Принципы

1. **AI Agent вместо state machine.** Главный workflow — один LangChain AI Agent, который сам ведёт диалог и решает что спрашивать. Нет жёсткого переключения состояний через PostgreSQL.
2. **Инструменты вместо sub-workflow цепочек.** Агент вызывает `check_dates` и `get_rag_context` как инструменты по необходимости — не по шагам.
3. **Сценарии — для генерации документов.** sc1–sc8 вызываются когда фактура собрана и тип нарушения определён. Каждый сценарий отвечает за оформление конкретного пакета документов.
4. **RAG — заглушка с текстами ТК РФ.** Позже заменяется на Qdrant или Контур.Норматив API без изменения интерфейса.

---

## Схема вызовов

```
Пользователь (Chat UI)
        ↓
  00_main_agent.json  ← ТОЧКА ВХОДА
        ↓
  AI Agent (qwen2.5:7b)
        ├── Tool: check_dates    → lib/lib_check_dates.json
        └── Tool: get_rag_context → lib/lib_rag_context.json
        ↓ (когда фактура собрана и тип определён)
  sc1_progul_ochny / sc2 / ... / sc8
        ↓
  lib/lib_build_sz.json
  lib/lib_final_pack.json
```

---

## Файлы

### Точка входа
| Файл | Назначение |
|------|------------|
| `00_main_agent.json` | Chat Trigger → AI Agent с инструментами |

### Инструменты агента (lib/)
| Файл | Назначение | Вход | Выход |
|------|------------|------|-------|
| `lib_check_dates.json` | Проверка сроков ТК РФ ст.193 | `violationDate`, `discoveryDate` | `isExpired`, `expiredReason`, `violationDeadline`, `discoveryDeadline` |
| `lib_rag_context.json` | Выдержки из НПА по теме (заглушка) | `rag_topic` | `context` (строка) |

### Вспомогательные библиотеки (lib/)
| Файл | Назначение |
|------|------------|
| `lib_build_sz.json` | Составить служебную записку по шаблону |
| `lib_final_pack.json` | Финальная инструкция по передаче пакета |

### Сценарии (scenarios/)
| Файл | Сценарий | Статус |
|------|----------|--------|
| `sc1_progul_ochny.json` | Прогул, очное присутствие (офисник) | 🔄 Требует доработки под v2 |
| `sc2_progul_distant.json` | Прогул, дистанционный | ⏳ Заглушка |
| `sc3_progul_unclear.json` | Прогул, неопределённый формат | ⏳ Заглушка |
| `sc4_ndo.json` | Ненадлежащее исполнение ДО | ⏳ Заглушка |
| `sc5_etika.json` | Нарушение этики | ⏳ Заглушка |
| `sc6_opyanenie.json` | Опьянение | ⏳ Заглушка |
| `sc7_ispytanie.json` | Испытательный срок (неудача) | ⏳ Заглушка |
| `sc8_ib_kt.json` | Нарушение ИБ / КТ | ⏳ Заглушка (→ юр.служба) |

### Архив (archive/)
| Файл | Причина архивации |
|------|-------------------|
| `00_router_v1.json` | Заменён на 00_main_agent.json (AI Agent) |
| `lib_session_v1.json` | Сессии управляются памятью агента |
| `lib_llm_call_v1.json` | LLM вызывается агентом нативно |
| `DEPRECATED_hr_scenario1_v1.json` | Первый прототип, устарел |

---

## RAG-заглушка

`lib_rag_context.json` принимает `rag_topic` и возвращает `context` — текст из НПА.

**Сейчас:** статичные тексты статей ТК РФ, захардкоженные в Code-нодах.

**Позже:** заменить Code-ноды на Qdrant Vector Store или HTTP Request к Контур.Норматив API.

Доступные темы:
| topic | НПА |
|-------|-----|
| `check_dates` | ТК РФ ст. 193 (сроки взысканий) |
| `progul` | ТК РФ ст. 81 п.6а (прогул) |
| `ndo` | ТК РФ ст. 81 п.5 (неисполнение ДО) |
| `opyanenie` | ТК РФ ст. 81 п.6б (опьянение) |
| `ispytanie` | ТК РФ ст. 71 (испытательный срок) |
| `ib_kt` | → юр.служба / ОИБО |
| `etika` | Внутренние ЛНА (DS-02) |
| `sz_structure` | Структура СЗ (ЛНА) |

---

## Порядок импорта в n8n

1. `lib/lib_rag_context.json`
2. `lib/lib_check_dates.json`
3. `lib/lib_build_sz.json`
4. `lib/lib_final_pack.json`
5. `scenarios/sc1_progul_ochny.json` — и остальные sc2–sc8
6. `00_main_agent.json` — **последним**

После импорта:
- Создать credential **Ollama API** → Base URL: `http://127.0.0.1:11434`
- Заменить `REPLACE_ME_OLLAMA` в ноде "Ollama qwen2.5:7b"

---

## Настройка памяти агента

По умолчанию: **Window Buffer Memory** (20 последних сообщений, in-memory).

При необходимости персистентной памяти — заменить на **PostgreSQL Chat Memory**:
- Нод: `@n8n/n8n-nodes-langchain.memoryPostgresChat`
- БД: hr_assistant, таблица создаётся автоматически
- Передавать sessionId из chat trigger

---

## Как добавить новый сценарий

1. Создать `scenarios/sc_NEW.json` с триггером `executeWorkflowTrigger`
2. Принимаемые данные: всё что агент собрал в диалоге (JSON)
3. Вернуть `{ output: "..." }` — текст ответа для пользователя
4. Обновить системный промпт агента в `00_main_agent.json`
