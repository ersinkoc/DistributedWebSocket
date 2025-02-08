FROM haproxy:2.8-alpine

COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Create directories for SSL certificates and logs
RUN mkdir -p /etc/ssl/private /var/log/haproxy

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8404/health || exit 1
