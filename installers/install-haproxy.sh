#!/bin/bash

# Default values
INSTALL_PATH="/opt/haproxy"
HTTP_PORT="8080"
HTTPS_PORT="8443"
SSL_CERT_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        --https-port)
            HTTPS_PORT="$2"
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
        --ssl-cert)
            SSL_CERT_PATH="$2"
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
    "haproxy/haproxy.cfg"
    "haproxy/Dockerfile"
    "haproxy/update_backends.py"
)

for file in "${FILES[@]}"; do
    dest_path="$INSTALL_PATH/${file#haproxy/}"
    mkdir -p "$(dirname "$dest_path")"
    cp "$(dirname "$0")/../$file" "$dest_path"
done

# Create environment file
cat > "$INSTALL_PATH/.env" << EOF
WS_UPDATES_URL=$WS_UPDATES_URL
API_KEY=$API_KEY
EOF

# Create docker-compose file
SSL_VOLUME=""
if [ -n "$SSL_CERT_PATH" ]; then
    SSL_VOLUME="      - ${SSL_CERT_PATH}:/usr/local/etc/haproxy/cert.pem:ro"
fi

cat > "$INSTALL_PATH/docker-compose.yml" << EOF
version: '3.8'

services:
  haproxy:
    build: .
    ports:
      - "${HTTP_PORT}:8080"
      - "${HTTPS_PORT}:8443"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
${SSL_VOLUME:+      $SSL_VOLUME}
    environment:
      - WS_UPDATES_URL=$WS_UPDATES_URL
      - API_KEY=$API_KEY
    restart: unless-stopped

  updater:
    build: 
      context: .
      dockerfile: Dockerfile.updater
    environment:
      - WS_UPDATES_URL=$WS_UPDATES_URL
      - API_KEY=$API_KEY
      - UPDATE_INTERVAL=30
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

networks:
  default:
    name: ws_network
EOF

echo "HAProxy installation prepared at: $INSTALL_PATH"
echo "HTTP Port: $HTTP_PORT"
echo "HTTPS Port: $HTTPS_PORT"
echo "To start the service:"
echo "cd $INSTALL_PATH"
echo "docker-compose up -d"

# Set appropriate permissions
chmod 755 "$INSTALL_PATH"
chmod 644 "$INSTALL_PATH"/*.yml "$INSTALL_PATH"/.env
