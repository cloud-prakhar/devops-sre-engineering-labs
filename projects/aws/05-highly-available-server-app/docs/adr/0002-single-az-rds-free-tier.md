# ADR-0002: Single-AZ RDS PostgreSQL on db.t4g.micro

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 05 |

## Context

Moving state off the instances is the precondition for an Auto Scaling app tier. The database must be
PostgreSQL (same engine as AWS 03), private, encrypted, and as cheap as possible.

## Decision drivers

- Managed backups and patching, so the lab focuses on the app tier.
- Free-tier eligibility.
- Honest statement of the remaining single point of failure.

## Considered alternatives

| Option | Cost | Availability |
|---|---|---|
| **A. RDS PostgreSQL db.t4g.micro single-AZ, 20 GB gp3** | ≈ $0.016/h; legacy free tier 750 h | Instance or AZ failure = outage until recovery |
| B. RDS Multi-AZ | ≈ 2× | Automatic failover in ~1–2 min |
| C. Aurora Serverless v2 | Minimum ACUs billed while running | Multi-AZ storage, fast failover |
| D. PostgreSQL on an EC2 instance | free-tier hours | You own backups, patching, failover |
| E. DynamoDB | Always-free allowance | Would require a new storage backend in the app |

## Decision

Option A with `storage_encrypted = true`, `publicly_accessible = false`, the module's `db` SG, 1-day
automated backups, no storage autoscaling beyond 20 GB, Performance Insights and enhanced monitoring off,
and TLS required by the app (`sslmode=require`). PostgreSQL major version is a variable (default 18).

## Consequences

**Positive:** shared state with managed backups; the app tier can be destroyed and rebuilt freely.

**Negative:** the database is the single point of failure — exercise 7 demonstrates it.

**Risks and tradeoffs:** `skip_final_snapshot = true` and `deletion_protection = false` make destroy
fast and free but would lose data in production.

**Cost implications:** see [cost](../cost.md); Multi-AZ would double the database line.

**Security implications:** private subnets, SG reference, encryption at rest, TLS in transit; the app
uses the master user — a dedicated least-privilege role is the production follow-up.
