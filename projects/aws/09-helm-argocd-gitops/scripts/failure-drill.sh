#!/usr/bin/env bash
# Opt-in GitOps drills on the lab cluster.
#   scripts/failure-drill.sh list | drift | delete | bad-release | rollback
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

case "${1:-list}" in
  list)
    cat <<'LIST'
drift        Change dev and prod by hand -> dev self-heals, prod shows OutOfSync until synced
delete       Delete the dev Deployment -> Argo CD recreates it
bad-release  Commit a digest that does not exist to dev -> Degraded (ImagePullBackOff); fix with rollback
rollback     git revert the last promotion commit and push -> dev returns to the previous digest
LIST
    ;;
  drift)
    kubectl -n taskboard-dev set env deploy/taskboard LOG_LEVEL=WARNING
    kubectl -n taskboard-prod set env deploy/taskboard LOG_LEVEL=WARNING 2>/dev/null || echo "prod not synced yet"
    echo "watch: kubectl -n argocd get applications -w" ;;
  delete) kubectl -n taskboard-dev delete deploy taskboard ;;
  bad-release)
    repo=$(sed -n 's/^  repository: //p' "$HERE/../environments/dev/values.yaml")
    "$HERE/promote.sh" dev --image "$repo@sha256:$(printf 'f%.0s' $(seq 1 64))" ;;
  rollback)
    cd "$HERE/../../../.."
    last=$(git log -n1 --format=%H -- projects/aws/09-helm-argocd-gitops/environments/dev/values.yaml)
    git revert --no-edit "$last" && git push ;;
  *) echo "unknown drill: $1" >&2; exit 1 ;;
esac
