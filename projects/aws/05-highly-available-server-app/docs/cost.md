# AWS 05 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 on-demand list prices as last known
> on 2026-11-09, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/).

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 3 hours, then `terraform destroy` |
| App tier | 2 × `t3.micro` (desired; up to 4 during drills), 10 GB gp3 each, standard credits |
| Load balancer | 1 ALB in 2 AZs, < 1 LCU |
| Public IPv4 | 2 instances + 2 ALB node addresses |
| Database | 1 × `db.t4g.micro` PostgreSQL, single-AZ, 20 GB gp3, 1-day backups |
| Secrets | 1 SSM standard SecureString parameter (AWS-managed key) |
| Excluded | Taxes, data transfer > 100 GB/month, CloudWatch beyond default metrics and the target-tracking alarms |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| t3.micro | $0.0104 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 (EBS) | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| Public IPv4 | $0.005 / hour each | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| ALB | $0.0225 / hour + $0.008 / LCU-hour | [ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) |
| db.t4g.micro PostgreSQL single-AZ | $0.016 / hour | [RDS PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/) |
| RDS gp3 storage | $0.115 / GB-month | [RDS PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/) |
| SSM standard parameter, aws/ssm key | no charge | [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/) |
| Secrets Manager `GetRandomPassword` (ephemeral generator) | API calls only, fractions of a cent | [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) |
| CloudWatch alarms created by target tracking (2) | $0.10 / alarm-month | [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) |

## Formula

```text
hourly  = n_instances × 0.0104 + n_ipv4 × 0.005 + 0.0225 + LCU × 0.008 + 0.016
storage = (n_instances × 10 × 0.08 + 20 × 0.115) per month
session = hours × hourly + storage × hours / 730
```

| Scenario | Calculation | Without free tier |
|---|---|---|
| 3-hour session (2 instances, 1 LCU) | 3 × (0.0208 + 0.020 + 0.0225 + 0.008 + 0.016) + 3.9 × 3/730 | **≈ $0.28** |
| Drills scale to 4 instances for 1 hour | + 1 × (0.0208 + 0.010) | **+ $0.03** |
| Left running a month | 730 × 0.0873 + 3.9 | **≈ $68** |

## Free-tier fit

| Account | What applies |
|---|---|
| Legacy free tier | 750 h/month each of: t2/t3.micro (shared by **all** instances — 2 instances = 1,460 h/month, so only short sessions are free), ALB + 15 LCU, db.t4g.micro single-AZ + 20 GB storage, public IPv4. A few 3-hour sessions per month stay at $0 |
| Free plan (credits) | Everything is paid from credits: ≈ $0.28 per session |
| Never free | Multi-AZ RDS, more than ~750 instance-hours, NAT Gateways (not used) |

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Forgetting to destroy | ≈ $2.20 per day |
| `multi_az = true` | Database line doubles |
| Scale-out drills left running | +$0.016/h per extra instance (incl. IPv4) |
| Private app subnets with one NAT Gateway per AZ | +≈ $0.09/h + data (2 AZs) |
| HTTPS with a custom domain | Route 53 hosted zone $0.50/month; ACM public certificates are free |

## Cleanup

```bash
terraform -chdir=terraform destroy
../../../shared/scripts/aws-find-lab-resources.sh
aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier'   # remove any you created
```

`skip_final_snapshot = true` means destroy leaves no snapshot behind; automated backups are deleted with
the instance.
