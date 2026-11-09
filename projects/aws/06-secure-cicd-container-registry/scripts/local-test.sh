#!/usr/bin/env bash
# Exercises the deploy script against a LOCAL registry, without AWS: digest-only policy, health-gated
# rollout, automatic rollback of a broken image, manual rollback. Costs nothing.
# Usage: scripts/local-test.sh [--keep]
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd docker curl

unset DOCKER_HOST
REG=127.0.0.1:15000
REPO=$REG/lab06/taskboard-api
STATE_DIR=$(mktemp -d)
export TASKBOARD_DEPLOY_STATE=$STATE_DIR TASKBOARD_NAME=lab06-localtest TASKBOARD_VOLUME=lab06-localtest-data \
       HOST_PORT=18090 SKIP_ECR_LOGIN=1
DEPLOY="$HERE/../files/taskboard-deploy.sh"
URL="http://127.0.0.1:$HOST_PORT/api/info"

cleanup() {
  docker rm -f lab06-localtest lab06-registry >/dev/null 2>&1 || true
  docker volume rm lab06-localtest-data >/dev/null 2>&1 || true
  docker image ls "$REPO" --format '{{.Repository}}:{{.Tag}}' | xargs -r docker image rm -f >/dev/null 2>&1 || true
  rm -rf "$STATE_DIR"
}
[[ "${1:-}" == "--keep" ]] || trap cleanup EXIT
cleanup

info "Local registry (stands in for ECR)"
docker run -d --name lab06-registry -p "$REG:5000" registry:3 >/dev/null
sleep 2

push() { # push <tag> <APP_VERSION> [dockerfile-dir]
  docker build -q --build-arg "APP_VERSION=$2" -t "$REPO:$1" "${3:-$ROOT/shared/sample-apps/taskboard/api}" >/dev/null
  docker push -q "$REPO:$1" >/dev/null
  docker inspect --format '{{index .RepoDigests 0}}' "$REPO:$1"
}
V1=$(push v1 v1)
V2=$(push v2 v2)
broken_dir=$(mktemp -d)
printf 'FROM %s\nENV DATABASE_URL=unsupported://broken\n' "$V1" > "$broken_dir/Dockerfile"
BROKEN=$(push broken broken "$broken_dir")
rm -rf "$broken_dir"
pass "pushed v1, v2 and a broken image; deploying by digest, e.g. $V1"

info "Policy: tags are refused"
if "$DEPLOY" "$REPO:v1" >/dev/null 2>&1; then fail "a tag was accepted"; else pass "tag reference refused"; fi

info "Rollout"
"$DEPLOY" "$V1" >/dev/null && [[ $(curl -fsS "$URL") == *'"version":"v1"'* ]] && pass "v1 healthy and serving" || fail "v1 deploy"
"$DEPLOY" "$V2" >/dev/null && [[ $(curl -fsS "$URL") == *'"version":"v2"'* ]] && pass "v2 healthy and serving" || fail "v2 deploy"
[[ $(cat "$STATE_DIR/previous") == "$V1" && $(cat "$STATE_DIR/current") == "$V2" ]] && pass "state: current=v2 previous=v1" || fail "state files"

info "Broken release rolls back automatically"
if "$DEPLOY" "$BROKEN" >/dev/null 2>&1; then fail "broken image reported healthy"; else pass "broken image rejected (exit 1)"; fi
[[ $(curl -fsS "$URL") == *'"version":"v2"'* ]] && pass "v2 restored and serving" || fail "service not restored"
[[ $(cat "$STATE_DIR/current") == "$V2" ]] && pass "state still points at v2" || fail "state corrupted by failed deploy"

info "Manual rollback"
"$DEPLOY" --rollback >/dev/null && [[ $(curl -fsS "$URL") == *'"version":"v1"'* ]] && pass "rolled back to v1" || fail "rollback"

info "Runtime profile"
[[ $(docker inspect -f '{{.Config.User}} {{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}}' lab06-localtest) == "10001:10001 true [ALL]" ]] \
  && pass "non-root, read-only, no capabilities" || fail "runtime profile"

finish
