# ADR-0001: SSH keys restricted by source IP, with Session Manager as fallback

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 01 (reused by AWS 02 and 03 through the shared `lab-host` module) |

## Context

The lab teaches Linux administration, so learners need a real interactive shell and must understand
SSH. The host has a public IP and sits in a public subnet because a NAT Gateway (needed for a private
subnet with outbound internet) is not covered by the free tier. Anything listening publicly is scanned
within minutes of launch.

## Decision drivers

- Learners must practise SSH itself (keys, sshd config, tunnels).
- Zero recurring cost beyond the instance.
- Minimal attack surface on a public IP.
- A recovery path when SSH is misconfigured during exercises.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. SSH keys, SG limited to operator /32, SSM fallback** | Teaches SSH; free; small exposure; lockouts recoverable | Port 22 is public to one IP; IP changes need `terraform apply` |
| B. Session Manager only, no port 22 | No inbound ports at all; IAM-audited sessions | Does not teach SSH; needs plugin; tunnels need SSM port forwarding |
| C. Bastion host in a public subnet, lab host private | Production pattern | Needs NAT Gateway or VPC endpoints for the private host (billed); second instance |
| D. EC2 Instance Connect Endpoint | No public IP needed; IAM-controlled | Adds a service to learn before Linux basics; endpoint and private networking complexity |
| E. SSH open to 0.0.0.0/0 with fail2ban | Works from anywhere | Constant brute-force noise; one weak key or CVE away from compromise |

## Decision

Option A. The `lab-host` module refuses `0.0.0.0/0` for SSH through variable validation, sshd accepts
only public keys from members of `ssh-users`, and the instance role carries only
`AmazonSSMManagedInstanceCore` so Session Manager works without any inbound rule.

## Consequences

**Positive:** learners practise the real tool; exposure is one port to one IP; Session Manager gives a
no-SSH recovery path and an alternative for networks that block port 22.

**Negative:** learners on changing IPs must re-apply; the host still needs a public IPv4 address, which
is billed outside the free-tier allowance.

**Risks and tradeoffs:** a leaked private key from the allowed IP still grants access — mitigated by
ed25519 keys with passphrases. The SSM role lets anyone with `ssm:StartSession` in the account open a
root-capable shell; in shared accounts, restrict that permission by tag.

**Cost implications:** none beyond the public IPv4 address that the free-tier-friendly design already
needs. Session Manager has no extra charge for EC2.

**Security implications:** IMDSv2 with hop limit 1 prevents containers or SSRF from stealing the
SSM role credentials; SG egress is limited to 80/443.

## Revisit when

Project 04 introduces private subnets — production-style access then moves to Session Manager or EC2
Instance Connect Endpoint with no public IP on application hosts.
