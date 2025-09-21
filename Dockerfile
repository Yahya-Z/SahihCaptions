# syntax=docker/dockerfile:1

# --- Builder stage: install PHP dependencies ---
FROM composer:2.7 AS vendor
WORKDIR /app
# Copy only composer files for dependency install
COPY --link composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-scripts --no-progress

# --- Final stage: PHP runtime ---
FROM php:8.2-fpm-alpine AS final

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    libpng \
    libjpeg-turbo \
    libwebp \
    libzip \
    zip \
    unzip \
    bash \
    shadow \
    curl \
    icu-libs \
    oniguruma \
    mysql-client \
    && docker-php-ext-install pdo pdo_mysql zip intl mbstring

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy application code (excluding .env, .git, etc. via .dockerignore)
COPY --link . .

# Copy installed PHP dependencies from builder
COPY --link --from=vendor /app/vendor ./vendor

# Ensure storage and bootstrap/cache are writable
RUN mkdir -p storage/framework storage/logs bootstrap/cache \
    && chown -R appuser:appgroup storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

USER appuser

# Expose port 9000 for PHP-FPM
EXPOSE 9000

# Entrypoint for PHP-FPM
CMD ["php-fpm"]
