# Repository conventions

These rules keep 45 projects consistent. CI and `scripts/catalog.py validate` enforce the structural
ones; reviewers enforce the rest.

## Project layout

```text
projects/<cloud>/<NN>-<slug>/
├── README.md            overview, architecture, concepts, deploy, verify, cleanup, repeat practice
├── terraform/           *.tf, terraform.tfvars.example, .terraform.lock.hcl
├── scripts/             deploy.sh, verify.sh, local-test.sh (when something can run locally)
├── files/ or stack/     anything copied to hosts (configs, units, compose files)
└── docs/
    ├── exercises.md     hands-on modules with expected results
    ├── troubleshooting.md   ≥ 5 incidents: symptoms, causes, diagnosis, meaning, fix, prevention
    ├── interview.md     5–8 questions, each with a Mermaid diagram and follow-ups
    ├── cost.md          assumptions, rates, formula, free-tier fit, cleanup
    └── adr/NNNN-*.md    ≥ 1 Architecture Decision Record
```

This is a directory listing, not an architecture diagram. Architecture is always drawn in Mermaid.

Shared, reusable material lives in `shared/` (code) and `docs/concepts/` (explanations). If two
projects need the same file, move it to `shared/` instead of copying it.

## Mermaid diagrams

- All diagrams are Mermaid. No ASCII art, PlantUML or image-only diagrams.
- Use the diagram type that fits: `flowchart` (architecture, traffic), `sequenceDiagram` (requests,
  incidents), `stateDiagram-v2` (lifecycles, recovery).
- Every flowchart defines colours with `classDef` from this palette:

| Class | Meaning | Definition |
|---|---|---|
| `client` / `net` | Clients, networking | `fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a` (blue) |
| `app` | Application workloads | `fill:#dcfce7,stroke:#15803d,color:#14532d` (green) |
| `k8s` | Orchestration, schedulers, IaC engines | `fill:#ede9fe,stroke:#6d28d9,color:#4c1d95` (purple) |
| `sec` | Security, IAM, firewalls | `fill:#ffedd5,stroke:#c2410c,color:#7c2d12` (orange) |
| `data` | Databases, storage, artefacts | `fill:#fef9c3,stroke:#a16207,color:#713f12` (yellow) |
| `risk` | Failures, risks, alerts | `fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d` (red) |
| `obs` | Monitoring, logs, observability | `fill:#ccfbf1,stroke:#0f766e,color:#134e4a` (teal) |

- Labels must not contain `;` in sequence diagrams or a second `:` in state transitions — both break
  parsing. `scripts/validate.sh mermaid` catches this.
- A diagram must explain something (components and connections, order of events, states). Each
  diagram is followed by a walkthrough or table.

## Terraform

- `required_version >= 1.9.0`; AWS provider `>= 6.0.0, < 7.0.0`; commit `.terraform.lock.hcl`.
- Provider `default_tags` on every project: `Repository`, `Project` (`<cloud>-<NN>-<slug>`),
  `ManagedBy`, `Owner`, `CostCenter`.
- Inputs that could expose or bill something are validated (`0.0.0.0/0` for SSH, instance types, disk size).
- `terraform.tfvars` is git-ignored; ship `terraform.tfvars.example`.
- Local state for AWS 01–03 only; remote state with locking from AWS 04 on.

## Scripts

- Bash with `set -euo pipefail`, sourcing [shared/scripts/lib.sh](../shared/scripts/lib.sh) for
  `info/pass/warn/fail/finish`, SSH options and Terraform outputs.
- `verify.sh` checks both what must work and what must **not** work (closed ports, refused logins).
- Failure-injection scripts are opt-in, scoped to lab resources, and revertible.
- Must pass ShellCheck.

## Containers

- Pin base images to a specific tag (and to a digest once a registry is used, AWS 06).
- Non-root, fixed UID; `HEALTHCHECK`; exec-form `CMD`.
- Runtime: read-only root, `cap_drop: ALL`, `no-new-privileges`, resource limits.
- Must pass hadolint.

## Status and claims

Never claim more than was verified. Status lives in [catalog/projects.yaml](../catalog/projects.yaml):

| Field | Allowed values | Rule |
|---|---|---|
| `status` | `planned`, `implemented`, `deployment-tested` | `implemented` requires the structural checks to pass |
| `validation.static` | `passed`, `failed`, `not-run` | Result of `scripts/validate.sh` |
| `validation.local` | `passed`, `failed`, `not-run`, `n/a` | Result of `scripts/local-test.sh` |
| `validation.deployment` | `passed`, `failed`, `not-tested` | `passed` requires a `deployment_record` (date, region, verify output) |

Prices are "reference rates" unless verified against the live price list on a stated date.

## Writing style

- Explain the problem before the tool. Prefer tables and short paragraphs over long prose.
- Link to official documentation instead of copying it.
- Every command block should be runnable as written (placeholders in `<angle-brackets>`).
- No filler: if a section does not help someone learn, deploy, troubleshoot or interview, remove it.
