#!/usr/bin/env bash
# Build, run, roll out and roll back the Taskboard container on the CURRENT Docker daemon.
# The daemon is chosen by DOCKER_HOST: unset = local (local-test.sh), ssh://... = the VM (deploy.sh).
#
#   taskboard-ctl.sh deploy <tag>    build, replace, health-gate, auto-rollback on failure
#   taskboard-ctl.sh rollback        run the previous image recorded on the container
#   taskboard-ctl.sh status          container, health and resource summary
#   taskboard-ctl.sh remove          delete the container (the data volume is kept)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd docker

NAME=${TASKBOARD_NAME:-taskboard}
IMAGE=taskboard-api
VOLUME=${TASKBOARD_VOLUME:-taskboard-data}
HOST_PORT=${HOST_PORT:-80}
APP_SRC="$ROOT/shared/sample-apps/taskboard/api"
# Only images carrying this label are ever pruned, so hand-built tags are left alone.
MANAGED_LABEL=lab.managed-by=taskboard-ctl

label() { docker inspect -f "{{index .Config.Labels \"$1\"}}" "$NAME" 2>/dev/null || true; }

build() {
  info "Building $IMAGE:$1 on ${DOCKER_HOST:-local daemon}"
  docker build --build-arg "APP_VERSION=$1" --label "$MANAGED_LABEL" -t "$IMAGE:$1" "$APP_SRC"
}

run() {
  local tag=$1 previous=${2:-}
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # Each flag removes a privilege the app does not need. See docs/exercises.md (exercise 3).
  docker run -d --name "$NAME" \
    --restart unless-stopped \
    --publish "${HOST_PORT}:8000" \
    --volume "${VOLUME}:/data" \
    --read-only --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --memory 256m --memory-swap 256m --cpus 0.8 --pids-limit 128 \
    --label "taskboard.previous=${previous}" \
    "$IMAGE:$tag" >/dev/null
}

wait_healthy() {
  local status
  for _ in $(seq 1 30); do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$NAME" 2>/dev/null || echo missing)
    case "$status" in
      healthy) return 0 ;;
      unhealthy|missing) return 1 ;;
    esac
    sleep 2
  done
  return 1
}

prune_images() { # keep the running tag and the previous one
  local keep1=$1 keep2=${2:-} tag
  for tag in $(docker image ls "$IMAGE" --filter "label=$MANAGED_LABEL" --format '{{.Tag}}'); do
    [[ "$tag" == "$keep1" || "$tag" == "$keep2" ]] && continue
    docker image rm "$IMAGE:$tag" >/dev/null 2>&1 || true
  done
}

case "${1:-}" in
  deploy)
    tag=${2:?usage: taskboard-ctl.sh deploy <tag>}
    previous=$(label org.opencontainers.image.version)
    build "$tag"
    info "Replacing container (previous version: ${previous:-none})"
    run "$tag" "$previous"
    if wait_healthy; then
      pass "$NAME is healthy on version $tag"
      prune_images "$tag" "$previous"
    else
      fail "$NAME version $tag did not become healthy"
      docker logs --tail 20 "$NAME" 2>&1 || true
      if [[ -n "$previous" && "$previous" != "$tag" ]]; then
        warn "rolling back to $previous"
        run "$previous" ""
        wait_healthy && pass "rolled back to $previous" || fail "rollback to $previous is unhealthy too"
      fi
      exit 1
    fi
    ;;
  rollback)
    previous=$(label taskboard.previous)
    [[ -n "$previous" ]] || die "no previous version recorded on container $NAME"
    current=$(label org.opencontainers.image.version)
    info "Rolling back $current -> $previous"
    run "$previous" "$current"
    wait_healthy && pass "running $previous" || die "$previous is not healthy"
    ;;
  status)
    docker ps -a --filter "name=^${NAME}$" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    docker inspect -f 'health={{.State.Health.Status}} restarts={{.RestartCount}} user={{.Config.User}} readonly={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}}' "$NAME"
    docker stats --no-stream "$NAME"
    ;;
  remove)
    docker rm -f "$NAME" >/dev/null 2>&1 && pass "removed $NAME (volume $VOLUME kept)" || warn "$NAME not found"
    ;;
  *)
    sed -n '2,9p' "$0"; exit 1 ;;
esac
