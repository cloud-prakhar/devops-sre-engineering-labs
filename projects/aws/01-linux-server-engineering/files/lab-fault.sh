#!/usr/bin/env bash
# Opt-in, bounded failure injection for lab 01. Affects only this host.
# Every scenario either stops by itself or schedules its own automatic revert.
#
#   sudo lab-fault list
#   sudo lab-fault <scenario>
#   sudo lab-fault revert          # undo everything now
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root (sudo lab-fault ...)" >&2; exit 1; }

FILL_FILE=/var/tmp/lab-fault-fill.img
DROPIN_DIR=/etc/systemd/system/taskboard.service.d
DROPIN=$DROPIN_DIR/99-lab-fault.conf
AUTO_REVERT_MIN=10

schedule_revert() {
  systemd-run --quiet --unit "lab-fault-revert-$1" --on-active="${AUTO_REVERT_MIN}m" \
    /usr/local/sbin/lab-fault revert >/dev/null 2>&1 || true
  echo "auto-revert scheduled in ${AUTO_REVERT_MIN} minutes (or run: sudo lab-fault revert)"
}

case "${1:-list}" in
  list)
    cat <<'LIST'
cpu        Saturate all vCPUs for 120 s (watch: top, mpstat 1, CPU credit balance)
memory     Allocate ~90% of RAM for 90 s (watch: free -m, vmstat 1, dmesg for OOM kills)
disk       Fill the root filesystem to ~95% (watch: df -h, du, journal errors)
crashloop  Make taskboard fail on every start (watch: systemctl status, journalctl -u)
kill       SIGKILL the taskboard process once (watch: systemd restarting it)
dns        Block outbound DNS (watch: resolvectl, dig, apt update failing)
revert     Undo disk, crashloop and dns faults immediately
LIST
    ;;
  cpu)
    echo "saturating $(nproc) vCPU(s) for 120 s"
    stress-ng --cpu "$(nproc)" --timeout 120s --metrics-brief
    ;;
  memory)
    echo "allocating ~90% of RAM for 90 s; the kernel OOM killer may terminate processes"
    stress-ng --vm 1 --vm-bytes 90% --vm-keep --timeout 90s --metrics-brief || true
    ;;
  disk)
    avail_kb=$(df --output=avail / | tail -n1)
    size_kb=$(df --output=size / | tail -n1)
    target_kb=$(( avail_kb - size_kb * 5 / 100 ))
    (( target_kb > 0 )) || { echo "disk already above 95%"; exit 0; }
    fallocate -l "${target_kb}K" "$FILL_FILE"
    df -h /
    schedule_revert disk
    ;;
  crashloop)
    mkdir -p "$DROPIN_DIR"
    printf '[Service]\nEnvironment=DATABASE_URL=unsupported://broken\n' > "$DROPIN"
    systemctl daemon-reload
    systemctl restart taskboard || true
    schedule_revert crashloop
    ;;
  kill)
    pid=$(systemctl show -p MainPID --value taskboard)
    [[ "$pid" != "0" ]] || { echo "taskboard is not running"; exit 1; }
    kill -9 "$pid"
    echo "killed PID $pid; systemd restarts it after RestartSec=3"
    ;;
  dns)
    ufw insert 1 deny out 53 >/dev/null
    resolvectl flush-caches || true
    echo "outbound DNS blocked"
    schedule_revert dns
    ;;
  revert)
    rm -f "$FILL_FILE"
    if [[ -f "$DROPIN" ]]; then
      rm -f "$DROPIN"
      systemctl daemon-reload
      systemctl reset-failed taskboard || true
      systemctl restart taskboard || true
    fi
    while ufw status numbered | grep -q '53 .*DENY OUT'; do
      ufw --force delete deny out 53 >/dev/null || break
    done
    for unit in disk crashloop dns; do
      systemctl stop "lab-fault-revert-$unit.timer" >/dev/null 2>&1 || true
    done
    echo "all reversible faults reverted"
    ;;
  *)
    echo "unknown scenario: $1 (try: lab-fault list)" >&2
    exit 1
    ;;
esac
