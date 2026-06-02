# Настройка workflow в n8n

> Подробная архитектура и порядок зависимостей — в [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. Создать Credential: PostgreSQL

Открой n8n → Settings → Credentials → Add credential → PostgreSQL

| Поле | Значение |
|------|----------|
| Host | localhost |
| Port | 5432 |
| Database | hr_assistant |
| User | olegkluev |
| Password | (пусто) |
| SSL | отключён |

Сохрани. Запомни **ID** (виден в URL: `/credentials/XXXX`).

---

## 2. Импортировать workflow

### Вариант А — автоматически (рекомендуется)

```bash
cd n8n/workflows
bash setup/install.sh
```

Скрипт импортирует все workflow через n8n API, автоматически подставляя реальные ID sub-workflow вместо плейсхолдеров `REPLACE_WITH_*`.

> ⚠️ После автоимпорта всё равно нужно вручную указать credential в postgres-нодах (см. шаг 3).

### Вариант Б — вручную

Импортировать строго в таком порядке:

1. `lib/lib_rag_context.json`
2. `lib/lib_llm_call.json`
3. `lib/lib_session.json`
4. `lib/lib_check_dates.json`
5. `lib/lib_build_sz.json`
6. `scenarios/sc1_progul_ochny.json`
7. `00_router.json` — последним

Для каждого: n8n → Workflows → иконка импорта (↑) → Import from file.

После импорта вручную нужно заменить плейсхолдеры `REPLACE_WITH_*` в нодах "Execute Workflow" на реальные ID (видны в URL открытого workflow).

---

## 3. Подключить credential к PostgreSQL-нодам

После импорта у postgres-нодов будет ошибка (credential `REPLACE_ME` не найден). Зайди в каждый из перечисленных нодов и выбери созданный credential.

**lib_session.json:**
- `PostgreSQL: создать сессию (если новая)`
- `PostgreSQL: загрузить state, context и историю`

**lib_check_dates.json:**
- `PostgreSQL: проверить сроки по ТК РФ ст.193`

**sc1_progul_ochny.json:**
- `СТАРТ: PostgreSQL — сохранить, state → CHECK_DATES`
- `ПРОСРОЧЕНО: PostgreSQL — сохранить, state → EXPIRED`
- `ДАТЫ (OK): PostgreSQL — сохранить, state → INCIDENT_TYPE`
- `ДАТЫ (ждём): PostgreSQL — сохранить, остаться`

---

## 4. Убедиться, что Ollama запущена и модель готова

```bash
ollama list
# Должна быть: qwen2.5:7b
```

Если модели нет:
```bash
ollama pull qwen2.5:7b
```

---

## 5. Тест

1. Открой `00: HR-ассистент — точка входа` → нажми **Test Workflow**
2. В чате напиши: `"Здравствуйте, у меня сотрудник не пришёл на работу"`
3. Ассистент должен поздороваться и спросить даты нарушения

---

## Текущий статус реализации

| State | Статус |
|-------|--------|
| `START` | ✅ Реализован |
| `CHECK_DATES` | ✅ Реализован (с проверкой сроков ТК ст.193) |
| `EXPIRED` | ✅ Реализован (переход из CHECK_DATES) |
| `INCIDENT_TYPE` | ⏳ TODO |
| `SUBTYPE` | ⏳ TODO |
| `VALIDATE_ABSENCE` | ⏳ TODO |
| `BUILD_ACT` | ⏳ TODO |
| `CHECK_ONGOING` | ⏳ TODO |
| `BUILD_SZ` | ⏳ Заглушка (lib_build_sz.json создан) |
| `DONE` | ⏳ TODO |
