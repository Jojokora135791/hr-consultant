-- HR-консультант — схема Postgres
-- Прод Контура: БД `n8n`, схема `hr_disciplinary_assistant` (host devof-pt-vxsa1.dev.kontur.ru).
-- Применить: psql -d n8n -f db/schema.sql   (или через workflow «Postgres: инициализация схемы»)
--
-- Таблица n8n_chat_histories (память диалога) создаётся автоматически нодой
-- "Postgres Chat Memory" — здесь её НЕ объявляем.

CREATE SCHEMA IF NOT EXISTS hr_disciplinary_assistant;

-- Ключевые данные кейсов — для отладки и будущих дашбордов.
-- Пишется после успешной генерации документов ("Финальный ответ" в Генерации).
CREATE TABLE IF NOT EXISTS hr_disciplinary_assistant.hr_cases (
    id              SERIAL PRIMARY KEY,
    chat_id         TEXT        NOT NULL,   -- = channel_id Mattermost (DM)
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

CREATE INDEX IF NOT EXISTS idx_hr_cases_chat_id    ON hr_disciplinary_assistant.hr_cases (chat_id);
CREATE INDEX IF NOT EXISTS idx_hr_cases_created_at ON hr_disciplinary_assistant.hr_cases (created_at);
CREATE INDEX IF NOT EXISTS idx_hr_cases_scenario   ON hr_disciplinary_assistant.hr_cases (scenario);

-- Доказательства (фото). В v7 (Mattermost) приём фото отложён — таблица под будущее.
CREATE TABLE IF NOT EXISTS hr_disciplinary_assistant.hr_evidence (
    id          SERIAL PRIMARY KEY,
    chat_id     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    file_id     TEXT,                  -- id файла (Mattermost/Telegram)
    file_size   BIGINT,                -- размер файла (байт); >0 = валиден
    downloaded  BOOLEAN DEFAULT FALSE, -- удалось ли реально скачать
    note        TEXT,                  -- комментарий/тип доказательства
    file_b64    TEXT                   -- сами байты фото в base64 (для вставки в .docx)
);

CREATE INDEX IF NOT EXISTS idx_hr_evidence_chat_id ON hr_disciplinary_assistant.hr_evidence (chat_id);
