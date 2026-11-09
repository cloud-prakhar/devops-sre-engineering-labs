# CLAUDE.md — working on this repository

Instructions for AI-assisted development sessions. Humans: see [CONTRIBUTING.md](CONTRIBUTING.md).

## What this repository is

A multi-cloud DevOps/SRE learning platform: 15 themes × 3 clouds = 45 projects, built in phases
(AWS → Azure → GCP → cross-cloud review). The catalog of record is
[catalog/projects.yaml](catalog/projects.yaml); the tracker
[docs/progress/implementation-tracker.md](docs/progress/implementation-tracker.md) is generated from it.

## Non-negotiable rules

1. **No unverified claims.** Never mark anything tested, validated or production-ready unless the check
   ran in this session and passed. `validation.deployment` stays `not-tested` until a human (or an
   approved session) actually deployed, verified and destroyed it, with a `deployment_record`.
2. **Never run paid or state-changing cloud commands without explicit approval in the current
   conversation**: no `terraform apply/destroy`, no resource-creating CLI calls. `terraform plan` also
   needs approval (it uses the account's credentials). `init -backend=false` and `validate` are fine.
3. **Free tier first (owner's instruction, 2026-11-09):** build AWS labs to fit the AWS Free Tier where
   the theme allows it; when a theme cannot be free (EKS control plane, NAT Gateway), say so in
   `cost.md` and the catalog's `free_tier` fields, and offer the cheapest honest variant.
4. **Mermaid only**, coloured with the palette in [docs/conventions.md](docs/conventions.md). No ASCII
   diagrams. Run `node scripts/mermaid/validate-mermaid.mjs` after any diagram change — `;` in sequence
   labels and a second `:` in state transitions break GitHub rendering.
5. **No placeholders or empty directories.** A planned project has a catalog entry only.
6. **No duplication.** Shared code → `shared/`; shared explanations → `docs/concepts/`.

## Layout

| Path | Contents |
|---|---|
| `projects/<cloud>/<NN>-<slug>/` | One lab: `README.md`, `terraform/`, `scripts/`, `files/` or `stack/`, `docs/{exercises,troubleshooting,interview,cost}.md`, `docs/adr/` |
| `shared/sample-apps/taskboard/` | The one app every lab deploys (FastAPI API + static frontend) |
| `shared/terraform-modules/aws/` | `lab-network` + `lab-host` (single free-tier host, AWS 01–04); `vpc` (multi-AZ, tiered SGs, NACL, S3 endpoint, `nat_mode` none/instance/gateway; AWS 04+) |
| `shared/cloud-init/` | Docker host cloud-init + `docker-daemon.json` |
| `shared/linux-service/` | Hardened `taskboard.service` + `install-taskboard.sh` (AWS 01 native install, AWS 05 instances) |
| `shared/scripts/` | `lib.sh` (helpers), `aws-preflight.sh`, `aws-find-lab-resources.sh`, `tf-init-backend.sh` (S3 backend from AWS 04 bootstrap) |
| `docs/concepts/` | Reusable concept guides (7-part structure) |
| `.github/workflows/aws-06-delivery.yml` | AWS 06 pipeline (lives at repo level because GitHub only reads workflows there); release/deploy only on `workflow_dispatch` + `vars.AWS06_ENABLED == 'true'` + environment `aws-06-lab` |
| `projects/aws/07-*/k8s/` | Kustomize bases (`base/`, `aws/`); `k8s/.generated/` is the git-ignored deploy overlay |
| `scripts/` | `validate.sh`, `catalog.py`, `check-links.py`, `mermaid/` |

## Conventions that are easy to get wrong

- Paths from a lab to the repo root are `../../../` (README) and `../../../../` (files in `docs/`,
  `terraform/`, `scripts/`).
- Tag every AWS resource through provider `default_tags`: `Repository=devops-sre-engineering-labs`,
  `Project=<cloud>-<NN>-<slug>` — the cleanup finder depends on it.
- `lab-host` validation: free-tier instance types only, root disk 8–30 GB, SSH CIDR never `0.0.0.0/0`.
- Scripts source `shared/scripts/lib.sh`, use `pass/fail/finish`, and test negative cases.
- Container runtime profile: non-root fixed UID, read-only root, `cap_drop: ALL`,
  `no-new-privileges`, resource limits.
- Interview questions use headings `## Q<N> (<Level>) — <question>`; `catalog.py` counts them and the
  index links to GitHub-style anchors (`scripts/check-links.py` verifies anchors).
- Troubleshooting entries use `## <N>. <title>`; at least five.
- Labs with several stacks keep them under `terraform/<stack>/`; `validate.sh` treats every directory
  with `.tf` files as a root module. Stacks with an S3 backend are rendered offline with a temporary
  local-backend override in a separate `TF_DATA_DIR`; values unknown before apply go in
  `local.user_data_placeholders` (see AWS 05 `asg.tf`).
- AWS 04+ stacks store state in the AWS 04 bootstrap bucket under `aws-NN/<stack>/terraform.tfstate`;
  initialise with `shared/scripts/tf-init-backend.sh <stack-dir>`.
- Secrets: generate with ephemeral resources and pass only to write-only arguments (`*_wo`); `verify.sh`
  asserts no secret is in state.
- Images are deployed by digest only (`repo@sha256:…`) — AWS 06 deploy script and AWS 07
  `deploy-workloads.sh` refuse tags. The shared API image ships without pip and applies Debian security
  updates at build time so the trivy gate (fixable HIGH/CRITICAL) passes.
- Kubernetes manifests must satisfy Pod Security `restricted` and pass `scripts/validate.sh kubernetes`;
  kustomize forbids absolute paths, so generated overlays live inside the repo (git-ignored).
- The environment blocks downloading and executing arbitrary binaries (e.g. the kind CLI); ask the owner
  before relying on one.
- `.github/workflows/external-links.yml` is **manual only** (`workflow_dispatch`) by owner decision — do not add a `schedule` trigger.

## Validation commands

```bash
scripts/validate.sh                       # all groups; Docker fallbacks for missing linters
scripts/validate.sh <group>               # terraform cloudinit shell docker yaml workflows kubernetes compose mermaid links catalog app secrets
python3 scripts/catalog.py validate       # structure of implemented projects + catalog consistency
python3 scripts/catalog.py tracker --write
projects/aws/02-dockerized-app-on-vm/scripts/local-test.sh
projects/aws/03-multi-service-docker-app/scripts/local-test.sh
```

Terraform init needs the AWS provider (~100 MB). Set `TF_PLUGIN_CACHE_DIR` to share it between labs.

## Pinned versions (verified 2026-11-09)

| Item | Version |
|---|---|
Owner instruction (2026-11-09): use the latest available versions, Python 3.14 for the app.

| Item | Version |
|---|---|
| Terraform | CI 1.17.1 (also validated locally with 1.15.6); `required_version` ≥ 1.9 (AWS 01–03), ≥ 1.10 (AWS 04, `use_lockfile`), ≥ 1.11 (AWS 05, write-only args); AWS provider `>= 6.0, < 7.0`, lock files at 6.72.0 |
| Python | 3.14 (image `python:3.14-slim-trixie`; on Ubuntu 24.04 hosts `python3.14` from the deadsnakes PPA) |
| Python deps | fastapi 0.162.2, uvicorn 0.54.0, psycopg[binary] 3.3.8, prometheus-client 0.26.0; dev: pytest 9.2.0, httpx2 2.16.0 |
| Images | `python:3.14-slim-trixie`, `nginxinc/nginx-unprivileged:1.31-alpine`, `postgres:18-alpine` (data under `/var/lib/postgresql/18/docker`), `alpine:3.23`, `node:26-alpine` |
| RDS | PostgreSQL major `18` (variable; fall back to 17 where not offered), db.t4g.micro |
| Linters (Docker) | hadolint v2.15.1, shellcheck v0.11.0, trivy 0.76.2, gitleaks v8.30.1, tflint v0.66.0, lychee 0.24.2, actionlint 1.7.12, kubeconform v0.8.0 (schemas 1.37.0); yamllint 1.38.0 |
| Kubernetes | EKS 1.37 (default/newest standard support on 2026-11-09 per `aws eks describe-cluster-versions`); add-ons resolved with `aws_eks_addon_version most_recent`; kind v0.33.0 / `kindest/node:v1.37.0` is the candidate local cluster (not yet allowed in this environment) |
| AWS 06 pipeline actions | configure-aws-credentials v6, amazon-ecr-login v2, attest-build-provenance v4, attest-sbom v4, upload-artifact v7; trivy run from its image, never a third-party action |
| Mermaid validation | mermaid 12.3.0 + jsdom 31.0.0 (needs Node ≥ 22.22; `validate.sh` falls back to `node:26-alpine`) |
| GitHub Actions | checkout v7, setup-python v7, setup-node v7, cache v6, setup-terraform v4; Python 3.14, Node 26 |

## Continuing the roadmap

Current state: Phase 0 done; AWS 01–07 implemented (static checks passed; AWS 02, 03, 06 local tests
passed; **none deployed**). Read-only AWS checks done on 2026-11-09: RDS PostgreSQL 18 (up to 18.6) is
orderable on db.t4g.micro in us-east-1; this account's free-tier-eligible types are t3.micro, t3.small,
t4g.micro, t4g.small, t8i.micro, t8i.small, c7i-flex.large, m7i-flex.large (no t2.micro).

Next steps, in order:

1. With the owner's approval, deploy-test AWS 01–07 (`apply` → `deploy.sh`/boot → `verify.sh` →
   `destroy`), fix what breaks, record `deployment_record`s. Highest-risk untested parts: deadsnakes
   PPA via cloud-init, AWS 05 boot within the 300 s grace period, NAT instance masquerading (AWS 04, 07),
   the AWS 06 workflow on GitHub (OIDC trust, attestations push to ECR), EKS add-on ordering (AWS 07).
2. AWS 08 Kubernetes networking and autoscaling on the AWS 07 cluster: AWS Load Balancer Controller via
   Pod Identity (Helm), Ingress (ALB, billed — document cost), HPA on metrics-server, PDBs, NetworkPolicy
   (VPC CNI network policy agent: `enableNetworkPolicy` in the vpc-cni add-on configuration), rolling
   updates. Reuse `k8s/base` and extend with overlays rather than copying manifests.
3. AWS 09–15.
4. For each new lab: copy `docs/templates/project-readme.md`, meet the definition of done in
   CONTRIBUTING.md, update the catalog (`status`, `path`, `validation`), regenerate the tracker,
   add questions to `docs/interview-preparation/README.md`.

At the end of every session, append to the session log in the tracker: files changed, projects
completed, commands actually run and their results, failures/blockers, what needs cloud credentials,
next project.
