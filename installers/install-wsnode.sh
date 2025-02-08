#!/bin/bash

# Default values
INSTALL_PATH="/opt/wsnode"
PORT="8081"
NODE_ID=$(uuidgen)

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
        --ws-updates-url)
            WS_UPDATES_URL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --node-id)
            NODE_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check required parameters
if [ -z "$WS_UPDATES_URL" ] || [ -z "$API_KEY" ]; then
    echo "Error: --ws-updates-url and --api-key are required"
    exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_PATH"

# Copy required files from repository
FILES=(
    "wsnode/src/server.js"
    "wsnode/package.json"
    "wsnode/Dockerfile"
)

for file in "${FILES[@]}"; do
    dest_path="$INSTALL_PATH/${file#wsnode/}"
    mkdir -p "$(dirname "$dest_path")"
    cp "$(dirname "$0")/../$file" "$dest_path"
done

# Create environment file
cat > "$INSTALL_PATH/.env" << EOF
NODE_ID=$NODE_ID
PORT=$PORT
WS_UPDATES_URL=$WS_UPDATES_URL
API_KEY=$API_KEY
EOF

# Create docker-compose file
cat > "$INSTALL_PATH/docker-compose.yml" << EOF
version: '3.8'

services:
  wsnode:
    build: .
    environment:
      - NODE_ID=$NODE_ID
      - PORT=$PORT
      - WS_UPDATES_URL=$WS_UPDATES_URL
      - API_KEY=$API_KEY
    ports:
      - "${PORT}:${PORT}"
    restart: unless-stopped

networks:
  default:
    name: ws_network
EOF

echo "WSNode installation prepared at: $INSTALL_PATH"
echo "Node ID: $NODE_ID"
echo "Port: $PORT"
echo "To start the service:"
echo "cd $INSTALL_PATH"
echo "docker-compose up -d"

# Set appropriate permissions
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/*.yml "$INSTALL_PATH"/.env
