# ADR-0003: PostgreSQL in a container with scripted logical backups

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 03 |

## Context

Taskboard needs a relational database that behaves like production (PostgreSQL), with data that
survives container replacement and a tested restore procedure. Managed databases cost money and hide
the operational work the lab teaches.

## Decision drivers

- Same database engine the later managed-service labs use.
- Data persists across deploys; restores are practised.
- Runs within the 1 GiB instance next to three other services.
- No extra cost.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. `postgres:17-alpine` container, named volume, `pg_dump` script** | Free; full control; backup/restore is hands-on | You own patching, backups, monitoring; single copy of data |
| B. Amazon RDS for PostgreSQL | Automated backups, PITR, Multi-AZ, patching | db.t4g.micro free-tier hours exist only on some plans; needs private subnets and SG design (AWS 04/10) |
| C. SQLite on a volume (as in AWS 02) | Simplest | Single writer; no network service to isolate; does not teach DB operations |
| D. PostgreSQL 18 | Newest major version | Changed default data directory layout in the official image; less tested by learners' tools at time of writing |

## Decision

Option A. PostgreSQL 17 runs as UID 70 with all capabilities dropped, on an internal network, with
data in `pg-data`. `backup-db.sh` writes custom-format dumps atomically, verifies them with
`pg_restore --list`, and keeps seven; `restore-db.sh` restores in a single transaction after
confirmation.

## Consequences

**Positive:** realistic operations practice; restore tested in `local-test.sh` on every run.

**Negative:** RPO equals backup frequency (manual here); backups live on the same disk as the data until
copied off-host.

**Risks and tradeoffs:** the `postgres:17-alpine` tag floats across minor versions — fine for minor
upgrades, but a major upgrade (17 → 18) requires dump/restore or `pg_upgrade`, never just a tag change.

**Cost implications:** none on the instance; off-host copies to S3 would cost cents (AWS 10).

**Security implications:** password from a secret file; no published port; no internet access from the
database network. No TLS between API and DB (same host, internal network) — required once they are on
different hosts.
