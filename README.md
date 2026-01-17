# 🌌 Nebula

Безопасное приложение для видеозвонков без регистрации с поддержкой WebRTC, построенное на Django и Vue.js.

## ✨ Особенности

- **🔐 Безопасность**: Аутентификация по паролю, CSRF защита
- **📱 Адаптивность**: Полная поддержка мобильных устройств
- **🎯 Простота**: Создание комнат одним кликом
- **⚡ WebRTC**: Прямое P2P соединение для минимальной задержки
- **🌙 Темная тема**: Автоматическое переключение по системным настройкам
- **📊 Мониторинг**: Статистика качества соединения в реальном времени
- **🔄 PWA**: Поддержка Progressive Web App для установки на устройства

## 🏗️ Архитектура

```
📦 Nebula
├── 🐍 Backend (Django)
│   ├── REST API
│   ├── WebSocket (Channels)
│   ├── Redis (кэширование и сессии)
│   └── PostgreSQL (база данных)
├── 🖥️ Frontend (Vue.js 3)
│   ├── Composition API
│   ├── Pinia (управление состоянием)
│   ├── TailwindCSS (стили)
│   └── WebRTC (видеосвязь)
└── 🐳 Docker
    ├── Nginx (прокси)
    ├── PostgreSQL
    ├── Redis
    └── SSL/HTTPS
```

## 🚀 Быстрый старт

### Автоматическая установка (Рекомендуется)

Для автоматической установки Nebula на ваш Ubuntu сервер используйте скрипт `deploy.sh`:

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/LilXryak/nebula.git
cd nebula

# 2. Запустите установщик (укажите свой домен при запросе)
sudo bash deploy.sh
```

**Требования:**
- Ubuntu 20.04+ сервер с правами root (sudo)
- Собственный домен с настроенной DNS записью (A запись на IP сервера)

**Установщик автоматически:**
- ✅ Проверит системные требования
- ✅ Установит Docker, Docker Compose, Nginx, Certbot
- ✅ Настроит SSL сертификаты Let's Encrypt
- ✅ Создаст конфигурационные файлы (.env, nginx.conf)
- ✅ Развернет приложение (docker compose)
- ✅ Настроит файрвол (UFW)
- ✅ Настроит автообновление SSL

**После установки:**
- Nebula будет доступен по вашему домену
- **Пароль доступа к сайту:** `admin123` (можно изменить в админ-панели)
- **Django Admin:** Если вы выбрали создание администратора при установке, используйте username: `admin`, password: `admin123`
- Если администратор не был создан: `docker compose exec backend python manage.py createsuperuser`

### Локальная разработка

1. **Клонирование репозитория**
```bash
git clone https://github.com/LilXryak/nebula.git
cd nebula
```

2. **Запуск с Docker Compose**
```bash
# Создайте .env файл из примера
cp env.example .env

# Запустите контейнеры
docker-compose up --build
```

3. **Создайте суперпользователя**
```bash
docker-compose exec backend python manage.py createsuperuser
```

4. **Доступ к приложению**
- Frontend: http://localhost
- Backend API: http://localhost/api
- Admin панель: http://localhost/admin

## 📋 Системные требования

- **Сервер**: Ubuntu 20.04+ или аналогичная Linux-система
- **RAM**: Минимум 2GB, рекомендуется 4GB+
- **CPU**: 2+ ядра
- **Диск**: 20GB+ свободного места
- **Сеть**: Статический IP или домен для SSL

## 🛠️ Развертывание на продакшене

> **💡 Совет**: Для быстрой установки используйте автоматический установщик `deploy.sh` (см. раздел "Быстрый старт").

### Ручная установка

Если вы предпочитаете установку вручную, следуйте инструкциям ниже:

### 1. Подготовка сервера

Обновите систему и установите необходимые пакеты:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
```

### 2. Установка Docker

**Добавление ключей и репозитория Docker:**
```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

**Установка Docker и компонентов:**
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Добавление пользователя в группу Docker:**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Установка Docker Compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 4. Установка Nginx и Certbot

```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx
```

### 5. Настройка SSL-сертификатов

**Получение сертификатов Let's Encrypt:**
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

**Остановка системного Nginx после получения сертификатов:**
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
```

### 6. Конфигурация проекта

**Создайте файл окружения:**
```bash
cp env.example .env
```

**Настройте переменные в `.env`:**
```bash
# Основные настройки
DEBUG=False
SECRET_KEY=your-super-secret-django-key-here
DOMAIN_NAME=yourdomain.com

# База данных
POSTGRES_PASSWORD=strong-database-password

# Пути к SSL сертификатам
SSL_CERT_PATH=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/yourdomain.com/privkey.pem

# Домены
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

**Обновите nginx.conf:**
Замените `yourdomain.com` на ваш реальный домен в файле `nginx.conf`.

### 7. Запуск приложения

**Сборка и запуск контейнеров:**
```bash
docker-compose up --build -d
```

**Создание суперпользователя:**
```bash
docker-compose exec backend python manage.py createsuperuser
```

**Проверка статуса контейнеров:**
```bash
docker-compose ps
```

### 8. Проверка работоспособности

- **Frontend**: https://yourdomain.com
- **Backend API**: https://yourdomain.com/api/health/
- **Admin панель**: https://yourdomain.com/admin/
- **WebSocket**: wss://yourdomain.com/ws/

## 🔧 Управление проектом

### Основные команды

```bash
# Просмотр логов
docker-compose logs -f

# Перезапуск сервисов
docker-compose restart

# Остановка проекта
docker-compose down

# Полная очистка (с удалением данных)
docker-compose down -v --remove-orphans
```

### Обновление проекта

```bash
# Получение обновлений
git pull origin main

# Пересборка и перезапуск
docker-compose up --build -d

# Применение миграций (если есть)
docker-compose exec backend python manage.py migrate
```

### Резервное копирование

```bash
# Создание бэкапа базы данных
docker-compose exec db pg_dump -U postgres nebula_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление из бэкапа
docker-compose exec -T db psql -U postgres nebula_db < backup_file.sql
```

## 📊 Мониторинг

### Health Check эндпоинты

- **Общее состояние**: `/api/health/`
- **Метрики системы**: `/api/metrics/` (только для админов)

### Логи

```bash
# Все логи
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f backend
docker-compose logs -f nginx
docker-compose logs -f db
```

## 🛡️ Безопасность

### Рекомендации по безопасности

1. **Измените пароль по умолчанию** в админ-панели
2. **Используйте сложные пароли** для базы данных
3. **Регулярно обновляйте** SSL-сертификаты
4. **Настройте файрвол** для ограничения доступа
5. **Мониторьте логи** на предмет подозрительной активности

### Настройка файрвола (UFW)

```bash
# Разрешить SSH, HTTP и HTTPS
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## 🔧 Разработка

### Структура проекта

```
📁 nebula/
├── 📁 backend/                 # Django backend
│   ├── 📁 apps/               # Django приложения
│   │   ├── 📁 authentication/ # Система аутентификации
│   │   ├── 📁 core/          # Основные модели и утилиты
│   │   └── 📁 rooms/         # Управление комнатами
│   ├── 📁 nebula_app/        # Основные настройки Django
│   └── 🐳 Dockerfile
├── 📁 nebula-frontend/        # Vue.js frontend
│   ├── 📁 src/
│   │   ├── 📁 components/    # Vue компоненты
│   │   ├── 📁 stores/        # Pinia хранилища
│   │   ├── 📁 services/      # API и утилиты
│   │   └── 📁 router/        # Vue Router
│   └── 🐳 Dockerfile
├── 🐳 docker-compose.yml     # Docker Compose конфигурация
├── 📄 nginx.conf             # Nginx конфигурация
└── 📄 .env.example           # Пример переменных окружения
```

### Локальная разработка

```bash
# Backend (Python/Django)
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py runserver

# Frontend (Vue.js)
cd nebula-frontend
npm install
npm run dev
```
