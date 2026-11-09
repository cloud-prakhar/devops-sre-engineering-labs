#!/usr/bin/env bash
# Restores a dump created by backup-db.sh into the running database. DESTRUCTIVE: replaces
# existing tables. Usage: ./restore-db.sh backups/taskboard-<timestamp>.dump [--yes]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
dump=${1:?usage: restore-db.sh <dump-file> [--yes]}
[[ -s "$dump" ]] || { echo "dump not found or empty: $dump" >&2; exit 1; }
if [[ "${2:-}" != "--yes" ]]; then
  read -r -p "Replace all Taskboard data with $dump? [y/N] " answer
  [[ "$answer" == [yY] ]] || { echo "aborted"; exit 1; }
fi
docker compose exec -T db pg_restore -U taskboard -d taskboard --clean --if-exists --no-owner --single-transaction < "$dump"
echo "restored $dump"
