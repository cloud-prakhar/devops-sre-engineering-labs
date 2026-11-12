#!/usr/bin/env bash
# Installs the AWS Load Balancer Controller (Helm chart pinned) into kube-system. Its AWS permissions
# come from the Pod Identity association created by terraform/ (no IRSA annotation needed).
# Usage: scripts/install-controller.sh        (current kubectl context = the AWS 07 cluster)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd helm kubectl terraform

CHART_VERSION=3.6.2          # controller v3.6.2 — keep in step with terraform/policies/*.json
TF="$HERE/../terraform"

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks >/dev/null

info "Installing aws-load-balancer-controller chart $CHART_VERSION"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system --version "$CHART_VERSION" \
  --set clusterName="$(tf_output "$TF" cluster_name)" \
  --set region="$(tf_output "$TF" region)" \
  --set vpcId="$(tf_output "$TF" vpc_id)" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set replicaCount=2 \
  --wait --timeout 5m

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=180s
kubectl get ingressclass alb >/dev/null && pass "IngressClass alb available"
