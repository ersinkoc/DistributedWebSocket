#!/bin/bash

# HAProxy Installation Script
echo "Installing HAProxy and dependencies..."

# Install HAProxy if not present
if ! command -v haproxy &> /dev/null; then
    apt-get update
    apt-get install -y haproxy
fi

# Create directories
mkdir -p /etc/haproxy/certs
mkdir -p /var/log/haproxy

# Copy configuration
cp haproxy.cfg /etc/haproxy/haproxy.cfg

# Set up the update script
cp update_backends.sh /usr/local/bin/
chmod +x /usr/local/bin/update_backends.sh

# Set up cron job for backend updates
echo "*/1 * * * * root /usr/local/bin/update_backends.sh" > /etc/cron.d/haproxy-update

# Start HAProxy
systemctl enable haproxy
systemctl restart haproxy

echo "HAProxy installation complete!"
