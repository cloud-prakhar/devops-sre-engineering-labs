#!/usr/bin/env bash
# Deploys k8s/base (+ k8s/aws on EKS) with the Taskboard image pinned by digest.
# Image: $IMAGE if set (repo@sha256:...), otherwise the newest image in AWS 06's ECR repository.
# Usage: scripts/deploy-workloads.sh            (uses the current kubectl context)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd kubectl terraform aws

TF="$HERE/../terraform"
IMAGE=${IMAGE:-$(latest_ecr_image)} || die "no image found: run the AWS 06 pipeline first, or set IMAGE=<repo@sha256:...>"
[[ "$IMAGE" =~ @sha256:[0-9a-f]{64}$ ]] || die "IMAGE must be pinned by digest: $IMAGE"
VERSION=${VERSION:-${IMAGE: -12}}

# Kustomize only accepts relative paths inside the repository, so the overlay lives in k8s/.generated
# (git-ignored) and is rewritten on every deploy.
overlay="$HERE/../k8s/.generated"
mkdir -p "$overlay"
cat > "$overlay/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
  - ../aws
images:
  - name: taskboard-api
    newName: ${IMAGE%@*}
    digest: ${IMAGE#*@}
labels:
  - pairs:
      app.kubernetes.io/version: "$VERSION"
    includeTemplates: true
    includeSelectors: false
configMapGenerator:
  - name: pod-identity-demo
    namespace: taskboard
    literals:
      - PARAM=$(tf_output "$TF" demo_parameter)
    options:
      disableNameSuffixHash: true
YAML

info "Applying workloads with $IMAGE"
kubectl delete job -n taskboard pod-identity-demo --ignore-not-found >/dev/null   # Jobs are immutable
kubectl apply -k "$overlay"
kubectl rollout status -n taskboard deployment/taskboard --timeout=180s
kubectl wait -n taskboard --for=condition=complete job/pod-identity-demo --timeout=120s \
  || warn "pod identity demo did not complete: kubectl logs -n taskboard job/pod-identity-demo"
pass "deployed. Try: kubectl port-forward -n taskboard svc/taskboard 8080:80"
