FROM php:8.1-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_sqlite mbstring exif pcntl

# Install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Set DNS resolvers and install dependencies
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN echo "nameserver 8.8.8.8" > /etc/resolv.conf \
    && echo "nameserver 1.1.1.1" >> /etc/resolv.conf \
    && composer install --no-dev --optimize-autoloader --no-interaction

# Configure Apache
COPY apache.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

# Create data directory with proper permissions
RUN mkdir -p /data \
    && chown -R www-data:www-data /data /var/www/html

# Switch to non-root user
USER www-data

EXPOSE 80

CMD ["apache2-foreground"]
