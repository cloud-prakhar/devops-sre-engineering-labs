#!/usr/bin/env bash
# Runs the exact container configuration from taskboard-ctl.sh on your LOCAL Docker daemon
# and checks behaviour and hardening. Costs nothing; does not touch AWS.
# This is a container test, not a substitute for testing the cloud deployment.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd docker curl

unset DOCKER_HOST
export TASKBOARD_NAME=taskboard-localtest TASKBOARD_VOLUME=taskboard-localtest-data HOST_PORT=${HOST_PORT:-18080}
URL="http://127.0.0.1:$HOST_PORT"
cleanup() {
  docker rm -f "$TASKBOARD_NAME" >/dev/null 2>&1 || true
  docker volume rm "$TASKBOARD_VOLUME" >/dev/null 2>&1 || true
  docker image ls taskboard-api --format '{{.Tag}}' | grep -E '^localtest-' | sed 's/^/taskboard-api:/' | xargs -r docker image rm >/dev/null 2>&1 || true
}
[[ "${1:-}" == "--keep" ]] || trap cleanup EXIT
cleanup

"$HERE/taskboard-ctl.sh" deploy localtest-v1

info "Functional checks"
[[ $(curl -fsS "$URL/healthz") == *ok* ]] && pass "/healthz" || fail "/healthz"
[[ $(curl -fsS "$URL/readyz") == *sqlite* ]] && pass "/readyz reports sqlite" || fail "/readyz"
id=$(curl -fsS -X POST "$URL/api/tasks" -H 'content-type: application/json' -d '{"title":"persist me"}' | sed -E 's/.*"id":([0-9]+).*/\1/')
[[ -n "$id" ]] && pass "created task $id" || fail "create task"

info "Hardening checks"
[[ $(docker inspect -f '{{.Config.User}}' "$TASKBOARD_NAME") == "10001:10001" ]] && pass "runs as UID 10001" || fail "not running as 10001"
docker exec "$TASKBOARD_NAME" sh -c 'touch /srv/x' 2>/dev/null && fail "root filesystem is writable" || pass "root filesystem is read-only"
docker exec "$TASKBOARD_NAME" sh -c 'touch /data/ok && rm /data/ok' && pass "/data volume is writable" || fail "/data not writable"
capeff=$(docker exec "$TASKBOARD_NAME" sh -c "grep CapEff /proc/1/status | awk '{print \$2}'")
[[ "$capeff" == "0000000000000000" ]] && pass "no effective capabilities" || fail "CapEff=$capeff"

info "Rollout, persistence and rollback"
"$HERE/taskboard-ctl.sh" deploy localtest-v2
[[ $(curl -fsS "$URL/api/info") == *localtest-v2* ]] && pass "v2 serving" || fail "v2 not serving"
curl -fsS "$URL/api/tasks" | grep -q 'persist me' && pass "data survived container replacement" || fail "data lost"
"$HERE/taskboard-ctl.sh" rollback
[[ $(curl -fsS "$URL/api/info") == *localtest-v1* ]] && pass "rolled back to v1" || fail "rollback failed"

info "Self-healing"
docker exec "$TASKBOARD_NAME" sh -c 'kill 1' || true
sleep 6
[[ $(docker inspect -f '{{.RestartCount}}' "$TASKBOARD_NAME") -ge 1 ]] && pass "restart policy restarted the container" || fail "container was not restarted"

finish
