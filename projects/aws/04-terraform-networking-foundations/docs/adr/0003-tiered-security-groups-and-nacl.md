# ADR-0003: Security-group references for tiers, one coarse stateless NACL for private subnets

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | Shared `vpc` module |

## Context

Later labs need a web tier (load balancer), an app tier (instances that come and go) and a data tier
(database). Access must follow the tiers, survive instance replacement, and be explainable in a review.

## Decision drivers

- Least privilege between tiers.
- Rules that stay correct under Auto Scaling.
- Teach both AWS filtering mechanisms without making the network fragile.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. SG references (web → app → db) + one simple private NACL** | Identity-based; no IP bookkeeping; NACL adds a subnet-level backstop | NACL ephemeral rule must be understood |
| B. CIDR-based SG rules per subnet | Simple to read | Any host in the subnet gets access; breaks when subnets change |
| C. Detailed per-port NACLs as the main control | Explicit deny lists | Stateless rules double the work and cause hard-to-debug outages |
| D. No NACL (default allow-all) | Nothing to break | Misses the stateless lesson; no subnet-level guardrail |

## Decision

Three security groups created by the module: `web` (80/443 from `web_ingress_cidrs`, egress only to the
app port of `app`), `app` (app port from `web`; egress to `db` and HTTP/HTTPS), `db` (db port from `app`
only, no egress rules). One NACL on the private subnets: allow everything from the VPC CIDR, allow TCP
1024–65535 return traffic from anywhere, allow all outbound.

## Consequences

**Positive:** AWS 05 attaches these groups and gets tier isolation with no extra rules; verify.sh can
check the chain mechanically.

**Negative:** the NACL's ephemeral-port rule is broad (needed for NAT and endpoint returns); it is a
backstop, not the primary control.

**Risks and tradeoffs:** SG references do not cross regions; anyone allowed to attach `app-sg` to an
instance gains database reachability — restrict that IAM action.

**Cost implications:** none.

**Security implications:** the db SG has no egress rules, so a compromised database instance cannot
open outbound connections (replies to inbound connections are still allowed by state tracking).
