#!/bin/bash

# Default values
INSTALL_PATH="/opt/wsupdates"
PORT="8000"
API_KEY=$(uuidgen)
DB_PATH="/opt/wsupdates/data/ws.db"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create installation directory
mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname "$DB_PATH")"

# Copy required files from repository
FILES=(
    "wsupdates/src/index.php"
    "wsupdates/composer.json"
    "wsupdates/Dockerfile"
)

for file in "${FILES[@]}"; do
    dest_path="$INSTALL_PATH/${file#wsupdates/}"
    mkdir -p "$(dirname "$dest_path")"
    cp "$(dirname "$0")/../$file" "$dest_path"
done

# Create environment file
cat > "$INSTALL_PATH/.env" << EOF
DB_PATH=$DB_PATH
API_KEY=$API_KEY
EOF

# Create docker-compose file
cat > "$INSTALL_PATH/docker-compose.yml" << EOF
version: '3.8'

services:
  wsupdates:
    build: .
    environment:
      - DB_PATH=$DB_PATH
      - API_KEY=$API_KEY
    volumes:
      - ${DB_PATH}:/data/ws.db
    ports:
      - "${PORT}:80"
    restart: unless-stopped

networks:
  default:
    name: ws_network
EOF

echo "WSUpdates installation prepared at: $INSTALL_PATH"
echo "API Key: $API_KEY"
echo "To start the service:"
echo "cd $INSTALL_PATH"
echo "docker-compose up -d"

# Set appropriate permissions
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/*.yml "$INSTALL_PATH"/.env
