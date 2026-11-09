#!/usr/bin/env bash
# Read-only security and health audit for the lab host. Exit code 1 if any check fails.
# Run on the host:  sudo host-audit
set -uo pipefail

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

[[ $EUID -eq 0 ]] || { echo "run as root (sudo host-audit)" >&2; exit 2; }

echo "== SSH (effective configuration from sshd -T)"
sshd_cfg=$(sshd -T 2>/dev/null)
check_sshd() {
  if grep -qix "$1 $2" <<<"$sshd_cfg"; then pass "sshd $1 = $2"; else fail "sshd $1 is '$(grep -i "^$1 " <<<"$sshd_cfg" | cut -d' ' -f2-)', want '$2'"; fi
}
check_sshd passwordauthentication no
check_sshd permitrootlogin no
check_sshd kbdinteractiveauthentication no
check_sshd x11forwarding no
if grep -qi '^allowgroups ssh-users' <<<"$sshd_cfg"; then pass "sshd restricted to group ssh-users"; else warn "AllowGroups not set"; fi

echo "== Firewall"
if ufw status | grep -q '^Status: active'; then pass "ufw active"; else fail "ufw inactive"; fi
if ufw status verbose | grep -q 'deny (incoming)'; then pass "ufw default deny incoming"; else fail "ufw does not deny incoming by default"; fi

echo "== Listening sockets"
# Expect only sshd publicly; DNS stub and the API on loopback.
while read -r addr proc; do
  case "$addr" in
    127.*|'[::1]'*) pass "loopback listener $addr ($proc)" ;;
    *:22) pass "ssh listener $addr" ;;
    *) fail "unexpected public listener $addr ($proc)" ;;
  esac
done < <(ss -Htlnp | awk '{print $4, $6}')

echo "== Accounts"
uid0=$(awk -F: '$3==0{print $1}' /etc/passwd | tr '\n' ' ')
[[ "$uid0" == "root " ]] && pass "only root has UID 0" || fail "UID 0 accounts: $uid0"
empty_pw=$(awk -F: '($2==""){print $1}' /etc/shadow)
[[ -z "$empty_pw" ]] && pass "no accounts with empty passwords" || fail "empty passwords: $empty_pw"
nopasswd=$(grep -rhs 'NOPASSWD' /etc/sudoers /etc/sudoers.d | grep -v '^#' || true)
[[ -n "$nopasswd" ]] && warn "NOPASSWD sudo rules exist (cloud default for 'ubuntu'): $(echo "$nopasswd" | head -n1)"

echo "== Patching"
systemctl is-enabled --quiet unattended-upgrades && pass "unattended-upgrades enabled" || fail "unattended-upgrades disabled"
if [[ -f /var/run/reboot-required ]]; then
  warn "reboot required for: $(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null)"
else
  pass "no pending reboot"
fi
upgradable=$(apt list --upgradable 2>/dev/null | grep -c -- '-security' || true)
(( upgradable == 0 )) && pass "no pending security updates" || warn "$upgradable security update(s) pending"

echo "== Instance metadata (IMDSv2 must be enforced)"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://169.254.169.254/latest/meta-data/ || true)
[[ "$code" == "401" ]] && pass "IMDSv1 request rejected (401)" || fail "IMDSv1 request returned $code (expected 401)"

echo "== Health"
failed_units=$(systemctl --failed --no-legend --plain | awk '{print $1}' | tr '\n' ' ')
[[ -z "$failed_units" ]] && pass "no failed systemd units" || fail "failed units: $failed_units"
while read -r use mount; do
  pct=${use%\%}
  (( pct < 80 )) && pass "disk $mount at $use" || fail "disk $mount at $use (>= 80%)"
done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x squashfs -x efivarfs | tail -n +2)
avail_mb=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
(( avail_mb > 100 )) && pass "memory available ${avail_mb} MiB" || fail "memory available only ${avail_mb} MiB"
timedatectl show -p NTPSynchronized --value | grep -q yes && pass "clock synchronised" || warn "clock not synchronised yet"
if systemctl is-active --quiet taskboard; then
  curl -fsS --max-time 3 http://127.0.0.1:8000/readyz >/dev/null && pass "taskboard ready" || fail "taskboard active but /readyz failing"
else
  warn "taskboard not running (install it with scripts/deploy-app.sh)"
fi

echo
if (( failures > 0 )); then echo "$failures check(s) failed"; exit 1; fi
echo "audit passed"
