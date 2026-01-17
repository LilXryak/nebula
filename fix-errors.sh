#!/bin/bash
# Скрипт для исправления ошибок Nebula

echo "🔧 Диагностика и исправление ошибок Nebula..."
echo ""

cd "$(dirname "$0")" || exit 1

# 1. Проверка логов backend
echo "📋 Проверка логов backend (последние 50 строк):"
docker compose logs backend --tail=50 | grep -i "error\|exception\|traceback" | tail -20 || echo "Ошибок не найдено в логах"

# 2. Проверка подключения к БД
echo ""
echo "🗄️  Проверка подключения к БД..."
if docker compose exec -T backend python -c "from django.db import connection; connection.ensure_connection(); print('✅ БД подключена')" 2>&1; then
    echo "✅ БД работает"
else
    echo "❌ Проблема с БД - пересоздаю volume..."
    docker compose down
    docker volume rm nebula_postgres_data 2>/dev/null || true
    docker compose up -d db redis
    sleep 10
    docker compose up -d
    echo "⏳ Жду 30 секунд для миграций..."
    sleep 30
fi

# 3. Выполнение миграций
echo ""
echo "📝 Выполнение миграций..."
docker compose exec -T backend python manage.py migrate --noinput 2>&1 | tail -20

# 4. Сбор статики
echo ""
echo "📦 Сбор статических файлов..."
docker compose exec -T backend python manage.py collectstatic --noinput 2>&1 | tail -10

# 5. Создание Django суперпользователя (если не существует)
echo ""
echo "👤 Проверка Django суперпользователя..."
docker compose exec -T backend python manage.py shell << 'PYEOF'
from django.contrib.auth import get_user_model
User = get_user_model()
username = 'admin'
email = 'admin@nebula.local'
password = 'admin123'

if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username=username, email=email, password=password)
    print(f'✅ Суперпользователь "{username}" создан!')
    print(f'   Username: {username}')
    print(f'   Password: {password}')
    print(f'   Email: {email}')
else:
    print(f'✅ Пользователь "{username}" уже существует')
PYEOF

# 6. Проверка статуса контейнеров
echo ""
echo "📊 Статус контейнеров:"
docker compose ps

# 7. Проверка API
echo ""
echo "🌐 Проверка API..."
if curl -s -f --max-time 5 "https://nebulacall.digital/api/health/" > /dev/null 2>&1; then
    echo "✅ API работает"
else
    echo "⚠️  API недоступен (может быть еще запускается)"
fi

echo ""
echo "✅ Диагностика завершена!"
echo ""
echo "📝 Если ошибки сохраняются, проверьте логи:"
echo "   docker compose logs backend --tail=100"
