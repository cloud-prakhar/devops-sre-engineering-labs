#!/usr/bin/env bash
# Connects your GitHub fork to the AWS 06 infrastructure:
#   1. creates the "aws-06-lab" Environment with YOU as required reviewer, deployable from main only
#   2. sets the repository variables the workflow reads (from terraform output github_variables)
# Changes GitHub settings of the repository you name; asks before doing so.
# Usage: scripts/configure-github.sh [owner/repo]     (default: the github_repository tfvar)
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd gh terraform jq

TF="$HERE/../terraform"
REPO=${1:-$(terraform -chdir="$TF" console <<<'var.github_repository' | tr -d '"')}
ENV_NAME=$(terraform -chdir="$TF" console <<<'var.github_environment' | tr -d '"')
vars=$(terraform -chdir="$TF" output -json github_variables)
me=$(gh api user --jq .id)

info "Repository: $REPO   Environment: $ENV_NAME   Reviewer: $(gh api user --jq .login)"
jq -r 'to_entries[] | "  \(.key) = \(.value)"' <<<"$vars"
read -r -p "Apply these GitHub settings? [y/N] " answer
[[ "$answer" == [yY] ]] || die "aborted"

info "Environment with required reviewer and a main-only deployment branch policy"
gh api -X PUT "repos/$REPO/environments/$ENV_NAME" --input - >/dev/null <<JSON
{"reviewers":[{"type":"User","id":$me}],
 "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
JSON
gh api -X POST "repos/$REPO/environments/$ENV_NAME/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 \
  || warn "branch policy 'main' already exists"
pass "environment $ENV_NAME configured"

info "Repository variables (not secrets: there are no secrets — OIDC replaces access keys)"
jq -r 'to_entries[] | "\(.key)\t\(.value)"' <<<"$vars" | while IFS=$'\t' read -r k v; do
  gh variable set "$k" --repo "$REPO" --body "$v" && pass "$k"
done

cat <<NEXT

Next: Actions -> aws-06-delivery -> Run workflow (branch main). Approve the release and deploy jobs
when GitHub asks. To disconnect later: gh variable set AWS06_ENABLED --repo $REPO --body false
NEXT
