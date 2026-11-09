#!/usr/bin/env bash
# Verifies the cloud deployment of lab 03 from your laptop.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform curl openssl ssh

IP=$(tf_output "$HERE/../terraform" public_ip)
TARGET="ubuntu@$IP"

info "Edge"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$IP/")
[[ "$code" == "301" ]] && pass "HTTP -> HTTPS redirect" || fail "HTTP returned $code"
curl -fsSk --max-time 5 "https://$IP/" | grep -q '<title>Taskboard</title>' && pass "frontend over HTTPS" || fail "frontend"
[[ $(curl -fsSk --max-time 5 "https://$IP/readyz") == *postgresql* ]] && pass "end-to-end readiness (proxy -> api -> db)" || fail "readyz"
san=$(echo | openssl s_client -connect "$IP:443" 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | tail -n1)
[[ "$san" == *"$IP"* ]] && pass "certificate covers $IP" || fail "certificate SAN: $san"

info "Exposure"
for port in 5432 8000 8080; do
  if timeout 5 bash -c "</dev/tcp/$IP/$port" 2>/dev/null; then fail "port $port reachable"; else pass "port $port not reachable"; fi
done

info "Stack state on the host"
lab_ssh "$TARGET" 'cd /opt/lab03 && docker compose ps --format "{{.Service}} {{.Health}}"' | while read -r svc health; do
  [[ "$health" == "healthy" ]] && pass "$svc healthy" || fail "$svc: $health"
done
lab_ssh "$TARGET" 'stat -c "%a %n" /opt/lab03/secrets /opt/lab03/secrets/db_password.txt'

finish
