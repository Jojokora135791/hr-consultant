---
name: project-architecture
description: "Архитектура n8n workflow. АКТУАЛЬНО — v8 (Mattermost + KonturGPT внутри контура + Staff). Источник правды — CLAUDE.md и [[kontur-integrations]]. Текст ниже — история v6/v7"
metadata:
  type: project
---

> ⚠️ **АКТУАЛЬНО v8 (источник правды — `CLAUDE.md` + [[kontur-integrations]]).** Переезд внутрь контура:
> - **Интерфейс — Mattermost** (бот на `mmpy_bot`, `bot/`): WS → webhook `/mattermost-in`; выход — `POST /api/v4/posts`. Telegram убран.
> - **Диалог — KonturGPT** (`preview-pro`, внутри контура), не Claude/Anthropic. n8n на `n8n-common.testkontur.ru`.
> - **Идентификация сотрудников через Staff API** (workflow «Идентификация пользователя», токен из Паспорта).
> - **calc_deadlines** расширен: резолвит относительные даты («вчера/сегодня/завтра») + сроки ст.193.
> - **Postgres** — схема `hr_disciplinary_assistant`, SSL=`disable`; 🔴 блокер прав DBA + pg_hba (см. [[kontur-integrations]]).
> - **Отлажены вживую только Mattermost + Паспорт + переезд**; идентификация/даты/генерация-в-MM — не тестированы.
> - **Генерация без Ollama** (petrovich +JS), скриншоты в СЗ (механика готова, приём фото в MM отложен).
> - `deploy/` (Нидерланды) — legacy, см. [[deploy-prod-netherlands]].

## Инфраструктура v6 (локально, macOS M3) — историческая, см. CLAUDE.md для прод

| Сервис | Команда | Статус |
|--------|---------|--------|
| Ollama | `brew services start ollama` | ✅ Авто-старт |
| n8n 2.10.3 | `NODE_FUNCTION_ALLOW_EXTERNAL=adm-zip WEBHOOK_URL=<туннель> n8n start` | ▶️ Ручной запуск |
| qwen2.5:7b | уже скачана в Ollama | ✅ Готова |
| nomic-embed-text | уже в Ollama | ✅ Готова |
| PostgreSQL 16 | `brew services start postgresql@16` | ✅ Задействована (память + кейсы) |
| cloudflared | `cloudflared tunnel --url http://localhost:5678` | 🧪 Webhook для Telegram |

**Запуск окружения вручную:**
```bash
brew services start ollama
brew services start postgresql@16
cloudflared tunnel --url http://localhost:5678
NODE_FUNCTION_ALLOW_EXTERNAL=adm-zip WEBHOOK_URL=https://<туннель> n8n start
```

> ⚠️ `NODE_FUNCTION_ALLOW_EXTERNAL=adm-zip` обязателен — иначе Code-ноды рендера .docx не подключат adm-zip.
> ⚠️ URL cloudflared-туннеля меняется при каждом перезапуске → после смены переактивировать workflow
> (Active off/on), чтобы Telegram-webhook перерегистрировался.

**How to apply:** В начале сессии проверять, запущен ли n8n (`http://localhost:5678`), Postgres и туннель.

---

## Подключения

- **Ollama:** `http://127.0.0.1:11434` (не localhost — macOS резолвит в IPv6 ::1, Ollama слушает только IPv4)
- **n8n:** `http://localhost:5678`
- **GitHub:** https://github.com/Jojokora135791/hr-consultant
- **PostgreSQL:** `host=localhost port=5432 dbname=hr_assistant user=olegkluev` (схема в `db/schema.sql`)
- **Google Drive:** Service Account `N8N-kontur` — только чтение (download/export), нет квоты на запись.

---

## Архитектура v6 — два workflow (Telegram + рендер .docx + Postgres)

**Принцип:** вся система — **два** workflow. Диалоговый AI Agent на **Claude (облако)** ведёт диалог
в Telegram; конвейер генерации на **Ollama (локально)** собирает готовые .docx из шаблонов Google Drive.
Проверка сроков — прямой Code-тул на агенте.

```
HR-агент.json (точка входа)
    ↓ Telegram: входящие (Telegram Trigger)
    ↓ Нормализация входа TG (Code: text/photo + валидация фото → hr_evidence)
    ↓ HR-ассистент (AI Agent, Claude Opus 4.8)
    ├── Postgres память (Postgres Chat Memory, sessionKey = chat_id, окно 30)
    ├── Tool: calc_deadlines (toolCode/JS) — ПРЯМОЙ тул, проверка сроков ст.193
    └── Tool: generate_documents → Генерация документов.json (toolWorkflow)
    ↓ Telegram: ответ (Send Message, parse_mode=HTML)

Генерация документов.json (Ollama + рендер .docx, БЕЗ проверки сроков):
    Вызов из агента → Нормализовать данные → Выбор сценария (Switch)
    → [progul_ochny: Drive скачать чеклист → Прочитать данные прогула | zaglushka]
    → Vision (заглушка) → Промпт нарушений (RAG) → Ollama HTTP → Объединить нарушения (chat_id)
    → Значения документов (context→плейсхолдеры + DOC_MAP) → Ollama умные значения (JSON) → Объединить значения
    → Статус ⏳ → Нужен акт? (IF) → [Drive акт → Рендер adm-zip → Telegram sendDocument]
    → Нужна СЗ? (IF) → [Drive СЗ → Рендер adm-zip → Telegram sendDocument]
    → Финальный ответ → Postgres запись кейса (hr_cases) → Вернуть результат
```

**Модели:**
- Диалог: **Claude Opus 4.8** (`anthropicApi`, Base URL `https://api.anthropic.com`). Облако, платно.
- Генерация: **Ollama qwen2.5:7b** локально (HTTP к `127.0.0.1:11434/api/generate`).

**Рендер .docx (гибрид).** Шаблоны — `.docx`/Google Docs в Google Drive с цельными `{{плейсхолдерами}}`.
Service Account скачивает шаблон (копировать не может — 403 storageQuotaExceeded, нет квоты), значения
подставляются локально через **adm-zip** (правка `word/document.xml`), результат уходит в Telegram
`sendDocument`. Детерминированные поля — из Code; «умные» (падежи, абзацы, приложения) — Ollama JSON.
Вариативность документов — `DOC_MAP { scenario: {нужен_акт, нужна_сз} }` + развилки `Нужен акт?`/`Нужна СЗ?`.

**fileId в Drive:** акт `1pz4mHqz6dleQKZvit3VRfXs_h95VWqKl`, СЗ `1iiqEDumDy61qRr9lv0kFGpkUB3hTpkWd`,
чеклист `1AkZ9oCM6EzNHewmEiwqvERmq9cKDMt0V`.

**Сбор полей под шаблоны (25 плейсхолдеров).** Агент в Шаг 2 собирает: сотрудник (ФИО/должность/
подразделение), даты и время отсутствия, **город+адрес рабочего места**, попытки связи, уважительная
причина, доказательства, **руководитель (ФИО/должность/подразделение** — автор СЗ и составитель акта),
**2 свидетеля** (ФИО+должность, агент поясняет зачем). Передаёт в `generate_documents`:
`employee`, `manager{+department}`, `workplace{city,address}`, `witnesses[2]`, `violation`,
`respectableReason`, `evidenceDescription`, `contactAttempts`, `chat_id`. Хардкод в «Значения
документов»: организация `АО «ПФ «СКБ Контур»`, адресат СЗ `Директору` + пустой ФИО, время акта — авто.

> ⚠️ **`.first()`, не `.item`** в far-ссылках после Telegram/HTTP-нод (они роняют вход). `.item`
> рвётся при разрыве потока и поштучном Execute → развилки в False, `chat_id is empty`, поля undefined.
> Все потребители chat_id берут из `Нормализовать данные` через `.first()`. Отлаживать только полным
> прогоном. См. [[n8n-first-vs-item-far-refs]].

**Проверка сроков ст.193 (Шаг 4) — только в main-агенте, через `calc_deadlines`:**
- Агент вызывает `calc_deadlines` со строкой `"violationDate=ГГГГ-ММ-ДД; discoveryDate=ГГГГ-ММ-ДД"`.
- Возврат: `{ isExpired, expiredReason, violationDeadline, discoveryDeadline }`. Агент не считает даты сам.
- Срок истёк → генерация не запускается, направить к Касмыниной О. / Черепановой Т.
- ⚠️ В генерации ст.193 НЕ дублируется (раньше был вшитый `tk_content` — убран). Чеклист — динамический из Drive.

**Почему убран саб-агент «Ресерчёр по срокам»** (был в v4): вложенный AI Agent (`agentTool`)
даёт ошибку **«The Tool attempted to return an engine request, which is not supported in Agents»**.
Решение: `calc_deadlines` прямым тулом. См. [[n8n-nested-agent-engine-request]].

> 🔒 **Приватность (НЕ паниковать):** Claude в диалоге и Google Drive для шаблонов — **для отладки**.
> Олег **НЕ гоняет продовые/реальные ПД** через облако. Вопрос «облако vs локаль для прода» (152-ФЗ,
> трансграничная передача ФИО) — отложен. Не предлагать паническую миграцию; для прода — решение Олега.

**Буферные сроки** (внутренний буфер Контура, НЕ дословно ТК; baseline ТК — 6 мес / 30 дн):
от нарушения **+5 мес. 15 дн.**, от обнаружения **+20 дн.** Зашиты в `calc_deadlines`. Уточнять у Касмыниной О.

**Postgres-таблицы:** `n8n_chat_histories` (память, создаёт сама нода), `hr_cases` (кейсы),
`hr_evidence` (фото-доказательства). Схема — `db/schema.sql`. ⚠️ В маппинге Postgres-нод НЕ указывать
колонку `id` (SERIAL автоинкремент — иначе id=0 и duplicate key).

**Что изменилось от v5:**
- Интерфейс: встроенный n8n-чат → **Telegram** (Trigger + Send Message + нормализация входа + фото).
- Память: in-memory Window Buffer → **Postgres Chat Memory**.
- Postgres **задействована** (была зарезервирована): память + hr_cases + hr_evidence.
- Шаблоны: вшитый текст в Code → **.docx в Google Drive** + рендер через adm-zip.
- Чеклист: вшит → **динамически из Drive**. ТК ст.193 в генерации — **убрана** (только calc_deadlines).
- Добавлены промежуточные статусы ⏳, развилки `Нужен акт?`/`Нужна СЗ?` (DOC_MAP).

---

## Сценарии

| Ключ | Где обрабатывается | Статус |
|------|--------------------|--------|
| `progul_ochny` | ветка Switch «Выбор сценария» | ✅ MVP реализован |
| `zaglushka` | ветка-заглушка (любой иной случай) | ✅ Fallback |
| `progul_distant` | — | ⏳ Следующая итерация |
| `ndo` / `opyanenie` / `ispytanie` | — | ⏳ Заглушка |
| `ib_kt` | — | ⏳ → юр.служба |

Агент присваивает `progul_ochny` только для очного прогула (сотрудник не ходит в офис), иначе — `zaglushka`.

---

## RAG-слот

Сейчас «RAG» — Code-нода `Промпт: нарушения (RAG)` + чеклист, подгружаемый целиком из Drive.
Реальной векторной БД и поиска по чанкам пока нет.
Заменить (ROADMAP P1.2): Qdrant или pgvector + Ollama nomic-embed-text → топ-N чанков в промпт.
Интеграция с RAG-AAS ЦИИ (Вова Поздняков) — июль 2026.

---

## Следующие шаги (см. ROADMAP.md)

1. ✅ P0.1 — Telegram-бот + промежуточные статусы
2. ✅ P1.1 — Рендер документов в .docx (Drive)
3. ✅ P1.4 — Postgres память + кейсы (база)
4. P0.2 — Robustness промптов на нетиповых сценариях
5. P1.2 — Реальный RAG (Qdrant/pgvector)
6. P1.3 — Vision (анализ фото-доказательств)
7. P2 — Деплой на сервер + решение по 152-ФЗ

---

## Открытые вопросы

| Вопрос | К кому | Статус |
|--------|--------|--------|
| Облако vs локаль для прода (Claude + Drive = ПД в облако, 152-ФЗ) | Клюев О. + ИБ | Отложено (отладка, не прод) |
| Буферные сроки (5 мес 15 дн / 20 дн) — подтвердить | Касмынина О. | Уточнить |
| Шаблон акта (DS-03) / СЗ (DS-04) — утверждённые | Черепанова / Касмынина | Нужно получить |
| RAG-AAS ЦИИ интеграция с n8n | Вова Поздняков | Планируется (июль 2026) |
| «Самодельный дистант» — алгоритм | Касмынина О. | Открыто |

---

## Связанные контакты

- RAG-AAS интеграция с n8n: Вова Поздняков
- n8n + RAG кейс: Яков Фуртиков
- ЛНА пилот: Дмитрий Воробьёв (RAG-AAS ЦИИ + КД, старт июль 2026)
- Эксперты кадрового учёта: Черепанова Т., Касмынина О.
