# ==============================================================================
# Stage 1: Build & Dependency Installation
# ==============================================================================
FROM composer:2 AS builder

WORKDIR /var/www/html

# Copy only dependency definitions first to maximize Docker layer caching
COPY composer.json composer.lock ./

# Install production dependencies (optimizing autoloaders)
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist

# ==============================================================================
# Stage 2: Production PHP-FPM Runtime
# ==============================================================================
FROM php:8.3-fpm-alpine

# Set working directory matching Nginx root
WORKDIR /var/www/html

# Install recommended system dependencies and standard PHP extension
RUN apk add --no-cache \
    libzip-dev \
    unzip \
    && docker-php-ext-install opcache

# Copy and use official production php.ini settings
COPY setup/php/php.ini /usr/local/etc/php/php.ini
# RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

##### move fpm configuration files #######
# fpm master process configuration file
# COPY setup/fpm/php-fpm.conf /usr/local/etc/php-fpm.conf

# fpm pool children configuration file 
COPY setup/fpm/www.conf /usr/local/etc/php-fpm.d/www.conf

# Configure Opcache for production-level response performance
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini


# Copy vendors from builder stage
COPY --from=builder /var/www/html/vendor ./vendor

# Copy application files
COPY public/ ./public/

# Set ownership to standard web user for security (avoid running as root)
RUN chown -R www-data:www-data /var/www/html

# Run container as the secure www-data user
USER www-data

EXPOSE 9000

CMD ["php-fpm"]
