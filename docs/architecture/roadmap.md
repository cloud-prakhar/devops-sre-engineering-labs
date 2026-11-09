# Roadmap architecture: how the 15 themes build on each other

The same dependency graph applies to every cloud. A project's `depends_on` in
[catalog/projects.yaml](../../catalog/projects.yaml) follows these edges.

```mermaid
flowchart LR
    p01[01 Linux]:::sec --> p02[02 Docker on VM]:::app --> p03[03 Compose stack]:::app
    p01 --> p04[04 Terraform networking]:::net
    p02 --> p05[05 HA server app]:::app
    p04 --> p05
    p02 --> p06[06 Secure CI/CD]:::sec
    p04 --> p07[07 Managed Kubernetes]:::k8s --> p08[08 K8s networking + autoscaling]:::k8s
    p06 --> p09[09 Helm + Argo CD]:::k8s
    p08 --> p09
    p08 --> p10[10 Stateful workloads]:::data
    p08 --> p11[11 Prometheus / Grafana]:::obs
    p08 --> p12[12 Elastic logging]:::obs
    p11 --> p13[13 Tracing]:::obs
    p11 --> p14[14 SRE failure lab]:::risk
    p12 --> p14
    p09 & p10 & p13 & p14 --> p15[15 Capstone]:::k8s
    classDef sec fill:#ffedd5,stroke:#c2410c,color:#7c2d12
    classDef app fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef net fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef k8s fill:#ede9fe,stroke:#6d28d9,color:#4c1d95
    classDef data fill:#fef9c3,stroke:#a16207,color:#713f12
    classDef obs fill:#ccfbf1,stroke:#0f766e,color:#134e4a
    classDef risk fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
```

## What carries forward

| Artefact | Introduced | Reused by |
|---|---|---|
| Taskboard app (`/healthz`, `/readyz`, `/metrics`, JSON logs) | shared | every lab; `/metrics` scraped in 11, JSON logs parsed in 12, instrumented in 13 |
| `lab-network`, `lab-host` modules | AWS 01 | AWS 02–03; replaced by the full network module in AWS 04 |
| Docker host cloud-init | AWS 02 | AWS 03 |
| Hardened container profile | AWS 02 | AWS 03 Compose anchor → Kubernetes `securityContext` in 08 |
| Health-gated rollout + rollback | AWS 02 | ALB health checks (05), Kubernetes rolling updates (08), Argo CD (09) |
| Two-tier network isolation | AWS 03 | private subnets (04), NetworkPolicy (08) |
| Backup / restore drill | AWS 03 | volume snapshots (10), DR in capstone (15) |
| Failure-injection pattern (opt-in, self-reverting) | AWS 01 | AWS 03 drills, SRE lab (14) |

## Extension points

The layout is designed so new tracks fit without restructuring:

| Future track | Where it plugs in |
|---|---|
| DevSecOps (SBOM, signing, policy-as-code) | Extends 06 and 09; new concept guides; new catalog entries numbered 16+ |
| Advanced platform engineering (internal developer platform) | Builds on 09 and 15 |
| Service mesh | Builds on 08 and 13 |
| FinOps | Each `cost.md` already records rates and formulas; a FinOps track aggregates them |
| AI infrastructure (GPU node pools, model serving) | Builds on 07, 08 and 11 |

New tracks get new catalog entries and directories under `projects/<cloud>/`; nothing existing moves.
