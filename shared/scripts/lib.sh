#!/usr/bin/env bash
# Shared helpers for lab scripts. Source it; do not execute it.
# Usage: source "$(dirname "$0")/../../../../shared/scripts/lib.sh"

set -euo pipefail

if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YLW=$'\e[33m'; C_BLU=$'\e[34m'; C_OFF=$'\e[0m'
else
  C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_OFF=""
fi

LAB_FAILURES=0

info() { printf '%s==>%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
pass() { printf '%sPASS%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn() { printf '%sWARN%s %s\n' "$C_YLW" "$C_OFF" "$*"; }
fail() { printf '%sFAIL%s %s\n' "$C_RED" "$C_OFF" "$*"; LAB_FAILURES=$((LAB_FAILURES + 1)); }
die()  { printf '%sERROR%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
  done
}

# tf_output <terraform-dir> <output-name>
tf_output() {
  terraform -chdir="$1" output -raw "$2" 2>/dev/null \
    || die "terraform output '$2' not found in $1 — run 'terraform apply' first"
}

# SSH options shared by every lab script. accept-new trusts a host key the first time and
# refuses a changed key afterwards (see troubleshooting: REMOTE HOST IDENTIFICATION HAS CHANGED).
LAB_SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=15)
if [[ -n "${LAB_SSH_KEY:-}" ]]; then
  LAB_SSH_OPTS+=(-i "$LAB_SSH_KEY")
fi

lab_ssh() {   # lab_ssh <user@host> <command...>
  local target=$1; shift
  ssh "${LAB_SSH_OPTS[@]}" "$target" "$@"
}

lab_rsync() { # lab_rsync <src> <user@host:dst>
  rsync -az --delete -e "ssh ${LAB_SSH_OPTS[*]}" "$1" "$2"
}

# wait_for_ssh <user@host> [timeout-seconds]
wait_for_ssh() {
  local target=$1 timeout=${2:-300} start
  start=$(date +%s)
  until lab_ssh "$target" true 2>/dev/null; do
    (( $(date +%s) - start > timeout )) && die "SSH to $target not ready after ${timeout}s"
    sleep 5
  done
}

finish() {
  if (( LAB_FAILURES > 0 )); then
    printf '\n%s%d check(s) failed.%s\n' "$C_RED" "$LAB_FAILURES" "$C_OFF"
    exit 1
  fi
  printf '\n%sAll checks passed.%s\n' "$C_GRN" "$C_OFF"
}
