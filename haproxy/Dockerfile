FROM haproxy:2.8-alpine

USER root

# Create directories and generate SSL certificate in a single layer
RUN set -ex \
    && mkdir -p /etc/ssl/private /var/log/haproxy /usr/local/etc/haproxy/certs \
    && apk add --no-cache openssl \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -keyout /usr/local/etc/haproxy/certs/cert.key \
       -out /usr/local/etc/haproxy/certs/cert.crt \
       -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
    && cat /usr/local/etc/haproxy/certs/cert.crt /usr/local/etc/haproxy/certs/cert.key \
       > /usr/local/etc/haproxy/certs/cert.pem \
    && chmod 600 /usr/local/etc/haproxy/certs/cert.* \
    && chown -R haproxy:haproxy /etc/ssl/private /var/log/haproxy /usr/local/etc/haproxy/certs \
    && apk del openssl

# Copy config and set permissions
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
RUN chmod 644 /usr/local/etc/haproxy/haproxy.cfg \
    && chown haproxy:haproxy /usr/local/etc/haproxy/haproxy.cfg

USER haproxy

HEALTHCHECK --interval=30s --timeout=3s CMD nc -z localhost 8404 || exit 1

EXPOSE 8080 8443

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
