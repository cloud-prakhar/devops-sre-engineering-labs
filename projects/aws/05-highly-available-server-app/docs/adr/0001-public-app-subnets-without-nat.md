# ADR-0001: App instances in public subnets, inbound only from the ALB, no NAT

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 05 |

## Context

App instances boot from source: they need outbound HTTPS/HTTP for Ubuntu and deadsnakes packages,
PyPI, the AWS CLI snap and SSM. Private subnets in the shared VPC module have no internet route by
default (AWS 04 ADR-0002). A NAT Gateway per AZ is the production answer and is never free; one NAT
instance would be a single point of failure in a lab whose whole point is removing them.

## Decision drivers

- No single point of failure in the app tier.
- Free-tier cost.
- Minimal exposure despite public addresses.

## Considered alternatives

| Option | Cost (2 AZs) | Availability | Exposure |
|---|---|---|---|
| **A. Public subnets, public IPs, SG: 8000 from web SG only, no SSH** | 2 × $0.005/h IPv4 | Per-AZ independent | Instances addressable on the internet but filtered to the ALB |
| B. Private subnets + one NAT Gateway per AZ | ≈ $0.09/h + data + 2 EIPs | Per-AZ independent | Not addressable |
| C. Private subnets + one NAT instance | free-tier hours | NAT is a SPOF for both AZs | Not addressable |
| D. Private subnets + pre-baked AMI + VPC endpoints (SSM, S3) | ≈ $0.06/h for 3 interface endpoints × 2 AZs | Per-AZ independent | Not addressable; needs an image pipeline |

## Decision

Option A. The launch template assigns a public IP, attaches only the module's `app` security group
(ingress: 8000 from `web` SG; egress: 80/443 and 5432 to `db` SG), enforces IMDSv2 with hop limit 1, and
the instance role grants Session Manager plus one parameter read. The database stays in private subnets.

## Consequences

**Positive:** the AZs fail independently; no NAT bill; the security group still blocks everything but
the load balancer.

**Negative:** public IPv4 charges per instance; a future SG mistake would expose instances directly.

**Risks and tradeoffs:** defence relies on a single control (the SG) for inbound — verified by
`verify.sh` ("instance :8000 not reachable"), and by AWS Config rules in production.

**Cost implications:** $0.01/h for two addresses vs ≈ $0.09/h + data for two NAT Gateways.

**Security implications:** no SSH keys exist for these instances at all.

## Revisit when

AWS 06 produces images in CI (option D becomes cheap and fast), or the lab is used beyond short sessions.
