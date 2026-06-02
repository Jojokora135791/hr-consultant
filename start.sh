#!/bin/bash
# Запуск всего окружения HR-ассистента
# Использование: ./start.sh [start|stop|status|import]

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-start}" in

  start)
    echo "=== Запуск HR-ассистент окружения ==="

    # PostgreSQL и Ollama — через brew (стартуют автоматически при загрузке)
    echo ""
    echo "→ PostgreSQL 16..."
    brew services start postgresql@16 2>/dev/null
    sleep 1
    /opt/homebrew/opt/postgresql@16/bin/psql -U olegkluev -d hr_assistant -c "SELECT 'PostgreSQL OK' AS status;" 2>/dev/null || \
      echo "  ⚠️  hr_assistant не отвечает"

    echo ""
    echo "→ Ollama..."
    brew services start ollama 2>/dev/null
    sleep 2
    curl -s http://localhost:11434/api/tags | python3 -c "
import json,sys
d=json.load(sys.stdin)
models=[m['name'] for m in d.get('models',[])]
print('  Модели:', ', '.join(models) if models else 'нет')
qwen='qwen2.5:7b' in ' '.join(models)
print('  qwen2.5:7b:', '✅ OK' if qwen else '⚠️  не найдена — запусти: ollama pull qwen2.5:7b')
" 2>/dev/null || echo "  ⚠️  Ollama не отвечает"

    echo ""
    echo "→ n8n..."
    if pgrep -f "n8n start" > /dev/null; then
      echo "  n8n уже запущен"
    else
      echo "  Запускаем n8n в фоне (логи: /tmp/n8n.log)"
      nohup n8n start > /tmp/n8n.log 2>&1 &
      sleep 3
    fi
    curl -s http://localhost:5678/healthz | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print('  ✅ n8n OK —', d.get('status','?'))
except:
  print('  ⚠️  n8n не отвечает, подожди пару секунд')
" 2>/dev/null

    echo ""
    echo "=== Всё запущено ==="
    echo "  n8n:       http://localhost:5678"
    echo "  Ollama:    http://localhost:11434"
    echo "  PostgreSQL: localhost:5432 / hr_assistant"
    echo ""
    echo "Следующий шаг: открыть n8n и найти workflow '00: HR-ассистент — точка входа'"
    ;;

  stop)
    echo "=== Остановка ==="
    pkill -f "n8n start" 2>/dev/null && echo "  n8n остановлен" || echo "  n8n не был запущен"
    # Ollama и PostgreSQL не останавливаем — они системные сервисы
    echo "  (Ollama и PostgreSQL оставлены — системные сервисы)"
    ;;

  status)
    echo "=== Статус сервисов ==="
    echo ""

    echo "PostgreSQL:"
    /opt/homebrew/opt/postgresql@16/bin/psql -U olegkluev -d hr_assistant -c "\
      SELECT 'sessions: ' || COUNT(*) FROM sessions
      UNION ALL
      SELECT 'messages: ' || COUNT(*) FROM messages;" 2>/dev/null || echo "  ❌ недоступен"

    echo ""
    echo "Ollama:"
    curl -s http://localhost:11434/api/tags | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d.get('models',[]): print(' ', m['name'])
" 2>/dev/null || echo "  ❌ недоступен"

    echo ""
    echo "n8n:"
    if pgrep -f "n8n start" > /dev/null; then
      echo "  ✅ запущен → http://localhost:5678"
      import json,sys
      curl -s http://localhost:5678/rest/workflows 2>/dev/null | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  wfs = d.get('data',[]) if isinstance(d,dict) else []
  hr=[w for w in wfs if w.get('id','').startswith('HR-')]
  print(f'  HR-workflows в n8n: {len(hr)}/7')
except: pass
" 2>/dev/null
    else
      echo "  ❌ не запущен (запусти: ./start.sh)"
    fi
    ;;

  import)
    echo "=== Импорт workflow в n8n ==="
    WF_DIR="$PROJECT_DIR/n8n/workflows"
    for f in \
      lib/lib_rag_context.json \
      lib/lib_session.json \
      lib/lib_llm_call.json \
      lib/lib_check_dates.json \
      lib/lib_build_sz.json \
      scenarios/sc1_progul_ochny.json \
      00_router.json
    do
      echo -n "  → $f ... "
      n8n import:workflow --input="$WF_DIR/$f" 2>&1 | grep -v "Error tracking"
    done
    echo "Готово. Проверь n8n: http://localhost:5678"
    ;;

  *)
    echo "Использование: $0 [start|stop|status|import]"
    echo "  start   — запустить всё окружение"
    echo "  stop    — остановить n8n"
    echo "  status  — проверить статус"
    echo "  import  — переимпортировать все workflow"
    ;;
esac
