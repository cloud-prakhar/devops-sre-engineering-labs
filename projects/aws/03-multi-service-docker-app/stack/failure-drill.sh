#!/usr/bin/env bash
# Opt-in failure injection for the Taskboard stack. Only touches this Compose project.
#   ./failure-drill.sh list | <scenario> | recover
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
dc() { docker compose "$@"; }

case "${1:-list}" in
  list)
    cat <<'LIST'
db-down        Stop PostgreSQL         -> /readyz 503, writes fail, frontend still loads
api-crash      SIGKILL the API         -> brief 502s, restart policy recovers it
api-partition  Disconnect API from db  -> /readyz 503 after DB_CONNECT_TIMEOUT, no restart
proxy-down     Stop the proxy          -> connection refused on 80/443
recreate-api   Recreate the API        -> new container IP; proxy re-resolves within 10 s
recover        Bring everything back
LIST
    ;;
  db-down)       dc stop db ;;
  api-crash)     dc kill -s KILL api ;;
  api-partition) docker network disconnect taskboard_backend "$(dc ps -q api)" ;;
  proxy-down)    dc stop proxy ;;
  recreate-api)  dc up -d --force-recreate --no-deps api ;;
  recover)
    docker network connect taskboard_backend "$(dc ps -q api)" 2>/dev/null || true
    dc up -d --wait
    ;;
  *) echo "unknown scenario: $1" >&2; exit 1 ;;
esac
