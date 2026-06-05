#!/bin/bash
# Скрипт импорта всех workflow в n8n и обновления ссылок на sub-workflow ID
# Запускать из папки n8n/workflows/

N8N_URL="http://localhost:5678"
WORKFLOWS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== HR-ассистент: установка workflow в n8n ==="
echo "n8n URL: $N8N_URL"
echo "Папка: $WORKFLOWS_DIR"
echo ""

# Функция импорта одного workflow
import_workflow() {
  local FILE="$1"
  local LABEL="$2"
  local RESPONSE=$(curl -s -X POST "$N8N_URL/rest/workflows" \
    -H "Content-Type: application/json" \
    -d "@$FILE")
  local ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('id','ERROR'))" 2>/dev/null)
  echo "  ✅ $LABEL → ID: $ID"
  echo "$ID"
}

# 1. Импортируем lib-воркфлоу (без зависимостей от других)
echo "--- Шаг 1: Библиотечные workflow ---"
RAG_ID=$(import_workflow "$WORKFLOWS_DIR/lib/lib_rag_context.json" "LIB: RAG-контекст")
LLM_ID=$(import_workflow "$WORKFLOWS_DIR/lib/lib_llm_call.json" "LIB: вызов LLM")
SES_ID=$(import_workflow "$WORKFLOWS_DIR/lib/lib_session.json" "LIB: сессия")
DATES_ID=$(import_workflow "$WORKFLOWS_DIR/lib/lib_check_dates.json" "LIB: проверка сроков")
SZ_ID=$(import_workflow "$WORKFLOWS_DIR/lib/lib_build_sz.json" "LIB: составить СЗ")
echo ""

# 2. Патчим lib_llm_call — вставляем ID RAG-workflow
echo "--- Шаг 2: Патч ссылок на sub-workflow ---"
python3 - <<EOF
import json, re

def patch_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()
    for placeholder, real_id in replacements.items():
        content = content.replace(placeholder, str(real_id))
    # Импортируем уже пропатченный JSON напрямую через API
    import urllib.request
    req = urllib.request.Request(
        'http://localhost:5678/rest/workflows',
        data=content.encode(),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read())
        new_id = data.get('data', {}).get('id', 'ERROR')
        print(f'  ✅ {path} (переимпорт с правильными ID) → {new_id}')
        return new_id
    except Exception as e:
        print(f'  ❌ Ошибка: {e}')
        return None

rag_id = '$RAG_ID'
llm_id = '$LLM_ID'
ses_id = '$SES_ID'
dates_id = '$DATES_ID'
sz_id = '$SZ_ID'

# Патч lib_llm_call (ссылка на RAG)
new_llm_id = patch_file('$WORKFLOWS_DIR/lib/lib_llm_call.json', {
    'REPLACE_WITH_LIB_RAG_CONTEXT_ID': rag_id
})
if new_llm_id:
    llm_id = new_llm_id

# Патч lib_build_sz (ссылка на LLM)
patch_file('$WORKFLOWS_DIR/lib/lib_build_sz.json', {
    'REPLACE_WITH_LIB_LLM_CALL_ID': llm_id
})

print(f'\n  Используемые ID:')
print(f'  RAG: {rag_id}')
print(f'  LLM: {llm_id}')
print(f'  Session: {ses_id}')
print(f'  CheckDates: {dates_id}')
print(f'  BuildSZ: {sz_id}')

# Сохраняем ID в файл для следующего шага
with open('/tmp/hr_workflow_ids.json', 'w') as f:
    json.dump({'rag': rag_id, 'llm': llm_id, 'session': ses_id, 'check_dates': dates_id, 'build_sz': sz_id}, f)
EOF

# 3. Импортируем сценарии (нужно передать все ID)
echo ""
echo "--- Шаг 3: Импорт сценариев ---"
SC1_ID=$(python3 - <<EOF
import json, urllib.request

with open('/tmp/hr_workflow_ids.json') as f:
    ids = json.load(f)

with open('$WORKFLOWS_DIR/scenarios/sc1_progul_ochny.json') as f:
    content = f.read()

for placeholder, real_id in {
    'REPLACE_WITH_LIB_SESSION_ID': ids['session'],
    'REPLACE_WITH_LIB_LLM_CALL_ID': ids['llm'],
    'REPLACE_WITH_LIB_CHECK_DATES_ID': ids['check_dates'],
    'REPLACE_WITH_LIB_BUILD_SZ_ID': ids['build_sz']
}.items():
    content = content.replace(placeholder, str(real_id))

req = urllib.request.Request(
    'http://localhost:5678/rest/workflows',
    data=content.encode(),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
sc1_id = data.get('data', {}).get('id', 'ERROR')
print(sc1_id)
EOF
)
echo "  ✅ Сценарий 1 (прогул очный) → ID: $SC1_ID"

# 4. Импортируем роутер
echo ""
echo "--- Шаг 4: Импорт главного роутера ---"
python3 - <<EOF
import json, urllib.request

with open('/tmp/hr_workflow_ids.json') as f:
    ids = json.load(f)

sc1_id = '$SC1_ID'

with open('$WORKFLOWS_DIR/00_router.json') as f:
    content = f.read()

content = content.replace('REPLACE_WITH_LIB_SESSION_ID', ids['session'])
content = content.replace('REPLACE_WITH_SC1_PROGUL_OCHNY_ID', sc1_id)

req = urllib.request.Request(
    'http://localhost:5678/rest/workflows',
    data=content.encode(),
    headers={'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
router_id = data.get('data', {}).get('id', 'ERROR')
print(f'  ✅ Роутер (00_router) → ID: {router_id}')
EOF

echo ""
echo "=== Установка завершена ==="
echo "Открой n8n: http://localhost:5678"
echo "Найди workflow '00: HR-ассистент — точка входа' и нажми Test Workflow"
