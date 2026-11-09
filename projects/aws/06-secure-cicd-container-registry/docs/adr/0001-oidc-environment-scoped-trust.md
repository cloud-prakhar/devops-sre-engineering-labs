# ADR-0001: GitHub OIDC with trust pinned to one repository and one GitHub Environment

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 06; pattern for every later pipeline |

## Context

The pipeline must push images and trigger deployments in AWS. The repository is public and accepts pull
requests. Any credential the pipeline can reach could be exfiltrated by malicious code in a PR or a
compromised third-party action.

## Decision drivers

- No long-lived credentials anywhere.
- Only reviewed code on `main`, approved by a human, may release or deploy.
- Separate, minimal permissions per job.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. OIDC, `sub = repo:O/R:environment:E`, environment with required reviewer and main-only policy** | No secrets; approvals and branch rules enforced by GitHub *and* AWS | Requires environment setup; reviewers needed for every run |
| B. OIDC, `sub = repo:O/R:ref:refs/heads/main` | No secrets; branch-scoped | No human approval; any workflow change merged to main runs with the role |
| C. OIDC, `sub = repo:O/R:*` | Simple | Any branch or PR workflow in the repo can assume the role |
| D. IAM user access keys in GitHub secrets | Works everywhere | Long-lived, leakable, rotation burden; exactly what this lab teaches against |

## Decision

Option A, with two roles: `lab06-gha-push` (ECR push to one repository) and `lab06-gha-deploy`
(`ssm:SendCommand` with `AWS-RunShellScript` on one instance). Both trust the same environment-scoped
`sub` and require `aud = sts.amazonaws.com`. `configure-github.sh` creates the environment with the
operator as required reviewer and a `main`-only deployment branch policy.

## Consequences

**Positive:** nothing to rotate or leak; every release needs an approval recorded by GitHub; CloudTrail
shows `gha-release-<run_id>` / `gha-deploy-<run_id>` sessions.

**Negative:** each manual run needs two approvals (release, deploy); one OIDC provider per account means
`create_github_oidc_provider = false` in accounts that already have one.

**Risks and tradeoffs:** the environment's protection is configured in GitHub, outside Terraform — if
someone removes the reviewer, AWS still trusts the environment name. Production: manage repository
settings as code (Terraform GitHub provider) and require two reviewers.

**Cost implications:** none.

**Security implications:** the `ecr:GetAuthorizationToken` and SSM read APIs cannot be resource-scoped;
everything else is.
