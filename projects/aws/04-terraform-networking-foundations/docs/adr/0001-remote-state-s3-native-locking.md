# ADR-0001: Remote state in S3 with native lock files, bootstrapped by a local-state stack

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 04 and every later AWS lab |

## Context

From AWS 04 on, stacks are long-lived enough to be shared between sessions, people and (AWS 06) a CI
pipeline. Local state cannot be shared or locked and dies with the laptop. The state backend must cost
nothing measurable and be secure, because state contains resource IDs and can contain secrets.

## Decision drivers

- Safe concurrent use (locking) and recoverability (history).
- Free-tier cost.
- Minimum moving parts for learners.
- Least-privilege access for automation later.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. S3 + `use_lockfile = true`** | One service; conditional-write locks; versioning for history; pennies per month | Needs Terraform ≥ 1.10; bucket must be bootstrapped |
| B. S3 + DynamoDB lock table | Works with older Terraform; widely documented | Deprecated in the S3 backend; second service and IAM surface |
| C. HCP Terraform / Terraform Cloud | Managed state, locking, UI, runs | External account; free tier limits; hides the mechanics this lab teaches |
| D. Keep local state | Nothing to set up | No sharing, no locking, no recovery |

## Decision

Option A. A bootstrap stack with **local** state creates the bucket (versioning, SSE-S3, ownership
enforced, all public access blocked, TLS-only bucket policy, 30-day noncurrent-version expiry) and
outputs both the backend settings and a least-privilege IAM policy. Each later stack uses a partial
`backend "s3"` block with a fixed `key`; `shared/scripts/tf-init-backend.sh` writes `backend.hcl` from the
bootstrap outputs.

## Consequences

**Positive:** shared, locked, recoverable state for every later lab; the CI role in AWS 06 can reuse
the output policy; no DynamoDB.

**Negative:** two-stage setup; the bootstrap stack's own state is local (it only describes the bucket,
and the bucket can be re-imported if that file is lost).

**Risks and tradeoffs:** destroying the bucket destroys every lab's state — `force_destroy` defaults to
`false` and `destroy.sh` asks before enabling it. SSE-S3 instead of a customer-managed KMS key means
anyone with `s3:GetObject` can read state; IAM is the control.

**Cost implications:** S3 storage and requests for a few small files: fractions of a cent per month.

**Security implications:** TLS-only policy; no public access; access logging not enabled (would need a
second bucket) — CloudTrail data events are the production audit option.
