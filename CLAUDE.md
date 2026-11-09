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
| `shared/terraform-modules/aws/` | `lab-network`, `lab-host` (free-tier single host) |
| `shared/cloud-init/` | Docker host cloud-init + `docker-daemon.json` |
| `shared/scripts/` | `lib.sh` (helpers), `aws-preflight.sh`, `aws-find-lab-resources.sh` |
| `docs/concepts/` | Reusable concept guides (7-part structure) |
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
- `.github/workflows/external-links.yml` is **manual only** (`workflow_dispatch`) by owner decision — do not add a `schedule` trigger.

## Validation commands

```bash
scripts/validate.sh                       # all groups; Docker fallbacks for missing linters
scripts/validate.sh <group>               # terraform cloudinit shell docker yaml compose mermaid links catalog app secrets
python3 scripts/catalog.py validate       # structure of implemented projects + catalog consistency
python3 scripts/catalog.py tracker --write
projects/aws/02-dockerized-app-on-vm/scripts/local-test.sh
projects/aws/03-multi-service-docker-app/scripts/local-test.sh
```

Terraform init needs the AWS provider (~100 MB). Set `TF_PLUGIN_CACHE_DIR` to share it between labs.

## Pinned versions (verified 2026-11-09)

| Item | Version |
|---|---|
| Terraform | ≥ 1.9 (tested 1.15.6); AWS provider `>= 6.0, < 7.0` (lock file 6.x) |
| Python deps | fastapi 0.162.2, uvicorn 0.54.0, psycopg 3.3.8, prometheus-client 0.26.0 |
| Images | `python:3.13-slim-trixie`, `nginxinc/nginx-unprivileged:1.28-alpine`, `postgres:17-alpine`, `alpine:3.22` |
| Linters (Docker) | hadolint v2.12.0, shellcheck v0.10.0, trivy 0.75.0, gitleaks v8.30.1, tflint v0.66.0 |
| Mermaid validation | mermaid 11.12.1 + jsdom 26.1.0 (`scripts/mermaid/package.json`) |

## Continuing the roadmap

Current state: Phase 0 done; AWS 01–03 implemented (static + local tests passed; **not deployed**).

Next steps, in order:

1. With the owner's approval, deploy-test AWS 01–03 (`apply` → `deploy.sh` → `verify.sh` → `destroy`),
   fix what breaks, record `deployment_record`s.
2. AWS 04 Terraform networking: public/private subnets across 2 AZs, remote state in S3 with native
   lock file (`use_lockfile = true`), NAT as an opt-in variable (NAT Gateway is never free — offer a
   NAT-less default and document the tradeoff). Add concept guides for VPC design and remote state.
3. AWS 05–06, then 07–15 (EKS is never free: document cost per hour and keep sessions short).
4. For each new lab: copy `docs/templates/project-readme.md`, meet the definition of done in
   CONTRIBUTING.md, update the catalog (`status`, `path`, `validation`), regenerate the tracker,
   add questions to `docs/interview-preparation/README.md`.

At the end of every session, append to the session log in the tracker: files changed, projects
completed, commands actually run and their results, failures/blockers, what needs cloud credentials,
next project.
