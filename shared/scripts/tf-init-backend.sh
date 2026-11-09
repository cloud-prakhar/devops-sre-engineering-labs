#!/usr/bin/env bash
# Points a stack at the shared S3 state bucket created by AWS 04's bootstrap stack:
# writes <stack-dir>/backend.hcl from the bootstrap outputs, then runs terraform init.
# Usage: shared/scripts/tf-init-backend.sh <stack-dir> [-migrate-state | -reconfigure | -upgrade]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_cmd terraform

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BOOT="$ROOT/projects/aws/04-terraform-networking-foundations/terraform/bootstrap"
STACK=${1:?usage: tf-init-backend.sh <stack-dir> [terraform init flags]}
shift
[[ -d "$STACK" ]] || die "no such stack directory: $STACK"

info "Reading the state bucket from $BOOT"
tf_output "$BOOT" backend_config > "$STACK/backend.hcl"
sed 's/^/    /' "$STACK/backend.hcl"

info "terraform init $STACK (S3 backend, native lock file)"
terraform -chdir="$STACK" init -input=false -backend-config=backend.hcl "$@"
key=$(sed -n 's/^ *key *= *"\(.*\)"/\1/p' "$STACK"/*.tf | head -n1)
pass "state: s3://$(tf_output "$BOOT" bucket)/${key}"
