# AWS 07 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 on-demand list prices as last known
> on 2026-11-09, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/).

**This lab is never free.** The EKS control plane is billed per cluster-hour on every account type.

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 3 hours including ≈ 25 min of create/destroy, then `terraform destroy` |
| Control plane | 1 cluster, Kubernetes 1.37 in **standard** support |
| Nodes | 2 × `t3.small` on-demand, 20 GB gp3 each, no public IPs |
| NAT | `nat_mode = instance`: 1 × `t3.micro`, 8 GB gp3, 1 public IPv4 |
| Add-ons | VPC CNI, kube-proxy, CoreDNS, Pod Identity agent, metrics-server (no add-on charges) |
| Excluded | Taxes, control-plane logs (off), load balancers (none in this lab), data transfer > free 100 GB |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| EKS cluster, standard support | $0.10 / hour | [EKS pricing](https://aws.amazon.com/eks/pricing/) |
| EKS cluster, extended support | $0.60 / hour | [EKS pricing](https://aws.amazon.com/eks/pricing/) |
| t3.small | $0.0208 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| t3.micro (NAT) | $0.0104 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| Public IPv4 | $0.005 / hour | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| NAT Gateway (if `nat_mode = gateway`) | $0.045 / hour + $0.045 / GB | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| EKS Pod Identity, access entries, managed add-ons | no charge | [EKS pricing](https://aws.amazon.com/eks/pricing/) |

## Formula

```text
hourly  = 0.10 (control plane) + n_nodes × 0.0208 + 0.0104 (NAT instance) + 0.005 (NAT IPv4)
storage = (n_nodes × 20 + 8) × 0.08 per month
session = hours × hourly + storage × hours / 730
```

| Scenario | Calculation | Cost |
|---|---|---|
| 3-hour session | 3 × (0.10 + 0.0416 + 0.0154) + 3.84 × 3/730 | **≈ $0.49** |
| Left running a day | 24 × 0.157 + 3.84/30 | **≈ $3.90** |
| Left running a month | 730 × 0.157 + 3.84 | **≈ $118** |
| Same month, extended support | + 730 × 0.50 | **≈ $483** |

The control plane alone is ≈ 64% of the hourly cost.

## Free-tier fit

| Account | Effect |
|---|---|
| Legacy free tier | Only the NAT `t3.micro` and some EBS are covered; `t3.small` nodes and the control plane are billed |
| Free plan (credits) | `t3.small` is free-tier eligible (no extra restriction), but all usage is paid from credits, including the control plane |

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Forgetting to destroy | ≈ $3.90 per day |
| Missing a version upgrade → extended support | Control plane × 6 (prevented by `upgrade_policy = STANDARD`, which upgrades automatically instead) |
| `nat_mode = gateway` | +$0.035/h vs the instance, plus $0.045/GB of image pulls |
| Control-plane logs | CloudWatch ingestion per GB (audit logs are chatty) |
| `Service type=LoadBalancer` (AWS 08) | an NLB/ALB per service, billed hourly |
| `c7i-flex.large` nodes | ≈ 4× the node line |
| `node_capacity_type = SPOT` | Usually 50–70% cheaper nodes, with interruptions |

## Cleanup

```bash
kubectl delete namespace taskboard --wait
terraform -chdir=terraform destroy
../../../shared/scripts/aws-find-lab-resources.sh
aws eks list-clusters --query clusters                                   # must not list lab07-eks
aws ec2 describe-volumes --filters Name=tag:eks:cluster-name,Values=lab07-eks --query 'Volumes[].VolumeId'
```

EBS volumes created by Kubernetes (PersistentVolumes, from AWS 10 on) are **not** in Terraform state; this
lab creates none, but check the last command anyway.
