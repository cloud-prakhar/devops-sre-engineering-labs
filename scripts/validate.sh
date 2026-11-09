#!/usr/bin/env bash
# Runs the repository's static checks locally. Uses a native tool when installed, otherwise the
# pinned Docker image. Nothing here talks to a cloud provider.
#
#   scripts/validate.sh                 all groups
#   scripts/validate.sh terraform shell one or more groups:
#     terraform cloudinit shell docker yaml compose mermaid links catalog app secrets
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1

HADOLINT_IMAGE=hadolint/hadolint:v2.12.0
SHELLCHECK_IMAGE=koalaman/shellcheck:v0.10.0
TFLINT_IMAGE=ghcr.io/terraform-linters/tflint:v0.66.0
TRIVY_IMAGE=aquasec/trivy:0.75.0
GITLEAKS_IMAGE=zricethezav/gitleaks:v8.30.1
PYTHON_IMAGE=python:3.13-slim-trixie

results=()
record() { results+=("$1|$([[ $2 -eq 0 ]] && echo PASS || echo FAIL)"); }   # group, exit status
have() { command -v "$1" >/dev/null 2>&1; }
dockerized() { docker run --rm -v "$ROOT:/repo" -w /repo "$@"; }
section() { printf '\n\033[34m== %s\033[0m\n' "$1"; }

tf_dirs() { find projects -type d -name terraform -not -path '*/.terraform/*' | sort; }
shell_files() { git ls-files -co --exclude-standard -- '*.sh' 2>/dev/null || find . -name '*.sh' -not -path './scripts/mermaid/node_modules/*'; }

run_terraform() {
  section "terraform: fmt, init -backend=false, validate, tflint, trivy"
  local ok=0 d
  terraform fmt -check -recursive -diff || ok=1
  for d in $(tf_dirs); do
    if terraform -chdir="$d" init -backend=false -input=false -no-color >/dev/null \
       && terraform -chdir="$d" validate -no-color >/dev/null; then
      echo "valid: $d"
    else
      echo "INVALID: $d"; terraform -chdir="$d" validate -no-color; ok=1
    fi
  done
  for d in $(tf_dirs) shared/terraform-modules/aws/*; do
    if have tflint; then tflint --chdir="$d" --config="$ROOT/.tflint.hcl" || ok=1
    else dockerized --entrypoint tflint "$TFLINT_IMAGE" --chdir="$d" --config=/repo/.tflint.hcl || ok=1; fi
  done
  echo "trivy config scan (HIGH, CRITICAL)"
  if have trivy; then trivy config --quiet --severity HIGH,CRITICAL --exit-code 1 --skip-dirs '**/.terraform' . || ok=1
  else dockerized "$TRIVY_IMAGE" config --quiet --severity HIGH,CRITICAL --exit-code 1 --skip-dirs '**/.terraform' /repo || ok=1; fi
  record terraform "$ok"
}

run_shell() {
  section "shell: shellcheck"
  local ok=0 files
  mapfile -t files < <(shell_files)
  # Severity "warning": style notes such as SC2015 (A && B || C with a B that always succeeds)
  # and SC2317 (functions called indirectly via "run_$group") are intentional here.
  if have shellcheck; then shellcheck -x -S warning "${files[@]}" || ok=1
  else dockerized "$SHELLCHECK_IMAGE" -x -S warning "${files[@]}" || ok=1; fi
  echo "${#files[@]} script(s) checked"
  record shell "$ok"
}

run_docker() {
  section "docker: hadolint"
  local ok=0 f
  while read -r f; do
    echo "hadolint $f"
    if have hadolint; then hadolint --config .hadolint.yaml "$f" || ok=1
    else docker run --rm -i -v "$ROOT/.hadolint.yaml:/.config/hadolint.yaml:ro" "$HADOLINT_IMAGE" hadolint --config /.config/hadolint.yaml - < "$f" || ok=1; fi
  done < <(find . -name Dockerfile -not -path '*/node_modules/*' | sort)
  record docker "$ok"
}

run_yaml() {
  section "yaml: yamllint"
  local ok=0
  if have yamllint; then yamllint -s . || ok=1
  else dockerized --entrypoint sh "$PYTHON_IMAGE" -c 'pip -q install yamllint==1.37.1 && yamllint -s .' || ok=1; fi
  record yaml "$ok"
}

run_compose() {
  section "compose: docker compose config"
  local ok=0 f dir
  while read -r f; do
    dir=$(dirname "$f")
    # Secrets must exist for config to resolve; use a throwaway file if none was generated.
    local tmp=""
    if [[ ! -f "$dir/secrets/db_password.txt" ]]; then
      mkdir -p "$dir/secrets"; echo "validate-only" > "$dir/secrets/db_password.txt"; tmp=1
    fi
    if docker compose -f "$f" config -q; then echo "valid: $f"; else ok=1; fi
    [[ -n "$tmp" ]] && rm -rf "$dir/secrets"
  done < <(find projects -name 'compose.yaml' | sort)
  record compose "$ok"
}

run_mermaid() {
  section "mermaid: parse every diagram"
  local ok=0
  if [[ ! -d scripts/mermaid/node_modules ]]; then (cd scripts/mermaid && npm ci --no-audit --no-fund --silent) || ok=1; fi
  node scripts/mermaid/validate-mermaid.mjs || ok=1
  record mermaid "$ok"
}

run_links() {
  section "links: relative links and anchors"
  local ok=0
  python3 scripts/check-links.py || ok=1
  record links "$ok"
}

run_catalog() {
  section "catalog: structure + tracker up to date"
  local ok=0 before
  python3 scripts/catalog.py validate || ok=1
  before=$(sha256sum docs/progress/implementation-tracker.md)
  python3 scripts/catalog.py tracker --write >/dev/null
  if [[ "$before" != "$(sha256sum docs/progress/implementation-tracker.md)" ]]; then
    echo "tracker was out of date (regenerated now; commit the change)"; ok=1
  fi
  record catalog "$ok"
}

run_app() {
  section "app: Taskboard unit tests"
  local ok=0 dir=shared/sample-apps/taskboard/api
  if python3 -c 'import fastapi, pytest, httpx, psycopg, prometheus_client' 2>/dev/null; then
    (cd "$dir" && python3 -m pytest -q -p no:cacheprovider) || ok=1
  else
    docker run --rm -v "$ROOT/$dir:/src:ro" -w /tmp "$PYTHON_IMAGE" sh -c \
      'cp -r /src /tmp/app && cd /tmp/app && pip -q install --disable-pip-version-check -r requirements-dev.txt && python -m pytest -q -p no:cacheprovider' || ok=1
  fi
  record app "$ok"
}

run_cloudinit() {
  section "cloudinit: render user data with Terraform, check schema; systemd-analyze verify units"
  local ok=0 d out tmp
  tmp=$(mktemp -d)
  ssh-keygen -q -t ed25519 -N '' -f "$tmp/key" -C validate-only
  mkdir -p "$tmp/ci" "$tmp/units"
  for d in $(tf_dirs); do
    out="$tmp/ci/$(basename "$(dirname "$d")").yaml"
    terraform -chdir="$d" init -backend=false -input=false >/dev/null || { ok=1; continue; }
    # terraform console prints heredoc markers around multi-line strings; strip them.
    if echo 'local.user_data' | terraform -chdir="$d" console \
         -var 'allowed_ssh_cidrs=["203.0.113.10/32"]' -var "ssh_public_key_path=$tmp/key.pub" \
         | sed -e '/^<<EOT$/d' -e '/^EOT$/d' > "$out" && [[ -s "$out" ]]; then
      echo "rendered: $d"
    else
      echo "RENDER FAILED: $d"; ok=1
    fi
  done
  find projects -name '*.service' -path '*/files/*' -exec cp {} "$tmp/units/" \;
  docker run --rm -v "$tmp:/t:ro" ubuntu:24.04 bash -c '
    set -u; rc=0
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null && apt-get install -y -qq cloud-init systemd >/dev/null 2>&1
    echo "cloud-init $(cloud-init --version 2>&1 | cut -d" " -f2), $(systemd --version | head -n1)"
    for f in /t/ci/*.yaml; do cloud-init schema -c "$f" --annotate || rc=1; done
    # Units reference a service user and binaries created at install time; stub them.
    useradd --system taskboard
    install -d /opt/taskboard/app /opt/taskboard/venv/bin
    printf "#!/bin/sh\n" > /opt/taskboard/venv/bin/uvicorn && chmod +x /opt/taskboard/venv/bin/uvicorn
    for u in /t/units/*.service; do
      [ -e "$u" ] || continue
      cp "$u" /etc/systemd/system/
      systemd-analyze verify "/etc/systemd/system/$(basename "$u")" && echo "unit ok: $(basename "$u")" || rc=1
    done
    exit $rc' || ok=1
  rm -rf "$tmp"
  record cloudinit "$ok"
}

run_secrets() {
  section "secrets: gitleaks (working tree)"
  local ok=0
  if have gitleaks; then gitleaks dir --redact --no-banner --exit-code 1 . || ok=1
  else dockerized "$GITLEAKS_IMAGE" dir --redact --no-banner --exit-code 1 /repo || ok=1; fi
  record secrets "$ok"
}

groups=("$@")
[[ ${#groups[@]} -eq 0 ]] && groups=(terraform cloudinit shell docker yaml compose mermaid links catalog app secrets)
for g in "${groups[@]}"; do
  case "$g" in
    terraform|cloudinit|shell|docker|yaml|compose|mermaid|links|catalog|app|secrets) "run_$g" ;;
    *) echo "unknown group: $g"; exit 2 ;;
  esac
done

section "summary"
failed=0
for r in "${results[@]}"; do
  printf '  %-10s %s\n' "${r%%|*}" "${r##*|}"
  [[ "${r##*|}" == FAIL ]] && failed=1
done
exit $failed
