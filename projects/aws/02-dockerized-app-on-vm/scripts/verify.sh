#!/usr/bin/env bash
# Verifies the cloud deployment of lab 02 from your laptop.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform curl docker

IP=$(tf_output "$HERE/../terraform" public_ip)
export DOCKER_HOST="ssh://ubuntu@$IP"

info "Application"
[[ $(curl -fsS --max-time 5 "http://$IP/healthz") == *ok* ]] && pass "http://$IP/healthz" || fail "healthz unreachable"
[[ $(curl -fsS --max-time 5 "http://$IP/readyz") == *ready* ]] && pass "readyz" || fail "readyz"
curl -fsS --max-time 5 "http://$IP/api/info" && echo

info "Docker daemon settings"
dinfo=$(docker info --format '{{.LoggingDriver}} live-restore={{.LiveRestoreEnabled}} {{.ServerVersion}}')
[[ "$dinfo" == local\ live-restore=true* ]] && pass "daemon: $dinfo" || fail "daemon: $dinfo"

info "Container hardening"
hc=$(docker inspect -f '{{.Config.User}} {{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}} {{.HostConfig.Memory}}' taskboard)
[[ "$hc" == "10001:10001 true [ALL] 268435456" ]] && pass "user/readonly/capdrop/memory: $hc" || fail "unexpected: $hc"

info "Exposure"
if curl -s --max-time 5 "http://$IP:8000/healthz" >/dev/null; then fail "container port 8000 reachable directly"; else pass "port 8000 not reachable"; fi
ufw=$(lab_ssh "ubuntu@$IP" 'sudo ufw status | grep -c 80' || true)
[[ "$ufw" == "0" ]] && warn "port 80 works although ufw has no rule for it: Docker bypasses ufw (exercise 4)"

finish
