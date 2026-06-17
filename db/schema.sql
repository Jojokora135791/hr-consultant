-- HR-консультант — схема Postgres (БД hr_assistant)
-- Применить: psql -d hr_assistant -f db/schema.sql
--
-- Таблица n8n_chat_histories (история диалога) создаётся автоматически нодой
-- "Postgres Chat Memory" в HR-агенте — здесь её НЕ объявляем, чтобы не конфликтовать
-- с форматом ноды (session_id varchar + message jsonb).

-- Ключевые данные кейсов — для отладки и будущих дашбордов.
-- Пишется после успешной генерации документов ("Финальный ответ" в Генерации).
CREATE TABLE IF NOT EXISTS hr_cases (
    id              SERIAL PRIMARY KEY,
    chat_id         TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    manager_name    TEXT,
    employee_name   TEXT,
    department      TEXT,
    scenario        TEXT,                  -- progul_ochny | zaglushka | ...
    violation_date  DATE,
    discovery_date  DATE,
    is_expired      BOOLEAN,               -- истёк ли срок ст.193 (из calc_deadlines)
    docs_generated  BOOLEAN DEFAULT FALSE, -- сформированы ли акт + СЗ
    raw_data        JSONB                  -- полный JSON, переданный в генерацию
);

CREATE INDEX IF NOT EXISTS idx_hr_cases_chat_id    ON hr_cases (chat_id);
CREATE INDEX IF NOT EXISTS idx_hr_cases_created_at ON hr_cases (created_at);
CREATE INDEX IF NOT EXISTS idx_hr_cases_scenario   ON hr_cases (scenario);

-- Доказательства (фото из Telegram). Валидация скачивания на этапе сбора.
CREATE TABLE IF NOT EXISTS hr_evidence (
    id          SERIAL PRIMARY KEY,
    chat_id     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    file_id     TEXT,                  -- Telegram file_id
    file_size   BIGINT,                -- размер файла (байт); >0 = валиден
    downloaded  BOOLEAN DEFAULT FALSE, -- удалось ли реально скачать
    note        TEXT                   -- комментарий/тип доказательства
);

CREATE INDEX IF NOT EXISTS idx_hr_evidence_chat_id ON hr_evidence (chat_id);
