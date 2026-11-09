# AWS 04 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 on-demand list prices as last known
> on 2026-11-09, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/).

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 3 hours, then `scripts/destroy.sh` (bucket may be kept for AWS 05) |
| Test hosts | 2 × `t3.micro` (bastion, private host), 8 GB gp3 each, standard credits |
| Public IPv4 | bastion (1); NAT instance or NAT Gateway EIP adds 1 |
| NAT | priced per mode below |
| State bucket | < 1 MB stored, < 1,000 requests per session |
| Excluded | Taxes, data transfer beyond the free 100 GB/month, flow logs (disabled) |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| t3.micro Linux | $0.0104 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| Public IPv4 | $0.005 / hour | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| NAT Gateway | $0.045 / hour + $0.045 / GB processed | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| S3 Standard | $0.023 / GB-month; PUT $0.005 / 1,000; GET $0.0004 / 1,000 | [S3 pricing](https://aws.amazon.com/s3/pricing/) |
| VPC, subnets, route tables, IGW, SGs, NACLs, S3 gateway endpoint | no charge | — |

## Formula

```text
session = hours × (n_instances × 0.0104 + n_public_ipv4 × 0.005 + nat_gw_hours × 0.045)
        + nat_gb × 0.045 + disk_GB × 0.08 × hours / 730 + s3 (≈ 0)
```

| `nat_mode` | Instances | Public IPv4 | 3-hour session | Left running a month |
|---|---|---|---|---|
| `none` (default) | 2 | 1 | 3 × (0.0208 + 0.005) + 16 × 0.08 × 3/730 ≈ **$0.08** | ≈ $20 |
| `instance` | 3 | 2 | 3 × (0.0312 + 0.010) + 24 × 0.08 × 3/730 ≈ **$0.13** | ≈ $32 |
| `gateway` | 2 | 2 | 3 × (0.0208 + 0.010 + 0.045) + 0.0053 + GB × 0.045 ≈ **$0.23** + data | ≈ $57 + data |
| `none`, `enable_test_hosts = false` | 0 | 0 | **≈ $0** (only the bucket) | ≈ $0 |

## Free-tier fit

| Account | Effect |
|---|---|
| Legacy free tier | 750 instance-hours/month are shared: a 3-hour session with 2–3 instances uses 6–9 hours. Public IPv4 750 h shared too. S3 5 GB free. NAT Gateway is **not** covered |
| Free plan (credits) | All of the above is paid from credits |

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| `nat_mode = gateway` left running | ≈ $33/month per gateway before data |
| Routing S3 traffic through NAT instead of the endpoint | $0.045/GB on a NAT Gateway — the endpoint is free |
| One NAT per AZ (production pattern) | Multiply the gateway line by `az_count` |
| Flow logs to CloudWatch | $0.50/GB ingested (reference) — not enabled here |
| Many state versions | Negligible; lifecycle expires noncurrent versions after 30 days |

## Cleanup

```bash
scripts/destroy.sh                                       # network, then optionally the bucket
../../../shared/scripts/aws-find-lab-resources.sh
aws ec2 describe-addresses --filters Name=tag:Repository,Values=devops-sre-engineering-labs   # no leftover EIPs
```

An Elastic IP left behind by a failed destroy keeps billing; the cleanup finder lists it.
