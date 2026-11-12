#!/usr/bin/env bash
# GitOps promotion: changes an environment's values file and commits it. Argo CD does the deploying.
#   scripts/promote.sh dev                       newest image in AWS 06's ECR repository
#   scripts/promote.sh dev --image <repo@sha256:...>
#   scripts/promote.sh prod --from dev           promote exactly what dev runs
# Pushes only after confirmation (or with --yes).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=../../../../shared/scripts/lib.sh
source "$ROOT/shared/scripts/lib.sh"
require_cmd git python3

ENV=${1:?usage: promote.sh <dev|prod> [--image repo@sha256:... | --from <env>] [--yes]}
shift
IMAGE="" FROM="" YES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE=$2; shift 2 ;;
    --from)  FROM=$2; shift 2 ;;
    --yes)   YES=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
FILE="$HERE/../environments/$ENV/values.yaml"
[[ -f "$FILE" ]] || die "no such environment: $ENV"

read_image() { # read_image <values-file> -> repo@digest
  python3 - "$1" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
repo = re.search(r"^  repository: (\S+)", s, re.M).group(1)
dig = re.search(r"^  digest: (\S+)", s, re.M).group(1)
print(f"{repo}@{dig}")
PY
}

if [[ -n "$FROM" ]]; then
  IMAGE=$(read_image "$HERE/../environments/$FROM/values.yaml")
elif [[ -z "$IMAGE" ]]; then
  require_cmd aws
  IMAGE=$(latest_ecr_image) || die "no image in ECR: run the AWS 06 pipeline, or pass --image"
fi
[[ "$IMAGE" =~ ^[a-z0-9.:/_-]+@sha256:[0-9a-f]{64}$ ]] || die "not a digest reference: $IMAGE"
[[ "$IMAGE" != *@sha256:0000000000000000* ]] || die "source environment still has the initial placeholder digest"

python3 - "$FILE" "${IMAGE%@*}" "${IMAGE#*@}" <<'PY'
import re, sys
path, repo, digest = sys.argv[1:4]
s = open(path).read()
s = re.sub(r"^(  repository: ).*$", r"\g<1>" + repo, s, count=1, flags=re.M)
s = re.sub(r"^(  digest: ).*$", r"\g<1>" + digest, s, count=1, flags=re.M)
s = re.sub(r"^(version: ).*$", r"\g<1>" + digest.split(":")[1][:12], s, count=1, flags=re.M)
open(path, "w").write(s)
PY

cd "$ROOT"
git --no-pager diff -- "$FILE"
if git diff --quiet -- "$FILE"; then pass "$ENV already runs $IMAGE"; exit 0; fi
git add "$FILE"
git commit -q -m "Promote taskboard to $ENV: ${IMAGE#*@}" -- "$FILE"
pass "committed promotion of $ENV"
if [[ -z "$YES" ]]; then
  read -r -p "git push to $(git rev-parse --abbrev-ref HEAD)? [y/N] " answer
  [[ "$answer" == [yY] ]] || { warn "not pushed: Argo CD will not see it until you push"; exit 0; }
fi
git push
pass "pushed; Argo CD picks it up within ~60 s (dev syncs itself, prod waits for scripts/sync-prod.sh)"
