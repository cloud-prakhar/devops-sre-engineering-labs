#!/usr/bin/env bash
# Lists every AWS resource still tagged by this repository, so you can confirm cleanup.
# Read-only. Usage: aws-find-lab-resources.sh [region ...]   (default: current region)
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_cmd aws

regions=("$@")
[[ ${#regions[@]} -eq 0 ]] && regions=("${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}")

found=0
for region in "${regions[@]}"; do
  info "Region $region"
  arns=$(aws resourcegroupstaggingapi get-resources --region "$region" \
    --tag-filters Key=Repository,Values=devops-sre-engineering-labs \
    --query 'ResourceTagMappingList[].[ResourceARN, Tags[?Key==`Project`]|[0].Value]' --output text)
  if [[ -n "$arns" ]]; then
    printf '%s\n' "$arns"
    found=1
  else
    pass "no tagged resources"
  fi
done
# The tagging API can lag a few minutes after deletion and does not list untaggable resources.
if (( found )); then
  warn "tagged resources remain — run 'terraform destroy' in the matching project"
  exit 1
fi
