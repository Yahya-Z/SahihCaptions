# Use PHP 8.3 with Apache
FROM php:8.3-apache

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libpq-dev \
    zip \
    unzip \
    nodejs \
    npm \
    postgresql-client \
    && docker-php-ext-install pdo_pgsql pgsql mbstring exif pcntl bcmath gd zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Configure Apache document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Add Apache configuration for Laravel
RUN echo '<Directory /var/www/html/public>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' > /etc/apache2/conf-available/laravel.conf \
    && a2enconf laravel

# Copy application code first
COPY . .

# Create required Laravel directories BEFORE installing dependencies
RUN mkdir -p storage/framework/cache/data \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p storage/logs \
    && mkdir -p bootstrap/cache

# Install PHP dependencies (include dev dependencies since Laravel 12 needs them)
RUN composer install --optimize-autoloader --no-interaction

# Generate basic autoloader with package discovery
RUN composer dump-autoload --optimize

# Install Node.js dependencies (including dev dependencies for build)
RUN npm ci

# Build Vue assets (skip if it fails - we can fix this later)
RUN npm run build || echo "Build failed, continuing without assets..."

# Clean up dev dependencies after build
RUN npm prune --omit=dev || echo "Cleanup failed, continuing..."

# Set permissions (create directories first, then set permissions)
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Create .env from .env.example if .env doesn't exist
RUN if [ ! -f .env ]; then cp .env.example .env; fi

# Generate application key and run Laravel setup
RUN php artisan key:generate --no-interaction

# Run package discovery to properly register all packages
RUN php artisan package:discover --ansi

# Clear caches to ensure clean state
RUN php artisan config:clear || echo "Config clear failed, continuing..."
RUN php artisan cache:clear || echo "Cache clear failed, continuing..."

# Expose port 80
EXPOSE 80

# Start Apache
CMD ["apache2-foreground"]