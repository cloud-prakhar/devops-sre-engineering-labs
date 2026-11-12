#!/usr/bin/env bash
# Verifies AWS 08: controller healthy, ALB serving through an Ingress, HPA reading metrics, PDB in force,
# rollout strategy, and NetworkPolicy enforcement (allowed and denied flows).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd kubectl curl aws

NS=taskboard
PROBE_IMAGE=busybox:1.37
probe_pod() { # probe_pod <namespace> <name> <labels-json> <url>  -> prints wget exit code
  kubectl run "$2" -n "$1" --image="$PROBE_IMAGE" --restart=Never --rm -i --quiet \
    --overrides="{\"metadata\":{\"labels\":$3},\"spec\":{\"automountServiceAccountToken\":false,\"securityContext\":{\"runAsNonRoot\":true,\"runAsUser\":65534,\"seccompProfile\":{\"type\":\"RuntimeDefault\"}},\"containers\":[{\"name\":\"p\",\"image\":\"$PROBE_IMAGE\",\"command\":[\"sh\",\"-c\",\"wget -q -T 5 -O /dev/null $4; echo rc=\$?\"],\"securityContext\":{\"allowPrivilegeEscalation\":false,\"capabilities\":{\"drop\":[\"ALL\"]}}}]}}" \
    2>/dev/null | sed -n 's/^rc=//p'
}

info "Controller"
ready=$(kubectl get deploy -n kube-system aws-load-balancer-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
(( ${ready:-0} >= 1 )) && pass "aws-load-balancer-controller: $ready ready" || fail "controller not ready"
kubectl get pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].spec.containers[0].env[*].name}' \
  | grep -q AWS_CONTAINER_CREDENTIALS_FULL_URI && pass "controller credentials come from Pod Identity" || warn "Pod Identity env not found on the controller pod"

info "Ingress / ALB"
host=$(kubectl get ingress -n $NS taskboard -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -n "$host" ]] && pass "ALB $host" || fail "Ingress has no address"
ok=0
for _ in $(seq 1 24); do
  curl -fsS -m 5 "http://$host/readyz" >/dev/null 2>&1 && { ok=1; break; }
  sleep 5
done
(( ok )) && pass "ALB → pods (/readyz) from your IP" || fail "ALB not answering"
declare -A seen=()
for _ in $(seq 1 12); do h=$(curl -fsS -m 5 "http://$host/api/info" | sed -n 's/.*"hostname":"\([^"]*\)".*/\1/p'); [[ -n "$h" ]] && seen[$h]=1; done
(( ${#seen[@]} >= 2 )) && pass "requests spread over ${#seen[@]} pods (target-type ip)" || warn "only ${#seen[@]} pod answered"
# The controller names target groups k8s-<namespace[:8]>-<service[:8]>-<hash>.
tg_healthy=0
for tg in $(aws elbv2 describe-target-groups --query "TargetGroups[?starts_with(TargetGroupName,'k8s-taskboar')].TargetGroupArn" --output text); do
  n=$(aws elbv2 describe-target-health --target-group-arn "$tg" --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" --output text)
  tg_healthy=$((tg_healthy + n))
done
(( ${tg_healthy:-0} >= 2 )) && pass "$tg_healthy healthy pod targets in the ALB target group" || warn "healthy targets: ${tg_healthy:-0}"

info "Autoscaling and disruption"
targets=$(kubectl get hpa -n $NS taskboard -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
[[ -n "$targets" ]] && pass "HPA reads CPU: ${targets}% of request (target 60%)" || fail "HPA has no metrics (metrics-server?)"
[[ $(kubectl get deploy -n $NS taskboard -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}') == 0 ]] && pass "rollouts never reduce capacity (maxUnavailable 0)" || fail "rollout strategy"
allowed=$(kubectl get pdb -n $NS taskboard -o jsonpath='{.status.disruptionsAllowed}')
(( ${allowed:-0} >= 1 )) && pass "PDB allows $allowed voluntary disruption(s), keeps 1 available" || warn "PDB allows 0 disruptions now"

info "NetworkPolicy (default deny + explicit allows)"
url="http://taskboard.$NS.svc.cluster.local/healthz"
[[ $(probe_pod $NS np-allowed '{"app.kubernetes.io/name":"load-generator"}' "$url") == 0 ]] && pass "allowed: load-generator → taskboard" || fail "load-generator blocked"
[[ $(probe_pod $NS np-denied '{"app.kubernetes.io/name":"intruder"}' "$url") != 0 ]] && pass "denied: unlabelled pod in the namespace → taskboard" || fail "unlabelled pod reached taskboard"
kubectl create namespace np-outside --dry-run=client -o yaml | kubectl label --local -f - pod-security.kubernetes.io/enforce=restricted -o yaml | kubectl apply -f - >/dev/null
[[ $(probe_pod np-outside np-outside '{"app.kubernetes.io/name":"load-generator"}' "$url") != 0 ]] && pass "denied: pod from another namespace → taskboard" || fail "other namespace reached taskboard"
kubectl delete namespace np-outside --wait=false >/dev/null

finish
