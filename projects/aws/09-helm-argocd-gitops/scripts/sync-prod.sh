#!/usr/bin/env bash
# Shows what prod would change, then asks Argo CD to sync it (a manual gate — prod has no automated sync).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd kubectl jq

app=$(kubectl -n argocd get application taskboard-prod -o json)
info "taskboard-prod: $(jq -r '.status.sync.status + " / " + .status.health.status' <<<"$app") at $(jq -r '.status.sync.revision[0:12] // "?"' <<<"$app")"
jq -r '.status.resources[]? | select(.status != "Synced") | "  \(.status)  \(.kind)/\(.name)"' <<<"$app"
read -r -p "Sync prod now? [y/N] " answer
[[ "$answer" == [yY] ]] || die "aborted"
kubectl -n argocd patch application taskboard-prod --type merge \
  -p '{"operation":{"initiatedBy":{"username":"sync-prod.sh"},"sync":{"syncStrategy":{"apply":{}}}}}' >/dev/null
for _ in $(seq 1 60); do
  phase=$(kubectl -n argocd get application taskboard-prod -o jsonpath='{.status.operationState.phase}')
  [[ "$phase" == Succeeded || "$phase" == Failed || "$phase" == Error ]] && break
  sleep 5
done
[[ "$phase" == Succeeded ]] && pass "prod synced" || die "sync $phase: kubectl -n argocd describe application taskboard-prod"
