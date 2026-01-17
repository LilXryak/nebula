#!/bin/bash
# Автоматический startup скрипт для backend
# Выполняет миграции и сбор статики при необходимости, затем запускает сервер

echo "🚀 Starting Nebula backend..."

# Ждем пока БД будет готова
echo "⏳ Waiting for database..."
for i in {1..30}; do
  if python manage.py showmigrations --plan >/dev/null 2>&1; then
    echo "✅ Database is ready!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "⚠️  Database connection timeout, but continuing..."
  else
    sleep 1
  fi
done

# Выполняем миграции (если нужно)
echo "🗄️  Checking database migrations..."
MIGRATION_OUTPUT=$(python manage.py showmigrations --plan 2>&1)
MIGRATION_STATUS=$?

if [ $MIGRATION_STATUS -eq 0 ]; then
  if echo "$MIGRATION_OUTPUT" | grep -q "\[ \]"; then
    echo "📝 Running pending migrations..."
    python manage.py migrate --noinput || {
      echo "⚠️  Migration error occurred, but continuing..."
    }
  else
    echo "✅ All migrations are up to date"
  fi
else
  echo "⚠️  Could not check migrations (DB may not be ready yet), continuing..."
fi

# Собираем статику (всегда, чтобы быть уверенными)
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput || echo "⚠️  Static files collection had issues, but continuing..."

# Запускаем сервер
echo "🌐 Starting Daphne server..."
exec daphne -b 0.0.0.0 -p 8000 nebula_app.asgi:application --access-log - --verbosity 2
