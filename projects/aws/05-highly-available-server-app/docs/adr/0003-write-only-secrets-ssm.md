# ADR-0003: Generate the DB password at apply time and keep it out of Terraform state

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 05, pattern for later labs |

## Context

RDS needs a master password and every app instance needs to read it at boot. Classic Terraform patterns
(`random_password` + `password`) store the secret in plain text in the state file, which now lives in
S3 and will be read by CI (AWS 06).

## Decision drivers

- Secret never in state, plan files or CI logs.
- No paid secret store required.
- Instances obtain it without baking it into user data or the AMI.

## Considered alternatives

| Option | Secret in state? | Cost | Rotation |
|---|---|---|---|
| **A. Ephemeral generator → `password_wo` + SSM `value_wo`** | No | Free (standard parameter, aws/ssm key) | Bump `db_password_version`, refresh instances |
| B. `random_password` + `password` + SSM `value` | Yes, plain text | Free | Taint and re-apply |
| C. `manage_master_user_password = true` (RDS-managed Secrets Manager secret) | No | $0.40/secret-month + API calls | Automatic rotation |
| D. Password in user data | In state **and** in instance metadata | Free | Re-deploy |

## Decision

Option A: `ephemeral "aws_secretsmanager_random_password"` produces the value during apply; it is
written only through write-only arguments to `aws_db_instance.password_wo` and
`aws_ssm_parameter.value_wo`, both keyed by `db_password_version`. Instances read the parameter with an
IAM policy limited to its ARN and KMS decrypt via SSM only.

## Consequences

**Positive:** `verify.sh` can assert that state contains no password; the pattern works for any secret.

**Negative:** requires Terraform ≥ 1.11 and a recent AWS provider; rotation needs an instance refresh and
briefly breaks new DB connections (exercise 8).

**Risks and tradeoffs:** anyone with `ssm:GetParameter` on the parameter, or root on an instance, can read
the password; the instance stores it in a 0640 file.

**Cost implications:** none (Secrets Manager is used only for the free-of-storage random-password API).

**Security implications:** a clear improvement over secrets in state; RDS IAM authentication or managed
rotation (option C) are the next steps for production.
