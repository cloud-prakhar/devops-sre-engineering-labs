# AWS 01 — Cost estimate

> **Pricing status: reference rates, not live-verified.** Rates below are AWS public on-demand list
> prices for us-east-1 as last known when this file was written (2026-11-09). They were **not** checked
> against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/) before relying on them.

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Lab session | 4 hours, then `terraform destroy` |
| Instance | 1 × `t3.micro` (2 vCPU, 1 GiB), Linux, on-demand, `cpu_credits = standard` |
| Storage | 1 × 20 GB gp3 root volume (3,000 IOPS / 125 MB/s baseline, no extra) |
| Public IPv4 | 1 auto-assigned address while running |
| Data transfer out | < 1 GB (SSH, package downloads are inbound and free) |
| Excluded | Taxes, support plans, CloudWatch beyond basic metrics, snapshots |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| t3.micro Linux | $0.0104 / hour | [EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 storage | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| Public IPv4 address | $0.005 / hour | [VPC pricing — public IPv4](https://aws.amazon.com/vpc/pricing/) |
| Data transfer out | first 100 GB/month free (all services combined) | [EC2 data transfer](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer) |
| Session Manager | no additional charge for EC2 | [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/) |
| VPC, IGW, SG, IAM, key pair | no charge | — |

## Formula

```text
session_cost = hours × (instance_rate + ipv4_rate) + volume_GB × gp3_rate × hours / 730
monthly_cost = 730   × (instance_rate + ipv4_rate) + volume_GB × gp3_rate
```

| Scenario | Calculation | Without free tier |
|---|---|---|
| 4-hour session | 4 × (0.0104 + 0.005) + 20 × 0.08 × 4 / 730 | **≈ $0.07** |
| Left running a month | 730 × 0.0154 + 20 × 0.08 | **≈ $12.84** |

## Free-tier fit

| Account type | What covers this lab | Result |
|---|---|---|
| Legacy free tier (account created before 2025-07-15, within 12 months) | 750 h/month t2.micro or t3.micro (region dependent), 30 GB EBS, 750 h public IPv4 | $0 if this is your only instance and disk |
| Free plan (account created on/after 2025-07-15) | Usage is paid from promotional credits; t3.micro is an eligible type | Consumes ≈ $0.07 of credits per session |
| Paid account outside free tier | — | As calculated above |

Free-tier hours are **per account (or per AWS Organization), not per instance**: two t3.micro
instances running all month use 1,460 hours and exceed 750.

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Forgetting to destroy | ≈ $0.42/day |
| `cpu_credits = unlimited` | Surplus credits billed per vCPU-hour; prevented by the module |
| Larger type (`t3.small`) | Rate roughly doubles |
| Snapshots / AMIs you create in exercises | $0.05/GB-month for snapshots (reference) |
| Detailed monitoring | Billed per metric; disabled by the module |
| Stopped (not terminated) instance | Instance hours stop; EBS and any Elastic IP keep billing |

## Cleanup

```bash
terraform -chdir=terraform destroy
../../../shared/scripts/aws-find-lab-resources.sh
aws ec2 describe-volumes --filters Name=tag:Repository,Values=devops-sre-engineering-labs --query 'Volumes[].VolumeId'
```

The root volume has `delete_on_termination = true`. Snapshots or AMIs you create by hand are not
managed by Terraform — delete them yourself.
