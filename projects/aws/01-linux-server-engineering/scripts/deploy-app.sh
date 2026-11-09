#!/usr/bin/env bash
# Copies the shared Taskboard API to the lab host and installs it as a systemd service.
# Usage: scripts/deploy-app.sh            (reads the host IP from terraform output)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform ssh rsync

IP=$(tf_output "$HERE/../terraform" public_ip)
TARGET="ubuntu@$IP"

info "Waiting for SSH and cloud-init on $IP"
wait_for_ssh "$TARGET"
lab_ssh "$TARGET" 'cloud-init status --wait >/dev/null; cloud-init status'

info "Copying application source"
lab_rsync "$ROOT/shared/sample-apps/taskboard/api/" "$TARGET:/tmp/taskboard-src/"

info "Installing as a systemd service"
lab_ssh "$TARGET" 'sudo install-taskboard /tmp/taskboard-src'

pass "deployed. Open a tunnel: ssh -N -L 8000:127.0.0.1:8000 $TARGET  then  curl http://127.0.0.1:8000/api/info"
