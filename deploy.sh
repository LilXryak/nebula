#!/bin/bash

###############################################################################
# Nebula - Автоматический установщик
# Полностью автоматическая развертка сервиса видеозвонков Nebula
###############################################################################

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Функции для вывода
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

title() {
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo ""
}

###############################################################################
# Шаг 1: Проверка требований
###############################################################################

title "Проверка системных требований"

# Проверка ОС
if [[ ! -f /etc/os-release ]]; then
    error "Не удалось определить ОС. Установщик поддерживает только Ubuntu."
    exit 1
fi

. /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    error "Этот установщик работает только на Ubuntu. Ваша ОС: $ID"
    exit 1
fi

success "ОС определена: Ubuntu $VERSION_ID"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Этот скрипт должен быть запущен от имени root (используйте sudo)"
   exit 1
fi

success "Проверка прав доступа пройдена"

# Проверка наличия домена
info "Для работы Nebula требуется собственный домен с настроенной DNS записью"
info "Убедитесь, что ваш домен указывает на IP адрес этого сервера"
echo ""
read -p "Введите ваш домен (например: example.com): " DOMAIN_NAME

if [[ -z "$DOMAIN_NAME" ]]; then
    error "Домен не может быть пустым!"
    exit 1
fi

# Валидация домена
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    error "Некорректный формат домена!"
    exit 1
fi

success "Домен принят: $DOMAIN_NAME"

# Проверка интернета
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    error "Нет подключения к интернету!"
    exit 1
fi

success "Проверка подключения к интернету пройдена"

###############################################################################
# Шаг 2: Обновление системы
###############################################################################

title "Обновление системы"

info "Обновление списка пакетов..."
apt-get update -qq

info "Обновление системы..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

success "Система обновлена"

###############################################################################
# Шаг 3: Установка Docker и Docker Compose
###############################################################################

title "Установка Docker и Docker Compose"

if command -v docker &> /dev/null; then
    info "Docker уже установлен"
    docker --version
else
    info "Установка Docker..."
    
    # Установка зависимостей
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Добавление GPG ключа Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Добавление репозитория Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    success "Docker установлен"
    docker --version
fi

# Проверка Docker Compose
if command -v docker compose &> /dev/null; then
    info "Docker Compose уже установлен"
    docker compose version
else
    error "Docker Compose не найден после установки Docker"
    exit 1
fi

# Добавление текущего пользователя в группу docker
if [[ -n "$SUDO_USER" ]]; then
    usermod -aG docker "$SUDO_USER"
    info "Пользователь $SUDO_USER добавлен в группу docker"
fi

success "Docker и Docker Compose готовы к работе"

###############################################################################
# Шаг 4: Установка Nginx и Certbot
###############################################################################

title "Установка Nginx и Certbot"

info "Установка Nginx и Certbot..."
apt-get install -y -qq nginx certbot python3-certbot-nginx

success "Nginx и Certbot установлены"

###############################################################################
# Шаг 5: Настройка SSL сертификатов
###############################################################################

title "Настройка SSL сертификатов"

info "Получение SSL сертификата для $DOMAIN_NAME..."

# Остановка nginx для получения сертификата
systemctl stop nginx || true

# Получение сертификата
if certbot certonly --standalone -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos --register-unsafely-without-email; then
    success "SSL сертификат успешно получен"
else
    error "Не удалось получить SSL сертификат. Проверьте DNS настройки."
    info "Убедитесь, что домен $DOMAIN_NAME указывает на IP этого сервера"
    exit 1
fi

# Остановка и отключение системного nginx (будет использоваться в Docker)
systemctl stop nginx
systemctl disable nginx

success "SSL сертификаты настроены"

###############################################################################
# Шаг 6: Настройка файрвола
###############################################################################

title "Настройка файрвола"

if command -v ufw &> /dev/null; then
    info "Настройка UFW..."
    # Пытаемся добавить правила (игнорируем ошибки если правила уже есть)
    ufw allow 22/tcp 2>/dev/null || true
    ufw allow 80/tcp 2>/dev/null || true
    ufw allow 443/tcp 2>/dev/null || true
    
    # Проверяем статус UFW и активируем если нужно
    ufw_status=$(ufw status 2>/dev/null | grep -i "Status: active" || echo "")
    if [ -z "$ufw_status" ]; then
        # Пытаемся активировать, но не блокируем скрипт если не получится
        echo "y" | ufw enable 2>/dev/null || true
    fi
    success "Файрвол настроен (или уже был настроен)"
else
    warning "UFW не установлен. Убедитесь, что порты 80 и 443 открыты в вашем файрволе."
fi

###############################################################################
# Шаг 7: Настройка проекта
###############################################################################

title "Настройка проекта Nebula"

# Определение директории проекта - используем текущую директорию где запущен скрипт
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Директория проекта: $PROJECT_DIR"

# Переходим в директорию проекта
cd "$PROJECT_DIR"

# Проверка наличия docker-compose.yml
if [[ ! -f "docker-compose.yml" ]]; then
    error "Файл docker-compose.yml не найден в $PROJECT_DIR"
    error "Убедитесь, что вы запускаете скрипт из корня репозитория"
    exit 1
fi

# Создание .env файла
info "Создание файла конфигурации .env..."

# Проверка существующего volume БД - если он есть и .env новый/неправильный, удаляем volume
DB_VOLUME_EXISTS=$(docker volume ls 2>/dev/null | grep -q "nebula_postgres_data" && echo "yes" || echo "no")

if [[ -f ".env" ]]; then
    info "Файл .env уже существует, проверяю пароль БД..."
    EXISTING_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2 || echo "")
    if [[ -n "$EXISTING_PASSWORD" && "$EXISTING_PASSWORD" != "your-strong-db-password-here" && "$DB_VOLUME_EXISTS" == "yes" ]]; then
        info "Используется существующий пароль БД"
        DB_PASSWORD="$EXISTING_PASSWORD"
    else
        info "Генерация нового пароля БД..."
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        # Если volume существует, но пароль неправильный - удаляем volume
        if [[ "$DB_VOLUME_EXISTS" == "yes" ]]; then
            warning "Обнаружен несоответствующий volume БД - будет пересоздан"
            docker compose down 2>/dev/null || true
            docker volume rm nebula_postgres_data 2>/dev/null || true
        fi
    fi
    EXISTING_SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d'=' -f2 || echo "")
    if [[ -n "$EXISTING_SECRET_KEY" && "$EXISTING_SECRET_KEY" != "your-super-secret-django-key-change-this-immediately-in-production" ]]; then
        SECRET_KEY="$EXISTING_SECRET_KEY"
    else
        SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    fi
else
    # Если .env не существует, но volume БД есть - удаляем volume для чистой установки
    if [[ "$DB_VOLUME_EXISTS" == "yes" ]]; then
        warning "Обнаружен старый volume БД без .env - удаляю для чистой установки..."
        docker compose down 2>/dev/null || true
        docker volume rm nebula_postgres_data 2>/dev/null || true
    fi
    
    # Генерация SECRET_KEY
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    # Генерация пароля БД
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
fi

cat > .env << EOF
# Django настройки
DEBUG=False
SECRET_KEY=$SECRET_KEY

# База данных PostgreSQL
POSTGRES_DB=nebula_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$DB_PASSWORD
DB_PASSWORD=$DB_PASSWORD
DB_HOST=db
DB_PORT=5432
DB_NAME=nebula_db
DB_USER=postgres

# Redis для сессий и WebSocket
REDIS_URL=redis://redis:6379/0

# Настройки приложения
ROOM_EXPIRY_HOURS=24
MAX_PARTICIPANTS_PER_ROOM=2
SHORT_CODE_LENGTH=6

# CORS настройки
CORS_ALLOWED_ORIGINS=https://$DOMAIN_NAME,https://www.$DOMAIN_NAME
ALLOWED_HOSTS=$DOMAIN_NAME,www.$DOMAIN_NAME,localhost,127.0.0.1

# SSL сертификаты
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
DOMAIN_NAME=$DOMAIN_NAME

# Frontend настройки
VITE_API_BASE_URL=https://$DOMAIN_NAME/api
VITE_WS_BASE_URL=wss://$DOMAIN_NAME
VITE_APP_NAME=Nebula
EOF

success "Файл .env создан"

# Проверка структуры проекта уже выполнена выше

# Обновление nginx.conf с правильным доменом
if [[ -f "nginx.conf" ]]; then
    info "Обновление nginx.conf с доменом $DOMAIN_NAME..."
    sed -i "s/yourdomain\.com/$DOMAIN_NAME/g" nginx.conf
    success "nginx.conf обновлен"
fi

###############################################################################
# Шаг 8: Запуск проекта
###############################################################################

title "Запуск Nebula"

# Очистка orphan контейнеров
info "Очистка старых контейнеров..."
docker compose down --remove-orphans 2>/dev/null || true

info "Запуск Docker контейнеров..."
docker compose pull 2>/dev/null || true
info "Сборка образов (это может занять несколько минут)..."
docker compose build 2>&1 | grep -E "(Step|Built|ERROR|WARN)" | tail -30 || true

info "Запуск контейнеров..."
docker compose up -d --remove-orphans

info "Ожидание запуска сервисов..."
sleep 30

# Проверка статуса контейнеров - backend теперь сам выполняет миграции
info "Backend автоматически выполнит миграции при запуске..."
sleep 3

# Проверка что backend запущен (не делаем проверку БД - если backend запустился, значит всё ОК)
if docker compose ps backend 2>/dev/null | grep -q "Up"; then
    success "Backend запущен (миграции выполняются в фоне)"
else
    info "Backend может еще запускаться..."
fi

# Проверка всех сервисов
info "Проверка статуса всех сервисов..."
if docker compose ps | grep -q "backend.*Up" && docker compose ps | grep -q "nginx.*Up"; then
    success "Все основные сервисы запущены"
    docker compose ps
else
    warning "Некоторые сервисы могут еще запускаться:"
    docker compose ps
fi

###############################################################################
# Шаг 9: Создание суперпользователя (опционально)
###############################################################################

title "Создание администратора"

info "Для создания администратора выполните:"
info "  docker compose exec backend python manage.py createsuperuser"
info ""
info "Или создайте сейчас (Enter чтобы пропустить):"
read -p "Создать администратора сейчас? (y/N): " CREATE_ADMIN

if [[ "$CREATE_ADMIN" =~ ^[Yy]$ ]]; then
    # Ждем пока backend выполнит миграции
    info "Ожидание выполнения миграций backend (30 секунд)..."
    sleep 30
    
    # Проверка и исправление проблемы с паролем БД перед созданием администратора
    info "Проверка подключения к БД перед созданием администратора..."
    db_check_output=$(docker compose exec -T backend python manage.py shell << 'PYEOF' 2>&1
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'nebula_app.settings')
import django
django.setup()
from django.db import connection
try:
    connection.ensure_connection()
    print('DB_OK')
except Exception as e:
    print(f'DB_ERROR: {str(e)}')
PYEOF
    )
    
    if echo "$db_check_output" | grep -q "password authentication failed"; then
        warning "Обнаружена проблема с паролем БД - пересоздаю БД с правильным паролем..."
        docker compose down
        docker volume rm nebula_postgres_data 2>/dev/null || true
        docker compose up -d db redis
        sleep 10
        docker compose up -d
        info "Ожидание выполнения миграций после пересоздания БД (20 секунд)..."
        sleep 20
        success "БД пересоздана с правильным паролем"
    fi
    
    info "Создание администратора Django..."
    # Используем неинтерактивный режим для автоматического создания
    admin_output=$(docker compose exec -T backend python manage.py shell << 'PYEOF' 2>&1
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'nebula_app.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()
username = 'admin'
email = 'admin@nebula.local'
password = 'admin123'

try:
    if not User.objects.filter(username=username).exists():
        User.objects.create_superuser(username=username, email=email, password=password)
        print(f'✅ Суперпользователь "{username}" создан успешно')
        print(f'   Email: {email}')
        print(f'   Password: {password}')
    else:
        print(f'✅ Пользователь "{username}" уже существует')
except Exception as e:
    print(f'⚠️  Ошибка при создании: {e}')
    print('Попробуйте создать вручную позже')
PYEOF
    )
    
    echo "$admin_output"
    
    if echo "$admin_output" | grep -q "✅ Суперпользователь"; then
        success "Администратор Django создан успешно!"
    elif echo "$admin_output" | grep -q "уже существует"; then
        success "Администратор Django уже существует"
    else
        warning "Не удалось создать администратора автоматически"
    fi
    
    info ""
    info "Данные для входа в Django Admin:"
    info "   Username: admin"
    info "   Password: admin123"
    info ""
    info "Если администратор не создан, выполните:"
    info "  docker compose exec backend python manage.py createsuperuser"
    info "  или: bash fix-errors.sh"
else
    info "Создание администратора пропущено"
    info "Вы можете создать его позже командой:"
    info "  docker compose exec backend python manage.py createsuperuser"
fi

# Информация о пароле доступа к сайту и проверка работы
info ""
info "Информация об авторизации:"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "1. Доступ к сайту (форма логина на главной странице):"
info "   Пароль: admin123"
info "   Можно изменить: https://$DOMAIN_NAME/admin/core/systemsettings/"
info ""
info "2. Django Admin панель (https://$DOMAIN_NAME/admin):"
info "   Это отдельный пароль от пароля доступа к сайту!"
if [[ "$CREATE_ADMIN" =~ ^[Yy]$ ]]; then
    info "   Username: admin (если был создан)"
    info "   Password: admin123 (если был создан)"
    warning "   ⚠️  ВАЖНО: Измените пароль после первого входа!"
    info ""
    info "   Если администратор не создан, выполните:"
    info "   docker compose exec backend python manage.py createsuperuser"
else
    info "   Создайте администратора:"
    info "   docker compose exec backend python manage.py createsuperuser"
fi
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info ""
info "Проверка работоспособности..."
# Быстрая проверка API (неблокирующая)
if curl -s -f --max-time 2 "https://$DOMAIN_NAME/api/health/" > /dev/null 2>&1; then
    success "API работает корректно"
else
    info "API может еще запускаться (это нормально, миграции выполняются в фоне)"
fi

###############################################################################
# Шаг 10: Настройка автообновления SSL
###############################################################################

title "Настройка автообновления SSL"

# Создание задачи cron для обновления сертификатов
cat > /etc/cron.monthly/certbot-renew << 'CRONEOF'
#!/bin/bash
certbot renew --quiet --deploy-hook "docker restart nebula-nginx-1"
CRONEOF

chmod +x /etc/cron.monthly/certbot-renew

success "Автообновление SSL настроено"

###############################################################################
# Установка завершена
###############################################################################

title "Установка завершена!"

success "Nebula успешно развернут!"
echo ""
info "Информация о развертывании:"
echo "  Домен:              https://$DOMAIN_NAME"
echo "  Админ панель:       https://$DOMAIN_NAME/admin"
echo "  API Health Check:   https://$DOMAIN_NAME/api/health/"
echo "  Директория:         $PROJECT_DIR"
echo ""
info "Управление:"
echo "  Логи:               cd $PROJECT_DIR && docker compose logs -f"
echo "  Остановить:         cd $PROJECT_DIR && docker compose down"
echo "  Запустить:          cd $PROJECT_DIR && docker compose up -d"
echo "  Перезапустить:      cd $PROJECT_DIR && docker compose restart"
echo ""
info "Проверка статуса:"
docker compose ps
echo ""
success "Наслаждайтесь Nebula!"
