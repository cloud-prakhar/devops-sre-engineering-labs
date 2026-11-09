# ADR-0002: Ubuntu 24.04 LTS, app run natively under a sandboxed systemd unit

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 01 |

## Context

The lab needs one operating system and a realistic workload to operate. Later projects containerise
the same application, so this lab should show what the OS itself provides before Docker hides it.

## Decision drivers

- Long support window and wide industry use, so skills transfer.
- Same OS on AWS, Azure and GCP labs.
- Free-tier sized (1 GiB RAM).
- Teach systemd, users and permissions directly.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. Ubuntu 24.04 LTS** (Canonical SSM parameter) | Same image family on all three clouds; supported until 2029 (standard); huge documentation base | Not AWS-optimised like AL2023 |
| B. Amazon Linux 2023 | AWS-tuned kernel, SSM agent preinstalled, dnf | AWS-only; skills less portable to Azure/GCP labs |
| C. Debian 13 / RHEL 9 | Stable; RHEL common in enterprises | RHEL is billed per hour; Debian has fewer cloud-specific docs |
| **Runtime: native systemd service** | Shows users, permissions, sandboxing, journald directly | Python venv per host; no image immutability |
| Runtime: Docker container | Portable artefact | Hides the OS concepts this lab teaches — covered in AWS 02 |

## Decision

Ubuntu 24.04 LTS selected through the public SSM parameter
`/aws/service/canonical/ubuntu/server/24.04/stable/current/<arch>/hvm/ebs-gp3/ami-id`, so every apply
gets the latest patched build without hard-coding AMI IDs per region. The API runs from a venv in
`/opt/taskboard`, owned by root and readable by a `taskboard` system user, as a sandboxed systemd unit
bound to `127.0.0.1`.

## Consequences

**Positive:** one OS across clouds; learners see systemd sandboxing and file ownership explicitly; the
API is not internet-reachable.

**Negative:** the AMI ID changes over time, so the module ignores AMI drift (`ignore_changes = [ami]`)
— a rebuilt host may differ from the original. Dependency installation runs `pip` on the host, which
needs outbound 443 to PyPI.

**Risks and tradeoffs:** tight sandboxing (`SystemCallFilter`, `ProtectSystem=strict`) can break future
app changes; `systemd-analyze security` and the startup logs show what to relax.

**Cost implications:** Ubuntu has no license charge on EC2; storage uses gp3 (cheaper than gp2 per GB).

**Security implications:** daily unattended security updates; reboots are manual by design so learners
practise them — production would schedule them.
