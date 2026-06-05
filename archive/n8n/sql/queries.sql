-- =============================================
-- HR-ассистент — SQL-запросы для n8n workflow
-- =============================================

-- ============================================
-- 1. ЗАГРУЗКА / СОЗДАНИЕ СЕССИИ
-- ============================================
-- Используется в начале каждого workflow
-- Параметр: $1 = session_id (из ChatTrigger)

INSERT INTO sessions (session_id, state, context)
VALUES ($1, 'START', '{}')
ON CONFLICT (session_id) DO NOTHING;

SELECT session_id, state, context
FROM sessions
WHERE session_id = $1;


-- ============================================
-- 2. ОБНОВЛЕНИЕ STATE
-- ============================================
-- Параметры: $1 = new_state, $2 = session_id

UPDATE sessions
SET state = $1
WHERE session_id = $2;


-- ============================================
-- 3. ОБНОВЛЕНИЕ CONTEXT (merge JSONB)
-- ============================================
-- Параметры: $1 = JSON-объект с новыми полями, $2 = session_id
-- Оператор || — мёрдж JSONB (новые поля перезаписывают старые)

UPDATE sessions
SET context = context || $1::jsonb
WHERE session_id = $2;


-- ============================================
-- 4. ОБНОВЛЕНИЕ STATE + CONTEXT ОДНОВРЕМЕННО
-- ============================================
-- Параметры: $1 = new_state, $2 = JSON-объект, $3 = session_id

UPDATE sessions
SET state   = $1,
    context = context || $2::jsonb
WHERE session_id = $3;


-- ============================================
-- 5. СОХРАНЕНИЕ СООБЩЕНИЯ В ИСТОРИЮ
-- ============================================
-- Параметры: $1 = session_id, $2 = role ('user'/'assistant'/'system'), $3 = content

INSERT INTO messages (session_id, role, content)
VALUES ($1, $2, $3);


-- ============================================
-- 6. ЗАГРУЗКА ИСТОРИИ ДИАЛОГА (последние N сообщений)
-- ============================================
-- Параметры: $1 = session_id, $2 = limit (рекомендуется 20)

SELECT role, content, created_at
FROM messages
WHERE session_id = $1
ORDER BY created_at ASC
LIMIT $2;


-- ============================================
-- 7. ЗАГРУЗКА ПОЛНОГО СОСТОЯНИЯ СЕССИИ
-- ============================================
-- Параметры: $1 = session_id

SELECT
    s.session_id,
    s.state,
    s.context,
    COALESCE(
        json_agg(
            json_build_object('role', m.role, 'content', m.content)
            ORDER BY m.created_at ASC
        ) FILTER (WHERE m.id IS NOT NULL),
        '[]'::json
    ) AS history
FROM sessions s
LEFT JOIN messages m ON m.session_id = s.session_id
WHERE s.session_id = $1
GROUP BY s.session_id, s.state, s.context;


-- ============================================
-- 8. ПРОВЕРКА СРОКОВ (CHECK_DATES)
-- ============================================
-- Проверяет оба условия ТК РФ ст. 193
-- Параметры: $1 = violation_date (DATE), $2 = discovery_date (DATE)
-- Возвращает: is_expired BOOLEAN

SELECT
    CASE
        WHEN CURRENT_DATE > $1::date + INTERVAL '5 months 15 days' THEN TRUE
        WHEN CURRENT_DATE > $2::date + INTERVAL '20 days' THEN TRUE
        ELSE FALSE
    END AS is_expired,
    CASE
        WHEN CURRENT_DATE > $1::date + INTERVAL '5 months 15 days' THEN 'violation_date'
        WHEN CURRENT_DATE > $2::date + INTERVAL '20 days' THEN 'discovery_date'
        ELSE NULL
    END AS expired_reason,
    ($1::date + INTERVAL '5 months 15 days')::date AS violation_deadline,
    ($2::date + INTERVAL '20 days')::date AS discovery_deadline;


-- ============================================
-- 9. ОЧИСТКА ЗАВЕРШЁННЫХ СЕССИЙ (опционально, для обслуживания)
-- ============================================
-- Удаляет сессии старше 30 дней в состоянии DONE/EXPIRED

DELETE FROM sessions
WHERE state IN ('DONE', 'EXPIRED')
  AND updated_at < NOW() - INTERVAL '30 days';
