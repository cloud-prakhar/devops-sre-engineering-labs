# Shared Terraform modules

Modules here are consumed by several projects through relative paths, so a fix lands everywhere at once.

| Module | Used by | What it creates | Free-tier notes |
|---|---|---|---|
| [aws/lab-network](aws/lab-network/) | AWS 01–03 | VPC, one public subnet, IGW, route table, locked default SG | No NAT Gateway (never free). No flow logs (billed). |
| [aws/lab-host](aws/lab-host/) | AWS 01–03 | Ubuntu 24.04 EC2, key pair, SG, SSM-only IAM role | Free-tier instance types only, `cpu_credits = "standard"`, root disk ≤ 30 GB, detailed monitoring off. |

```mermaid
flowchart LR
    proj[projects/aws/0X/terraform]:::app --> net[lab-network]:::net
    proj --> host[lab-host]:::k8s
    net -->|vpc_id, public_subnet_id| host
    host --> iam[IAM role<br/>SSM only]:::sec
    host --> sg[Security group<br/>operator CIDRs]:::sec
    host --> ec2[EC2 t3.micro<br/>IMDSv2, encrypted gp3]:::app
    classDef net fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef app fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef k8s fill:#ede9fe,stroke:#6d28d9,color:#4c1d95
    classDef sec fill:#ffedd5,stroke:#c2410c,color:#7c2d12
```

Rules for changing a shared module:

1. Keep inputs backward compatible, or update every caller in the same change.
2. Run `scripts/validate.sh terraform` — it validates every project that consumes the module.
3. Do not add resources that are billed by default; make them opt-in variables.
