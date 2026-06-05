# Настройка workflow в n8n (v2 — AI Agent)

> Подробная архитектура и порядок зависимостей — в [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. Создать Credential: Ollama API

Открой n8n → Settings → Credentials → Add credential → Ollama API

| Поле | Значение |
|------|----------|
| Base URL | http://127.0.0.1:11434 |

> ⚠️ Используй именно `127.0.0.1`, а не `localhost` — macOS резолвит `localhost` в IPv6 (`::1`), Ollama слушает только IPv4.

Сохрани. Запомни **ID** (виден в URL: `/credentials/XXXX`).

---

## 2. Импортировать workflow

### Вариант А — автоматически

```bash
cd ~/Documents/Projects/hr-consultant
./start.sh import
```

### Вариант Б — вручную

Импортировать строго в таком порядке:

1. `lib/lib_rag_context.json`
2. `lib/lib_check_dates.json`
3. `lib/lib_build_sz.json`
4. `lib/lib_final_pack.json`
5. `scenarios/sc1_progul_ochny.json` — и остальные sc2–sc8
6. `00_main_agent.json` — **последним**

Для каждого: n8n → Workflows → иконка импорта (↑) → Import from file.

> Файлы `archive/` импортировать **не нужно** — они устарели.

---

## 3. Подключить credential к Ollama-ноду

После импорта `00_main_agent.json` открой его → найди ноду **"Ollama qwen2.5:7b"** → замени credential `REPLACE_ME_OLLAMA` на созданный на шаге 1.

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

1. Открой `HR-ассистент (AI Agent)` → нажми **Test Workflow**
2. В чате напиши: `"Здравствуйте, у меня сотрудник не пришёл на работу"`
3. Ассистент должен поздороваться и попросить описать ситуацию
4. После указания дат — должен автоматически вызвать `check_dates`

---

## Текущий статус реализации

| Компонент | Статус |
|-----------|--------|
| AI Agent (главный диалог) | ✅ Реализован |
| Tool: check_dates | ✅ Реализован |
| Tool: get_rag_context | ✅ Реализован (заглушка) |
| sc1: генерация акта (BUILD_ACT) | 🔄 Требует доработки под v2 |
| sc1: генерация СЗ (BUILD_SZ) | 🔄 Требует доработки под v2 |
| sc2–sc8 | ⏳ Заглушки |

---

## Если нужен PostgreSQL (опционально)

PostgreSQL создана и доступна, но активно не используется в v2 (сессии хранятся в памяти агента).

Если понадобится персистентная память — заменить `Window Buffer Memory` на `PostgreSQL Chat Memory`:

| Поле | Значение |
|------|----------|
| Host | localhost |
| Port | 5432 |
| Database | hr_assistant |
| User | olegkluev |
| Password | (пусто) |
| SSL | отключён |
