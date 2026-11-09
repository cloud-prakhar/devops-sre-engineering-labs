# TLS-terminating reverse proxy for the Taskboard stack.
FROM nginxinc/nginx-unprivileged:1.31-alpine
USER root
# openssl generates the lab's self-signed certificate at start-up (see 15-self-signed-cert.sh).
RUN apk add --no-cache openssl \
 && install -d -o nginx -g nginx -m 0750 /etc/nginx/certs
COPY --chmod=0755 15-self-signed-cert.sh /docker-entrypoint.d/15-self-signed-cert.sh
COPY nginx.conf /etc/nginx/conf.d/default.conf
USER 101
EXPOSE 8080 8443
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
