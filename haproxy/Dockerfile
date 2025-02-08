FROM haproxy:2.8-alpine

# Install required packages
RUN apk add --no-cache \
    python3 \
    py3-pip \
    openssl \
    curl

# Create required directories with proper permissions
RUN mkdir -p /etc/ssl/private \
    && mkdir -p /var/log/haproxy \
    && mkdir -p /usr/local/etc/haproxy/certs \
    && chown -R haproxy:haproxy /etc/ssl/private \
    && chown -R haproxy:haproxy /var/log/haproxy \
    && chown -R haproxy:haproxy /usr/local/etc/haproxy/certs

# Create self-signed certificate for development
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /usr/local/etc/haproxy/certs/cert.key \
    -out /usr/local/etc/haproxy/certs/cert.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
    && cat /usr/local/etc/haproxy/certs/cert.crt \
        /usr/local/etc/haproxy/certs/cert.key \
        > /usr/local/etc/haproxy/certs/cert.pem \
    && chown -R haproxy:haproxy /usr/local/etc/haproxy/certs

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
RUN chown haproxy:haproxy /usr/local/etc/haproxy/haproxy.cfg

# Switch to haproxy user
USER haproxy

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8404/health || exit 1

EXPOSE 8080 8443

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
