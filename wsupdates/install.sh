#!/bin/bash

# WSUpdates Installation Script
echo "Installing WSUpdates Service..."

# Create necessary directories
mkdir -p database
mkdir -p logs

# Generate API key if not provided
API_KEY=${API_KEY:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)}

# Create .env file
cat > .env << EOL
DB_PATH=database/wsupdates.sqlite
API_KEY=${API_KEY}
APP_ENV=production
DEBUG=false
EOL

# Install composer if not present
if ! command -v composer &> /dev/null; then
    echo "Installing Composer..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    php -r "unlink('composer-setup.php');"
fi

# Install dependencies
echo "Installing PHP dependencies..."
composer install --no-dev

# Set permissions
chmod 755 src
chmod 644 .env
chmod -R 777 database
chmod -R 777 logs

echo "WSUpdates installation complete!"
echo "API Key: ${API_KEY}"
