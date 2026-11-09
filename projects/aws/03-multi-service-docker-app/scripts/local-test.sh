#!/usr/bin/env bash
# Runs the full Compose stack on your LOCAL Docker daemon on high ports and checks routing, TLS,
# isolation, failure recovery and backup/restore. Costs nothing; does not touch AWS.
# Usage: scripts/local-test.sh [--keep]
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
STACK="$HERE/../stack"
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd docker curl openssl

unset DOCKER_HOST
export COMPOSE_PROJECT_NAME=taskboard HTTP_PORT=${HTTP_PORT:-18080} HTTPS_PORT=${HTTPS_PORT:-18443}
export APP_VERSION=localtest TLS_SAN="DNS:localhost,IP:127.0.0.1"
BASE="https://127.0.0.1:$HTTPS_PORT"
dc() { docker compose --project-directory "$STACK" -f "$STACK/compose.yaml" "$@"; }
cleanup() { dc down -v --remove-orphans >/dev/null 2>&1 || true; }
[[ "${1:-}" == "--keep" ]] || trap cleanup EXIT

"$STACK/init-secrets.sh" >/dev/null
info "Starting the stack (build + wait for health)"
dc up -d --build --wait --wait-timeout 180

info "Routing and TLS"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$HTTP_PORT/")
[[ "$code" == "301" ]] && pass "HTTP redirects to HTTPS (301)" || fail "HTTP returned $code"
curl -fsSk "$BASE/" | grep -q '<title>Taskboard</title>' && pass "frontend served over HTTPS" || fail "frontend"
[[ $(curl -fsSk "$BASE/readyz") == *postgresql* ]] && pass "/readyz: api -> postgresql" || fail "/readyz"
proto=$(echo | openssl s_client -connect "127.0.0.1:$HTTPS_PORT" 2>/dev/null | awk '/^ *Protocol *:/{print $3; exit} /New, TLSv/{print $2; exit}' | tr -d ',')
[[ "$proto" == "TLSv1.3" ]] && pass "negotiated $proto" || fail "negotiated '$proto', expected TLSv1.3"
san=$(echo | openssl s_client -connect "127.0.0.1:$HTTPS_PORT" 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | tail -n1)
[[ "$san" == *"IP Address:127.0.0.1"* ]] && pass "certificate SAN: $san" || fail "certificate SAN: $san"
curl -fsSk -X POST "$BASE/api/tasks" -H 'content-type: application/json' -d '{"title":"backup me"}' >/dev/null && pass "task created through proxy" || fail "create task"

info "Isolation"
published=$(dc ps --format '{{.Service}} {{.Publishers}}' | grep -v '^proxy' | grep -c 'PublishedPort:[1-9]' || true)
[[ "$published" == "0" ]] && pass "only the proxy publishes ports" || fail "other services publish ports"
if docker run --rm --network taskboard_edge postgres:17-alpine pg_isready -h db -t 3 >/dev/null 2>&1; then
  fail "database reachable from the edge network"
else
  pass "database not reachable from the edge network"
fi
if docker run --rm --network taskboard_backend alpine:3.22 wget -q -T 3 -O /dev/null https://pypi.org >/dev/null 2>&1; then
  fail "backend network has internet access"
else
  pass "backend network is internal (no internet)"
fi
[[ $(docker inspect -f '{{.Config.User}}' "$(dc ps -q db)") == "70:70" ]] && pass "postgres runs as UID 70" || fail "postgres user"
[[ $(dc exec -T db sh -c 'cat /proc/1/status' | awk '/CapBnd/{print $2}') == "0000000000000000" ]] && pass "postgres has no capabilities" || fail "postgres capabilities"
dc exec -T api sh -c 'env' | grep -qi 'password=' && fail "password in API environment" || pass "no password in API environment"

info "Backup"
"$STACK/backup-db.sh" "$STACK/backups-localtest" | tail -n1
dump=$(ls -1t "$STACK"/backups-localtest/*.dump | head -n1)

info "Failure: database down"
"$STACK/failure-drill.sh" db-down >/dev/null 2>&1
sleep 2
code=$(curl -sk -o /dev/null -w '%{http_code}' "$BASE/readyz")
[[ "$code" == "503" ]] && pass "/readyz returns 503 while db is down" || fail "/readyz returned $code"
code=$(curl -sk -o /dev/null -w '%{http_code}' "$BASE/")
[[ "$code" == "200" ]] && pass "frontend still served during db outage" || fail "frontend returned $code"
[[ $(docker inspect -f '{{.State.Health.Status}}' "$(dc ps -q api)") == "healthy" ]] && pass "api liveness unaffected (no restart storm)" || fail "api unhealthy"
"$STACK/failure-drill.sh" recover >/dev/null 2>&1
[[ $(curl -fsSk "$BASE/readyz") == *ready* ]] && pass "recovered after db restart" || fail "not recovered"

info "Failure: API recreated with a new IP"
old_ip=$(docker inspect -f '{{(index .NetworkSettings.Networks "taskboard_edge").IPAddress}}' "$(dc ps -q api)")
dc rm -sf api >/dev/null 2>&1
# Occupy the freed address so the new API container is forced onto a different IP.
docker run -d --rm --name taskboard-ip-squatter --network taskboard_edge alpine:3.22 sleep 120 >/dev/null
dc up -d --wait >/dev/null 2>&1
docker rm -f taskboard-ip-squatter >/dev/null
sleep 11   # resolver valid=10s
new_ip=$(docker inspect -f '{{(index .NetworkSettings.Networks "taskboard_edge").IPAddress}}' "$(dc ps -q api)")
code=$(curl -sk -o /dev/null -w '%{http_code}' "$BASE/api/info")
[[ "$old_ip" != "$new_ip" ]] || fail "API kept its IP ($old_ip); test inconclusive"
[[ "$code" == "200" ]] && pass "proxy follows API ($old_ip -> $new_ip) without reload" || fail "proxy returned $code after API recreate"

info "Restore"
curl -fsSk -X POST "$BASE/api/tasks" -H 'content-type: application/json' -d '{"title":"after backup"}' >/dev/null
"$STACK/restore-db.sh" "$dump" --yes >/dev/null
tasks=$(curl -fsSk "$BASE/api/tasks")
[[ "$tasks" == *"backup me"* && "$tasks" != *"after backup"* ]] && pass "restore returned data to the backup point" || fail "restore result: $tasks"
rm -rf "$STACK/backups-localtest"

info "Rate limiting"
codes=$(for _ in $(seq 1 80); do curl -sk -o /dev/null -w '%{http_code}\n' "$BASE/api/info" & done; wait)
grep -q 429 <<<"$codes" && pass "burst beyond 20 r/s + 40 receives 429" || warn "no 429 seen (client too slow to exceed the limit)"

finish
