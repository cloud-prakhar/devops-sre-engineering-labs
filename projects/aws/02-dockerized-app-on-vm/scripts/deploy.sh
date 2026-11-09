#!/usr/bin/env bash
# Deploys Taskboard to the lab VM by driving its Docker daemon over SSH (no registry needed).
# Usage: scripts/deploy.sh [tag]     default tag: current git commit
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform ssh docker

TAG=${1:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}
IP=$(tf_output "$HERE/../terraform" public_ip)

info "Waiting for SSH and cloud-init on $IP"
wait_for_ssh "ubuntu@$IP"
lab_ssh "ubuntu@$IP" 'cloud-init status --wait >/dev/null; cloud-init status; docker version --format "docker {{.Server.Version}}"'

export DOCKER_HOST="ssh://ubuntu@$IP"
"$HERE/taskboard-ctl.sh" deploy "$TAG"
pass "open http://$IP/api/info"
