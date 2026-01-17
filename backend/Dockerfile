FROM python:3.11-slim

WORKDIR /app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    gettext \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Копирование и установка Python зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Дополнительно устанавливаем daphne если его нет в requirements.txt
RUN pip install daphne

# Создание непривилегированного пользователя с определенным UID/GID
RUN groupadd -r appuser -g 1000 && useradd -r -g appuser -u 1000 appuser

# Копирование исходного кода
COPY . .

# Создание директорий для статических файлов, медиа и логов с правильными правами
RUN mkdir -p /app/staticfiles /app/media /app/logs && \
    chown -R appuser:appuser /app && \
    chmod -R 755 /app/logs

# Копирование startup скрипта
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Переключение на непривилегированного пользователя
USER appuser

EXPOSE 8000

# Используем startup скрипт который автоматически выполняет миграции
CMD ["/app/start.sh"]
