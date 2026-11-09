#!/usr/bin/env bash
# End-to-end verification for lab 01, run from your laptop after deploy-app.sh.
# Checks both what must work (key login, service, audit) and what must NOT work
# (password login, public access to the API port).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform ssh curl

IP=$(tf_output "$HERE/../terraform" public_ip)
TARGET="ubuntu@$IP"

info "Positive checks"
if lab_ssh "$TARGET" true; then pass "key-based SSH login works"; else fail "key-based SSH login failed"; fi
status=$(lab_ssh "$TARGET" 'cloud-init status' 2>/dev/null || true)
[[ "$status" == *done* ]] && pass "cloud-init: $status" || fail "cloud-init: $status"
if lab_ssh "$TARGET" 'sudo host-audit'; then pass "host audit passed"; else fail "host audit reported failures (see above)"; fi
info_json=$(lab_ssh "$TARGET" 'curl -fsS http://127.0.0.1:8000/api/info' 2>/dev/null || true)
[[ "$info_json" == *lab01* ]] && pass "API answers on loopback: $info_json" || fail "API not answering on the host"

info "Negative checks (these must be refused)"
pw_out=$(ssh -o BatchMode=yes -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$TARGET" true 2>&1 || true)
[[ "$pw_out" == *"Permission denied (publickey)"* ]] && pass "password authentication refused" \
  || fail "unexpected response to password auth: $pw_out"
root_out=$(ssh "${LAB_SSH_OPTS[@]}" -o BatchMode=yes "root@$IP" true 2>&1 || true)
[[ "$root_out" == *"Permission denied"* ]] && pass "root login refused" || fail "root login not refused: $root_out"
if curl -s --max-time 5 "http://$IP:8000/healthz" >/dev/null 2>&1; then
  fail "API port 8000 is reachable from the internet"
else
  pass "API port 8000 not reachable from the internet"
fi

finish
