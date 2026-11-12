# AWS 08 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 list prices as last known on
> 2026-11-12, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/).

**Not free:** this lab runs on the AWS 07 cluster (≈ $0.157/hour, see [AWS 07 cost](../../07-managed-kubernetes-foundations/docs/cost.md))
and adds an Application Load Balancer.

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 3 hours on an existing AWS 07 cluster, then cleanup |
| Added by this lab | 1 internet-facing ALB in 2 AZs (2 public IPv4 addresses), < 1 LCU |
| Pods | scale within the existing nodes (no node autoscaling) |
| IAM, Pod Identity, Helm, NetworkPolicy, HPA, PDB | no charge |
| Excluded | Taxes, data transfer > free 100 GB |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| Application Load Balancer | $0.0225 / hour + $0.008 / LCU-hour | [ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) |
| Public IPv4 (ALB nodes) | $0.005 / hour each | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| AWS 07 cluster (control plane, nodes, NAT instance) | ≈ $0.157 / hour | [AWS 07 cost](../../07-managed-kubernetes-foundations/docs/cost.md) |

## Formula

```text
added_hourly = 0.0225 + LCU × 0.008 + 2 × 0.005
session      = hours × (aws07_hourly + added_hourly)
```

| Scenario | Calculation | Cost |
|---|---|---|
| This lab's addition, 3 hours (1 LCU) | 3 × (0.0225 + 0.008 + 0.010) | **≈ $0.12** |
| AWS 07 + 08 together, 3 hours | 3 × (0.157 + 0.0405) + storage | **≈ $0.61** |
| ALB left running a month | 730 × 0.0405 | **≈ $30** |

## Free-tier fit

The legacy free tier includes 750 ALB hours and 15 LCUs per month, which would cover this lab's ALB — but
the EKS control plane is never free, so the lab as a whole is billed on every account type.

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Forgetting to delete the Ingress before destroying the cluster | Orphaned ALB ≈ $1/day plus security groups |
| One Ingress per service without `group.name` | One ALB each |
| HTTPS with a domain | ACM certificates are free; Route 53 hosted zone $0.50/month |
| Raising `node_count` for HPA headroom | +$0.0208/h per t3.small |
| AWS WAF on the ALB | Per web ACL, rule and request |

## Cleanup

```bash
kubectl delete -k k8s/.generated
aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName,`k8s-taskboar`)].LoadBalancerName'   # until empty
helm uninstall aws-load-balancer-controller -n kube-system
terraform -chdir=terraform destroy
../../../shared/scripts/aws-find-lab-resources.sh
```
