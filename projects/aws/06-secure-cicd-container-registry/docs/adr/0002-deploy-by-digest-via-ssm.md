# ADR-0002: Deploy image digests through SSM Run Command to a host-side deploy script

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 06 |

## Context

After a release, the new image must run on the deploy host, safely and verifiably, from a GitHub-hosted
runner whose IP addresses change constantly.

## Decision drivers

- No inbound access from CI; no SSH keys in CI.
- Deploy exactly the scanned and attested bytes.
- Health-gated rollout with automatic rollback, even if the pipeline dies mid-deploy.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. SSM Run Command → `taskboard-deploy <repo@digest>` on the host** | No inbound ports; IAM-scoped; audited; host-side logic survives CI failures | `AWS-RunShellScript` is broad; depends on the SSM agent |
| B. SSH from the runner | Familiar | Open port 22 to the world (runner IPs) and a root-equivalent key in secrets |
| C. Host polls ECR for new tags (Watchtower-style) | Pure pull | Deploys whatever is pushed, without approval or verification |
| D. ECS / Kubernetes | Native rolling deploys | Not free (Fargate/EKS); covered from AWS 07 on |
| E. Auto Scaling instance refresh with a new launch template (AWS 05 style) | Immutable instances | Minutes per rollout; multiple instances cost more |

## Decision

Option A. The deploy job validates that the reference is `repo@sha256:<64 hex>`, runs the host script via
`scripts/ssm-run.sh` (which returns the command's real exit status), then verifies `/api/info` from inside
the host. The host script refuses tags, records `current`/`previous` digests, replaces the container with
the AWS 02 runtime profile, waits for Docker health, and restores the previous digest on failure.

## Consequences

**Positive:** CI needs no network path to the host; rollback is a first-class operation (`--rollback`);
the same script was tested locally against a registry (10 checks).

**Negative:** one host means a short outage during replacement (fixed by AWS 05's pattern); SSM agent
outages block deploys.

**Risks and tradeoffs:** the deploy role can run any shell command as root on that one instance — narrow
it with a custom SSM document that takes only a digest parameter (exercise 8).

**Cost implications:** SSM Run Command has no charge.

**Security implications:** the instance role can pull from one repository only; no credentials are
written to disk except Docker's short-lived ECR login token.
