#!/bin/bash

# WSNode Installation Script
echo "Installing WSNode..."

# Generate random node ID if not provided
if [ -z "$NODE_ID" ]; then
    NODE_ID="wsnode_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
fi

# Default port if not set
PORT=${PORT:-8080}

# Create .env file
cat > .env << EOL
NODE_ID=${NODE_ID}
PORT=${PORT}
WS_UPDATES_URL=${WS_UPDATES_URL:-http://wsupdates.example.com}
API_KEY=${API_KEY:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)}
UPDATE_INTERVAL=30000
EOL

# Install dependencies
echo "Installing Node.js dependencies..."
npm install

# Start the server
echo "Starting WSNode server..."
echo "Node ID: ${NODE_ID}"
echo "Port: ${PORT}"
npm start
