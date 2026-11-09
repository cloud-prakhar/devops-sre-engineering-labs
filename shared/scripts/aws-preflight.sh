#!/usr/bin/env bash
# Preflight for AWS labs: tools, credentials, region, operator IP, free-tier reminders.
# Read-only: it calls STS and EC2 describe APIs only (no charges, no resources created).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}

info "Checking local tools"
for cmd in terraform aws ssh rsync curl; do
  if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd found"; else fail "$cmd missing"; fi
done
if command -v terraform >/dev/null 2>&1; then
  tf_ver=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
  if [[ "$(printf '%s\n' 1.9.0 "$tf_ver" | sort -V | head -n1)" != "1.9.0" ]]; then
    fail "terraform $tf_ver is older than 1.9.0"
  else
    pass "terraform $tf_ver"
  fi
fi

info "Checking AWS identity (region: $REGION)"
if identity=$(aws sts get-caller-identity --output text --query '[Account,Arn]' 2>&1); then
  pass "authenticated as: $identity"
  case "$identity" in
    *":root"*) warn "you are using the ROOT user. Create an IAM Identity Center or IAM user for labs." ;;
  esac
else
  fail "aws sts get-caller-identity failed: $identity"
fi

if aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[0].ZoneName' --output text >/dev/null 2>&1; then
  pass "EC2 API reachable in $REGION"
else
  fail "cannot call EC2 in $REGION (region disabled or no permission)"
fi

info "Detecting your public IP for security group rules"
if my_ip=$(curl -fsS --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]'); then
  pass "public IP $my_ip -> use allowed_ssh_cidrs = [\"$my_ip/32\"]"
else
  warn "could not detect public IP; set allowed_ssh_cidrs manually"
fi

info "SSH key"
key=${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}
if [[ -f "$key" ]]; then pass "found $key"; else warn "no $key — create one: ssh-keygen -t ed25519"; fi

cat <<'NOTE'

Free-tier reminders
  * Accounts created on/after 2025-07-15 use the credit-based Free plan; older accounts keep the
    12-month legacy free tier. Check yours: Billing console -> Free Tier.
  * Create a zero-spend or $1 budget alert BEFORE deploying: see docs/cost-and-free-tier.md.
  * Always run 'terraform destroy' at the end of a session.
NOTE
finish
