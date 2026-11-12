#!/usr/bin/env bash
# Deploys k8s/ (AWS 07 base + Ingress, HPA, PDB, NetworkPolicies) with the image pinned by digest and
# the ALB restricted to your CIDR.
# Usage: ALLOWED_HTTP_CIDR=203.0.113.10/32 scripts/deploy-workloads.sh     (IMAGE optional)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd kubectl aws

CIDR=${ALLOWED_HTTP_CIDR:-$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32}
[[ "$CIDR" != 0.0.0.0/0 ]] || die "refusing to open the ALB to 0.0.0.0/0"
IMAGE=${IMAGE:-$(latest_ecr_image)} || die "no image found: run the AWS 06 pipeline first, or set IMAGE=<repo@sha256:...>"
[[ "$IMAGE" =~ @sha256:[0-9a-f]{64}$ ]] || die "IMAGE must be pinned by digest: $IMAGE"

overlay="$HERE/../k8s/.generated"
mkdir -p "$overlay"
cat > "$overlay/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ..
images:
  - name: taskboard-api
    newName: ${IMAGE%@*}
    digest: ${IMAGE#*@}
labels:
  - pairs:
      app.kubernetes.io/version: "${IMAGE: -12}"
    includeTemplates: true
    includeSelectors: false
patches:
  - target:
      kind: Ingress
      name: taskboard
    patch: |-
      - op: replace
        path: /metadata/annotations/alb.ingress.kubernetes.io~1inbound-cidrs
        value: "$CIDR"
YAML

info "Applying with $IMAGE, ALB open to $CIDR"
kubectl apply -k "$overlay"
kubectl rollout status -n taskboard deployment/taskboard --timeout=180s
info "Waiting for the ALB address (1-3 minutes)"
for _ in $(seq 1 36); do
  host=$(kubectl get ingress -n taskboard taskboard -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  [[ -n "$host" ]] && break
  sleep 5
done
[[ -n "${host:-}" ]] || die "no ALB address yet: kubectl describe ingress -n taskboard taskboard"
pass "http://$host/api/info (DNS may take another minute)"
