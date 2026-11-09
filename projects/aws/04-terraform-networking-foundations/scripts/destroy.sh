#!/usr/bin/env bash
# Tears AWS 04 down in the only safe order: network first (its state lives in the bucket), then the
# bucket with every state version. Asks before deleting state history.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd terraform

BOOT="$HERE/../terraform/bootstrap"
NET="$HERE/../terraform/network"

info "Destroying the network stack"
terraform -chdir="$NET" destroy -input=false

read -r -p "Also delete the state bucket and ALL state versions (other labs may use it)? [y/N] " answer
if [[ "$answer" != [yY] ]]; then
  pass "network destroyed; state bucket kept"
  exit 0
fi
info "Allowing bucket deletion, then destroying the bootstrap stack"
terraform -chdir="$BOOT" apply -input=false -auto-approve -var force_destroy=true -target=aws_s3_bucket.state
terraform -chdir="$BOOT" destroy -input=false -var force_destroy=true
rm -f "$NET/backend.hcl"
"$ROOT/shared/scripts/aws-find-lab-resources.sh" || true
