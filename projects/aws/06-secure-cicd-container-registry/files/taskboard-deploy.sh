#!/usr/bin/env bash
# Deploys the Taskboard image on this host. Called by the pipeline through SSM Run Command.
#
#   taskboard-deploy <registry/repo@sha256:...>   deploy an image pinned by digest
#   taskboard-deploy --rollback                    redeploy the previously running digest
#   taskboard-deploy --status                      print current and previous digests
#
# Only digests are accepted: a tag can be moved to different content after it was tested and
# scanned; a digest cannot. The run profile matches AWS 02 (non-root, read-only, no capabilities).
set -euo pipefail

STATE=${TASKBOARD_DEPLOY_STATE:-/var/lib/taskboard-deploy}
NAME=${TASKBOARD_NAME:-taskboard}
VOLUME=${TASKBOARD_VOLUME:-taskboard-data}
HOST_PORT=${HOST_PORT:-80}
AWS=${AWS_CLI:-$(command -v aws || echo /snap/bin/aws)}

log() { echo "taskboard-deploy: $*"; }
die() { log "ERROR: $*" >&2; exit 1; }

ecr_login() {
  local registry=${1%%/*} region
  [[ -n "${SKIP_ECR_LOGIN:-}" || "$registry" != *.dkr.ecr.*.amazonaws.com ]] && return 0
  region=$(cut -d. -f4 <<<"$registry")
  # The instance role allows ecr:GetAuthorizationToken and pulls from one repository only.
  "$AWS" ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry" >/dev/null
}

run() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" \
    --restart unless-stopped \
    --publish "${HOST_PORT}:8000" \
    --volume "${VOLUME}:/data" \
    --read-only --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --cap-drop ALL --security-opt no-new-privileges:true \
    --memory 256m --memory-swap 256m --cpus 0.8 --pids-limit 128 \
    --label "taskboard.image=$1" \
    "$1" >/dev/null
}

wait_healthy() {
  local status
  for _ in $(seq 1 30); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$NAME" 2>/dev/null || echo missing)
    [[ "$status" == healthy ]] && return 0
    [[ "$status" == unhealthy || "$status" == missing ]] && return 1
    sleep 2
  done
  return 1
}

mkdir -p "$STATE"
current=$(cat "$STATE/current" 2>/dev/null || true)

case "${1:-}" in
  --status)
    echo "current:  ${current:-none}"
    echo "previous: $(cat "$STATE/previous" 2>/dev/null || echo none)"
    exit 0 ;;
  --rollback)
    target=$(cat "$STATE/previous" 2>/dev/null || true)
    [[ -n "$target" ]] || die "no previous digest recorded" ;;
  "") die "usage: taskboard-deploy <image@sha256:...> | --rollback | --status" ;;
  *) target=$1 ;;
esac

[[ "$target" =~ @sha256:[0-9a-f]{64}$ ]] || die "refusing '$target': deploy by digest (repo@sha256:...) only"

log "pulling $target"
ecr_login "$target"
docker pull --quiet "$target" >/dev/null

log "replacing container (was: ${current:-none})"
run "$target"
if wait_healthy; then
  if [[ "$target" != "$current" ]]; then
    [[ -n "$current" ]] && echo "$current" > "$STATE/previous"
    echo "$target" > "$STATE/current"
  fi
  docker image prune -f >/dev/null
  log "healthy: $target"
  exit 0
fi

log "new image unhealthy; last log lines:"
docker logs --tail 15 "$NAME" 2>&1 | sed 's/^/  /' || true
if [[ -n "$current" && "$current" != "$target" ]]; then
  log "rolling back to $current"
  run "$current"
  wait_healthy && log "rollback healthy" || log "ROLLBACK UNHEALTHY"
fi
exit 1
