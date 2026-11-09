#!/usr/bin/env bash
# Verifies AWS 07: control plane settings, nodes across AZs, add-ons, workloads, access entries + RBAC,
# Pod Identity, and Pod Security admission. Run after terraform apply and deploy-workloads.sh.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd kubectl terraform aws jq curl

TF="$HERE/../terraform"
CLUSTER=$(tf_output "$TF" cluster_name)

info "Control plane"
c=$(aws eks describe-cluster --name "$CLUSTER" --query cluster --output json)
[[ $(jq -r .status <<<"$c") == ACTIVE ]] && pass "cluster ACTIVE, Kubernetes $(jq -r .version <<<"$c")" || fail "cluster not ACTIVE"
[[ $(jq -r .accessConfig.authenticationMode <<<"$c") == API ]] && pass "authentication mode API (access entries, no aws-auth)" || fail "auth mode $(jq -r .accessConfig.authenticationMode <<<"$c")"
[[ $(jq -r .upgradePolicy.supportType <<<"$c") == STANDARD ]] && pass "upgrade policy STANDARD (no extended-support surcharge)" || fail "support type $(jq -r .upgradePolicy.supportType <<<"$c")"
cidrs=$(jq -r '.resourcesVpcConfig.publicAccessCidrs | join(",")' <<<"$c")
[[ "$cidrs" != *0.0.0.0/0* ]] && pass "public endpoint restricted to $cidrs" || fail "API endpoint open to the internet"

info "Nodes and add-ons"
ready=$(kubectl get nodes -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')
zones=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}{end}' | sort -u | wc -l)
(( ready >= 2 )) && pass "$ready nodes Ready" || fail "$ready nodes Ready"
(( zones >= 2 )) && pass "nodes in $zones AZs" || warn "nodes in $zones AZ"
for a in $(aws eks list-addons --cluster-name "$CLUSTER" --query 'addons[]' --output text); do
  s=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$a" --query 'addon.[status,addonVersion]' --output text)
  [[ "$s" == ACTIVE* ]] && pass "add-on $a: $s" || fail "add-on $a: $s"
done
notrunning=$(kubectl get pods -n kube-system --no-headers | awk '$3!="Running" && $3!="Completed"' | wc -l)
(( notrunning == 0 )) && pass "all kube-system pods running" || fail "$notrunning kube-system pod(s) not running"
kubectl top nodes >/dev/null 2>&1 && pass "metrics-server answers (kubectl top)" || warn "metrics not available yet"

info "Workload"
avail=$(kubectl get deploy -n taskboard taskboard -o jsonpath='{.status.availableReplicas}')
[[ "${avail:-0}" -ge 2 ]] && pass "taskboard: $avail replicas available" || fail "taskboard available: ${avail:-0}"
kubectl port-forward -n taskboard svc/taskboard 18087:80 >/dev/null 2>&1 &
pf=$!
sleep 3
[[ $(curl -fsS -m 5 http://127.0.0.1:18087/readyz || true) == *ready* ]] && pass "service answers through port-forward" || fail "service unreachable"
kill $pf 2>/dev/null || true

info "Pod Security admission (namespace enforces 'restricted')"
if out=$(kubectl run psa-probe -n taskboard --image=busybox:1.37 --dry-run=server --privileged -- sleep 1 2>&1); then
  fail "privileged pod was admitted"
else
  grep -q 'violates PodSecurity' <<<"$out" && pass "privileged pod rejected by PodSecurity" || fail "unexpected: $out"
fi

info "Access entries + RBAC (as the developer IAM role)"
dev_cfg=$(mktemp)
aws eks update-kubeconfig --name "$CLUSTER" --role-arn "$(tf_output "$TF" developer_role_arn)" --kubeconfig "$dev_cfg" --alias dev >/dev/null
can() { kubectl --kubeconfig "$dev_cfg" auth can-i "$@" 2>/dev/null || true; }
[[ $(can list pods -n taskboard) == yes ]] && pass "developer can list pods in taskboard" || fail "developer cannot list pods"
[[ $(can delete deployments -n taskboard) == no ]] && pass "developer cannot delete deployments" || fail "developer can delete deployments"
[[ $(can list pods -n kube-system) == no ]] && pass "developer cannot read kube-system" || fail "developer can read kube-system"
[[ $(can get nodes) == no ]] && pass "developer cannot read nodes (cluster scope)" || fail "developer can read nodes"
rm -f "$dev_cfg"

info "EKS Pod Identity"
logs=$(kubectl logs -n taskboard job/pod-identity-demo 2>/dev/null || true)
[[ "$logs" == *pod-identity-demo* && "$logs" == *"hello from SSM"* ]] \
  && pass "demo pod assumed its role and read the parameter" || fail "pod identity demo output: $logs"

finish
