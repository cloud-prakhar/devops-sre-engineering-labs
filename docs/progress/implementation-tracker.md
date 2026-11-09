# Implementation tracker

Status of all 45 projects. The tables between the markers are **generated** from
[catalog/projects.yaml](../../catalog/projects.yaml) and the files on disk — do not edit them by hand:

```bash
python3 scripts/catalog.py tracker --write
```

Columns Docs → Interview are structural checks computed by `scripts/catalog.py` (required README
sections, Terraform present, scripts present, ≥ 2 README diagrams, ≥ 1 ADR, cost formula + cleanup,
≥ 5 troubleshooting incidents, 5–8 interview questions each with a diagram). Static / Local / Cloud
deploy come from the catalog's `validation` fields.

**Cloud deploy is "not tested" for every project.** No lab has been applied to a real cloud account yet.

<!-- tracker:begin -->
### AWS

| ID | Project | Free tier | Status | Docs | IaC | App/scripts | Diagrams | ADR | Cost | Troubleshooting | Interview | Static | Local | Cloud deploy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| aws-01 | [Linux Server Engineering](../../projects/aws/01-linux-server-engineering/) | fits | implemented | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ passed | n/a | ⏳ not tested |
| aws-02 | [Dockerized Application on Cloud VM](../../projects/aws/02-dockerized-app-on-vm/) | fits | implemented | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ passed | ✅ passed | ⏳ not tested |
| aws-03 | [Multi-Service Docker Application](../../projects/aws/03-multi-service-docker-app/) | fits | implemented | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ passed | ✅ passed | ⏳ not tested |
| aws-04 | [Terraform Networking Foundations](../../projects/aws/04-terraform-networking-foundations/) | fits | implemented | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ passed | n/a | ⏳ not tested |
| aws-05 | [Highly Available Server Application](../../projects/aws/05-highly-available-server-app/) | partial | implemented | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ passed | n/a | ⏳ not tested |
| aws-06 | Secure CI/CD and Container Registry | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-07 | Managed Kubernetes Foundations | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-08 | Kubernetes Networking and Autoscaling | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-09 | Helm and Argo CD GitOps | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-10 | Stateful Kubernetes Workloads | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-11 | Prometheus, Grafana and Alertmanager | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-12 | Centralized Logging with Elastic Stack | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-13 | Distributed Tracing | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-14 | SRE Failure and Recovery Lab | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| aws-15 | Production-Inspired DevOps/SRE Capstone | no | planned | — | — | — | — | — | — | — | — | — | — | — |

### AZURE

| ID | Project | Free tier | Status | Docs | IaC | App/scripts | Diagrams | ADR | Cost | Troubleshooting | Interview | Static | Local | Cloud deploy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| azure-01 | Linux Server Engineering | fits | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-02 | Dockerized Application on Cloud VM | fits | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-03 | Multi-Service Docker Application | fits | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-04 | Terraform Networking Foundations | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-05 | Highly Available Server Application | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-06 | Secure CI/CD and Container Registry | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-07 | Managed Kubernetes Foundations | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-08 | Kubernetes Networking and Autoscaling | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-09 | Helm and Argo CD GitOps | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-10 | Stateful Kubernetes Workloads | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-11 | Prometheus, Grafana and Alertmanager | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-12 | Centralized Logging with Elastic Stack | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-13 | Distributed Tracing | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-14 | SRE Failure and Recovery Lab | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| azure-15 | Production-Inspired DevOps/SRE Capstone | no | planned | — | — | — | — | — | — | — | — | — | — | — |

### GCP

| ID | Project | Free tier | Status | Docs | IaC | App/scripts | Diagrams | ADR | Cost | Troubleshooting | Interview | Static | Local | Cloud deploy |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| gcp-01 | Linux Server Engineering | fits | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-02 | Dockerized Application on Cloud VM | fits | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-03 | Multi-Service Docker Application | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-04 | Terraform Networking Foundations | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-05 | Highly Available Server Application | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-06 | Secure CI/CD and Container Registry | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-07 | Managed Kubernetes Foundations | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-08 | Kubernetes Networking and Autoscaling | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-09 | Helm and Argo CD GitOps | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-10 | Stateful Kubernetes Workloads | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-11 | Prometheus, Grafana and Alertmanager | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-12 | Centralized Logging with Elastic Stack | no | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-13 | Distributed Tracing | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-14 | SRE Failure and Recovery Lab | partial | planned | — | — | — | — | — | — | — | — | — | — | — |
| gcp-15 | Production-Inspired DevOps/SRE Capstone | no | planned | — | — | — | — | — | — | — | — | — | — | — |
<!-- tracker:end -->

## Session log

### 2026-11-09 — Phase 0 + AWS 01–03

**Implemented:** repository foundation (README, conventions, concepts, learning paths, interview
index, service mapping, catalog of 45, CI, validation scripts) and AWS 01, 02, 03.

**Validation actually run in this session (all passed on the final run):**

| Check | Tool / version | Result |
|---|---|---|
| Terraform fmt + `init -backend=false` + validate (AWS 01, 02, 03) | Terraform 1.15.6, AWS provider 6.x | passed |
| tflint (3 labs + 2 shared modules) | tflint v0.66.0, terraform ruleset | passed |
| IaC and Dockerfile security scan, HIGH/CRITICAL | trivy 0.75.0 | passed (one LOW, DS-0026, fixed) |
| Rendered user data vs cloud-init schema (3 labs) | cloud-init 26.2 on Ubuntu 24.04 | passed |
| `systemd-analyze verify taskboard.service` | systemd 255 | passed |
| ShellCheck, severity warning (21 scripts) | shellcheck v0.10.0 | passed |
| hadolint (3 Dockerfiles) | hadolint v2.12.0 | passed |
| yamllint | yamllint (repo config) | passed |
| `docker compose config` (AWS 03) | Compose v5.1.3 | passed |
| Mermaid parse (every diagram in every Markdown file) | mermaid 11.12.1 | passed |
| Relative links and heading anchors | `scripts/check-links.py` | passed |
| Catalog consistency + project standard | `scripts/catalog.py validate` | passed |
| Taskboard API unit tests (5) | pytest 9.2.0, Python 3.13 | passed |
| Secret scan of the working tree | gitleaks v8.30.1 | passed |
| AWS 02 `scripts/local-test.sh` (14 checks) | Docker 29.1.3 | passed |
| AWS 03 `scripts/local-test.sh` (19 checks) | Docker 29.1.3, Compose v5.1.3 | passed |

**Found and fixed during validation:** image pruning in `taskboard-ctl.sh` deleted unrelated local
images (now label-scoped); 5 Mermaid diagrams with `;`/`:` in labels that would not render on GitHub;
tflint failing when the SSH key file is absent (now a clear validation error); frontend/proxy
Dockerfiles missing explicit `USER`/`HEALTHCHECK`; an exercise that claimed a 500 where the stack can
return 504 (documented with the measured cause).

**Not run:** external link checking (lychee workflow is manual: run it from the Actions tab); the GitHub Actions workflows themselves
(they have not run on GitHub yet).

**Not done:** no `terraform plan` or `apply` against AWS (would use account credentials; requires the
owner's approval), so cloud-init on a real instance, `deploy.sh` and `verify.sh` are untested.

**Next:** deploy-test AWS 01–03 in a lab account (record results in the catalog's
`deployment_record`), then AWS 04.

### 2026-11-09 (session 2) — AWS 04, AWS 05, dependency upgrade

**Implemented:** AWS 04 Terraform Networking Foundations (bootstrap state bucket + network stack, shared
`vpc` module with `nat_mode` none/instance/gateway) and AWS 05 Highly Available Server Application
(ALB + Auto Scaling group across 2 AZs + single-AZ RDS PostgreSQL, write-only secrets). New concept
guides: VPC design, Terraform state and locking, load balancing and autoscaling. Shared additions:
`shared/linux-service/` (moved from AWS 01), `shared/scripts/tf-init-backend.sh`, `lab-host` options for
private hosts.

**Upgraded to latest versions (owner request):** Python 3.14 (image `python:3.14-slim-trixie`; deadsnakes
`python3.14` on Ubuntu 24.04 hosts), NGINX 1.31, PostgreSQL 18 (Compose volume moved to
`/var/lib/postgresql` for the 18 data layout), Alpine 3.23, `httpx` → `httpx2` 2.16.0, Terraform 1.17.1 in
CI, mermaid 12.3.0 + jsdom 31.0.0 (Node ≥ 22.22, CI Node 26), hadolint v2.15.1, shellcheck v0.11.0,
trivy 0.76.2, lychee 0.24.2, yamllint 1.38.0, GitHub Actions checkout/setup-python/setup-node v7,
cache v6, setup-terraform v4. Python packages were already at their latest releases.

**Validation actually run (final results, all passed):**

| Check | Result |
|---|---|
| `terraform validate` for all 6 stacks with Terraform 1.17.1 (container) and 1.15.6 (local) | passed |
| tflint (6 stacks + 3 shared modules) | passed (after removing an unused data source and annotating render placeholders) |
| trivy 0.76.2 config scan, HIGH/CRITICAL | passed (new AWS-0102 / AWS-0132 findings reviewed and ignored with written justification) |
| cloud-init 26.2 schema for 6 rendered user-data documents, incl. AWS 05 offline render | passed |
| `systemd-analyze verify` of the shared `taskboard.service` (now with `${TASKBOARD_HOST}`) | passed |
| Python 3.14.10 from deadsnakes on Ubuntu 24.04: venv + `pip install -r requirements-dev.txt` + pytest | 5 passed |
| ShellCheck v0.11.0 (all scripts), hadolint v2.15.1, yamllint, compose config, Mermaid (mermaid 12.3.0), links, catalog | passed |
| API unit tests (Python 3.14, httpx2) | 5 passed, no deprecation warnings |
| AWS 02 `local-test.sh` on Python 3.14 image | 14/14 passed |
| AWS 03 `local-test.sh` on Python 3.14 / NGINX 1.31 / PostgreSQL 18 | 19/19 passed |

**Bugs found by validation and fixed:** AWS 05 user data rendered `content: null` for the empty
`app/__init__.py` (would have failed on real instances) — package docstring added and a 14 KB gzipped
user-data size guard added to `validate.sh`; `validate.sh` leaked "undeclared variable" warnings into
rendered user data; trivy ignore for AWS-0132 was on the wrong resource.

**Not run / needs cloud credentials and approval:** `terraform plan/apply` for any lab. Unverified until
deployed: deadsnakes PPA through cloud-init on EC2, RDS PostgreSQL 18 on db.t4g.micro in the chosen
region, AWS 05 boot time vs the 300 s health-check grace period, NAT instance masquerading, S3 native
locking behaviour, every `verify.sh`.

**Next:** AWS 06 Secure CI/CD and Container Registry (plan in CLAUDE.md).
