# ADR-0003: Auto-sync dev, manual-sync prod, promotion by commit

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 09 |

## Context

Changes should flow quickly to dev and deliberately to prod, with a complete history of what ran where.

## Decision drivers

- Every deployment is a reviewable commit.
- A human gate before production.
- Rollback without special tooling.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. dev automated (prune + self-heal), prod manual sync; promote by editing values files** | Simple, visible gate; Git history is the audit log | Manual sync is a weak control if many people can click Sync |
| B. Both automated, gate via PR approval on prod values | Pure GitOps; review is the gate | Needs branch protection and reviewers (a team setting) |
| C. Argo CD Image Updater writes digests back | No manual promotion | More moving parts; write access to Git from the cluster |
| D. Argo Rollouts canary with analysis | Progressive delivery | Needs metrics (AWS 11) |

## Decision

Option A, implemented with an ApplicationSet `templatePatch` that adds `automated` only where
`autoSync: true`. `promote.sh` writes the digest (and a version label) and commits; `sync-prod.sh` shows the
out-of-sync resources and triggers one sync operation; rollback is `git revert`.

## Consequences

**Positive:** drift in dev is reverted within a minute; prod drift is visible but never auto-applied.

**Negative:** prod can lag Git indefinitely if nobody syncs (by design; visible as OutOfSync).

**Risks and tradeoffs:** `promote.sh` pushes from a laptop; in a team, promotions arrive as PRs (option B).

**Cost implications:** none.

**Security implications:** CI never needs cluster credentials; write access to the tracked branch becomes
the most sensitive permission.
