#!/bin/sh
# Runs from the official NGINX image's /docker-entrypoint.d/ hook before nginx starts.
# Creates a self-signed certificate for the lab unless one already exists for the same SAN.
# To use a real certificate, place tls.crt and tls.key in the tls-certs volume and remove san.txt.
set -eu
CERT_DIR=/etc/nginx/certs
SAN=${TLS_SAN:-DNS:localhost,IP:127.0.0.1}

if [ -s "$CERT_DIR/tls.crt" ] && [ -s "$CERT_DIR/tls.key" ]; then
  if [ ! -f "$CERT_DIR/san.txt" ] || [ "$(cat "$CERT_DIR/san.txt")" = "$SAN" ]; then
    echo "15-self-signed-cert: using existing certificate"
    exit 0
  fi
  echo "15-self-signed-cert: SAN changed to $SAN, regenerating"
fi

umask 077
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 30 \
  -subj "/CN=taskboard-lab" -addext "subjectAltName=$SAN" \
  -keyout "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.crt" 2>/dev/null
printf '%s' "$SAN" > "$CERT_DIR/san.txt"
echo "15-self-signed-cert: generated certificate for $SAN (valid 30 days)"
