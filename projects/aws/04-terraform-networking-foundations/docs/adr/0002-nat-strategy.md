# ADR-0002: Default to no NAT, offer a NAT instance or one NAT Gateway as opt-ins

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | Shared `vpc` module; AWS 04 and later |

## Context

Private subnets have no internet route. Production designs give each AZ its own NAT Gateway, but NAT
Gateways are billed hourly and per GB and are never covered by the free tier — about $33 a month each
before data. The owner asked for free-tier-first labs. Many private workloads only need AWS services
(S3), which a free gateway endpoint provides.

## Decision drivers

- Zero cost by default.
- Learners must still see real NAT behaviour and its tradeoffs.
- Honest representation of the production pattern.

## Considered alternatives

| Option | Cost | Availability | Notes |
|---|---|---|---|
| **A. `none` + S3 gateway endpoint (default)** | $0 | n/a | Private hosts reach S3 only; package installs need another path |
| **B. `instance`: one t3.micro NAT instance** | free-tier hours | Single point of failure for all AZs | Fully inspectable (`nft`, `sysctl`), `source_dest_check = false` |
| **C. `gateway`: one NAT Gateway** | ≈ $0.045/h + $0.045/GB | Zonal; other AZs depend on its AZ | Managed, scales automatically |
| D. One NAT Gateway per AZ | ≈ $0.045/h × AZs + data | AZ-independent | Production pattern; documented, not offered as a toggle to avoid accidental cost |
| E. Interface endpoints for SSM/ECR/STS | ≈ $0.01/h per endpoint per AZ | Per-AZ | Removes NAT for AWS APIs; introduced when EKS needs them |

## Decision

`nat_mode` with values `none` (default), `instance`, `gateway`. Private route tables are already one
per AZ, so moving to a NAT per AZ later only changes the route targets. The S3 gateway endpoint is
always on.

## Consequences

**Positive:** free by default; learners compare all three behaviours with the same `verify.sh`.

**Negative:** with `none`, private hosts cannot install packages — AWS 05 therefore keeps app instances
in public subnets with inbound restricted to the load balancer (its ADR explains why).

**Risks and tradeoffs:** `instance` and `gateway` route every AZ through AZ a: an AZ a outage removes
egress everywhere, and AZ b traffic pays cross-AZ transfer.

**Cost implications:** see [cost](../cost.md): ≈ $0.08 / $0.13 / $0.23 per 3-hour session.

**Security implications:** no NAT means no exfiltration path to the internet from private subnets —
a security benefit worth keeping for data tiers.
