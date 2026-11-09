# ADR-0002: Nodes in private subnets, egress through a NAT instance by default

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 07 |

## Context

Nodes must pull images (ECR, `public.ecr.aws`) and reach the EKS API. Putting nodes in public subnets gives
each one a public IP and requires auto-assigned addresses on those subnets; private subnets need NAT or a
set of VPC endpoints.

## Decision drivers

- Nodes not addressable from the internet.
- Smallest added cost on top of a billed control plane.
- Same network module as AWS 04/05.

## Considered alternatives

| Option | Cost (per hour) | Notes |
|---|---|---|
| **A. Private nodes + NAT instance (`nat_mode = instance`)** | ≈ $0.0154 (t3.micro + IPv4) | Free-tier hours; single point of egress failure; fine for image pulls |
| B. Private nodes + NAT Gateway | ≈ $0.05 + $0.045/GB | Managed, scalable; per-AZ for production (×2) |
| C. Private nodes + interface endpoints (ECR API, ECR DKR, STS, EKS Auth, EC2) + S3 gateway | ≈ $0.01 × endpoints × AZs ≈ $0.10 | No internet at all; public images (aws-cli demo) unavailable |
| D. Public subnets, public IPs on nodes | ≈ $0.01 for 2 IPv4 | Nodes addressable from the internet; requires changing subnet auto-assign |

## Decision

Option A by default, Option B as `nat_mode = gateway`. The VPC module tags public subnets
`kubernetes.io/role/elb` and private ones `kubernetes.io/role/internal-elb` for AWS 08.

## Consequences

**Positive:** nodes have no public IPs; cheapest egress.

**Negative:** if the NAT instance fails, nodes cannot pull new images (running pods keep running); egress
for both AZs depends on AZ a.

**Risks and tradeoffs:** a NAT instance's bandwidth is limited by its type; large image pulls are slower.

**Cost implications:** ≈ $11/month equivalent vs ≈ $33+ for one NAT Gateway.

**Security implications:** private nodes plus SG/NACL from the shared module; the S3 gateway endpoint keeps
ECR layer downloads (served from S3) off the NAT.
