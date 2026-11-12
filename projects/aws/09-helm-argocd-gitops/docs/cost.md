# AWS 09 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 list prices as last known on
> 2026-11-12, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/).

**Not free:** this lab runs on the AWS 07 cluster (≈ $0.157/hour, see [AWS 07 cost](../../07-managed-kubernetes-foundations/docs/cost.md)).
Argo CD itself is free software and creates no AWS resources, but its pods need node capacity.

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 3 hours on the AWS 07 cluster, then cleanup |
| Added by this lab | 1 extra `t3.small` node (`node_count = 3` in AWS 07) for Argo CD's 5 pods, 20 GB gp3 |
| Prod Ingress | disabled by default (enabling it adds AWS 08's ALB cost) |
| GitHub | public fork; Argo CD polls over HTTPS (no GitHub cost) |
| Excluded | Taxes; data transfer for Git polling and image pulls (well under the free 100 GB) |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| t3.small (extra node) | $0.0208 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| AWS 07 cluster | ≈ $0.157 / hour | [AWS 07 cost](../../07-managed-kubernetes-foundations/docs/cost.md) |
| ALB if prod Ingress is enabled | ≈ $0.0405 / hour | [AWS 08 cost](../../08-kubernetes-networking-autoscaling/docs/cost.md) |

## Formula

```text
added_hourly = 0.0208 (third node) [+ 0.0405 if prod ingress]
session      = hours × (aws07_hourly + added_hourly) + 20 GB × 0.08 × hours / 730
```

| Scenario | Calculation | Cost |
|---|---|---|
| This lab's addition, 3 hours | 3 × 0.0208 + 1.6 × 3/730 | **≈ $0.07** |
| AWS 07 + 09 together, 3 hours | 3 × (0.157 + 0.0208) + storage | **≈ $0.56** |
| Extra node left running a month | 730 × 0.0208 + 1.6 | **≈ $17** |

## Free-tier fit

None of the lab is free while the EKS control plane runs. On Free-plan accounts `t3.small` is free-tier
eligible but still paid from credits.

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Enabling prod's Ingress | +≈ $0.04/h (ALB + 2 IPv4) |
| Argo CD HA mode (Redis HA, multiple replicas) | More pods → more nodes |
| Using `c7i-flex.large` nodes instead of a third t3.small | ≈ +$0.13/h for two nodes |
| Forgetting to destroy | the whole cluster, ≈ $4.30/day with three nodes |

## Cleanup

```bash
kubectl -n argocd delete applicationset taskboard
kubectl -n argocd delete application gitops-root
terraform -chdir=terraform destroy
kubectl delete namespace taskboard-dev taskboard-prod --ignore-not-found
../../../shared/scripts/aws-find-lab-resources.sh
```

Return AWS 07 to `node_count = 2` (or destroy it) when you are done.
