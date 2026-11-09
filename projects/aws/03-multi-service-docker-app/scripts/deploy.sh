#!/usr/bin/env bash
# Ships the Compose stack and the shared Taskboard source to the VM, then builds and starts it.
# Secrets are generated ON the VM and never copied. Usage: scripts/deploy.sh [version]
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform ssh rsync

VERSION=${1:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}
IP=$(tf_output "$HERE/../terraform" public_ip)
TARGET="ubuntu@$IP"
REMOTE=/opt/lab03

info "Waiting for SSH, cloud-init and Docker on $IP"
wait_for_ssh "$TARGET"
lab_ssh "$TARGET" "cloud-init status --wait >/dev/null; docker compose version; sudo install -d -o ubuntu -g ubuntu -m 0750 $REMOTE"

info "Syncing stack and application source"
# --delete keeps the remote copy identical, except for state that must survive deploys.
rsync -az --delete --exclude secrets/ --exclude backups/ --exclude .env -e "ssh ${LAB_SSH_OPTS[*]}" \
  "$HERE/../stack/" "$TARGET:$REMOTE/"
rsync -az --delete --exclude tests/ --exclude __pycache__/ -e "ssh ${LAB_SSH_OPTS[*]}" \
  "$ROOT/shared/sample-apps/taskboard/" "$TARGET:$REMOTE/taskboard/"

info "Configuring and starting version $VERSION"
lab_ssh "$TARGET" bash -s -- "$REMOTE" "$VERSION" "$IP" <<'REMOTE_SCRIPT'
set -euo pipefail
cd "$1"
./init-secrets.sh
cat > .env <<ENV
APP_VERSION=$2
HTTP_PORT=80
HTTPS_PORT=443
TLS_SAN=IP:$3
TASKBOARD_SRC=./taskboard
ENV
docker compose up -d --build --wait --wait-timeout 300
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
# Keep the two newest image versions of each service.
for img in taskboard-api taskboard-frontend taskboard-proxy; do
  docker image ls "$img" --format '{{.CreatedAt}}\t{{.Repository}}:{{.Tag}}' | sort -r | tail -n +3 | cut -f2 | xargs -r docker image rm >/dev/null 2>&1 || true
done
REMOTE_SCRIPT

pass "deployed. Open https://$IP/ (self-signed certificate: accept the warning)"
