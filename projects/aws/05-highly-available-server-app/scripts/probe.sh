#!/usr/bin/env bash
# Sends one request per interval to the load balancer and prints a running tally, so you can watch
# availability during failure drills and rollouts. Usage: scripts/probe.sh [seconds] [interval]
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform curl

DURATION=${1:-180}
INTERVAL=${2:-0.5}
URL="http://$(tf_output "$HERE/../terraform" alb_dns_name)/api/info"
ok=0; bad=0; end=$((SECONDS + DURATION))
declare -A hosts=()
while (( SECONDS < end )); do
  body=$(curl -s -m 3 -w '\n%{http_code}' "$URL" || printf '\n000')
  code=${body##*$'\n'}
  if [[ "$code" == 200 ]]; then
    ok=$((ok + 1))
    host=$(sed -n 's/.*"hostname":"\([^"]*\)".*/\1/p' <<<"$body")
    hosts[$host]=$(( ${hosts[$host]:-0} + 1 ))
  else
    bad=$((bad + 1))
    printf '%s %s\n' "$(date +%T)" "HTTP $code"
  fi
  sleep "$INTERVAL"
done
total=$((ok + bad))
printf '\n%d requests, %d ok, %d failed (%.2f%% success)\n' "$total" "$ok" "$bad" "$(awk "BEGIN{print 100*$ok/($total>0?$total:1)}")"
for h in "${!hosts[@]}"; do printf '  %-40s %d\n' "$h" "${hosts[$h]}"; done
(( bad == 0 ))
