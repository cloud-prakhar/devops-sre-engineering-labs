#!/usr/bin/env bash
# Logical backup of the Taskboard database (custom format, compressed).
# Usage: ./backup-db.sh [output-dir]      default: ./backups ; keeps the newest 7 dumps
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
OUT=${1:-backups}
install -d -m 0700 "$OUT"
file="$OUT/taskboard-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker compose exec -T db pg_dump -U taskboard -d taskboard --format=custom --compress=6 > "$file.partial"
mv "$file.partial" "$file"   # never leave a truncated file that looks like a good backup
docker compose exec -T db pg_restore --list < "$file" >/dev/null   # integrity check
ls -1t "$OUT"/taskboard-*.dump | tail -n +8 | xargs -r rm -f
echo "backup written: $file ($(du -h "$file" | cut -f1))"
