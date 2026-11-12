#!/usr/bin/env bash
# Opt-in drills for AWS 08 on the lab cluster only.
#   scripts/failure-drill.sh list | load | drain | rollout | break-policy | restore-policy
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NS=taskboard

case "${1:-list}" in
  list)
    cat <<'LIST'
load            Start 10 minutes of CPU load -> HPA scales 2 -> up to 6, then back down after ~2 minutes idle
drain           Drain one node -> PDB keeps >= 1 replica, pods reschedule, ALB targets move
rollout         Restart the Deployment while you probe the ALB -> maxSurge 1 / maxUnavailable 0, no errors
break-policy    Delete the ALB allow policy -> ALB targets turn unhealthy, users get 502/503
restore-policy  Re-apply all manifests (undoes break-policy)
LIST
    ;;
  load)    kubectl apply -f "$HERE/../k8s/drills/load-generator.yaml"; echo "watch: kubectl get hpa -n $NS -w" ;;
  drain)
    node=$(kubectl get pods -n $NS -l app.kubernetes.io/name=taskboard -o jsonpath='{.items[0].spec.nodeName}')
    kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=180s
    echo "drained $node; undo with: kubectl uncordon $node" ;;
  rollout) kubectl rollout restart -n $NS deploy/taskboard && kubectl rollout status -n $NS deploy/taskboard ;;
  break-policy) kubectl delete networkpolicy -n $NS allow-alb-to-taskboard ;;
  restore-policy) kubectl apply -k "$HERE/../k8s/.generated" ;;
  *) echo "unknown drill: $1" >&2; exit 1 ;;
esac
