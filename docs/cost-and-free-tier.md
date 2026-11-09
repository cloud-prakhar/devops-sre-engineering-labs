# Cost and free tier

Every lab has its own `docs/cost.md` with assumptions, a formula and cleanup steps. This page explains
the method, the free-tier rules that matter, and how to protect yourself from surprise bills.

> Prices in this repository are **reference rates** recorded on the date shown in each file. They are
> not live-verified unless the file says so. Always confirm with the provider's calculator.

## 1. Set a budget alarm before the first deploy

```bash
# AWS: a $1 monthly cost budget that emails you at 50% of actual spend.
aws budgets create-budget --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --budget '{"BudgetName":"labs-1usd","BudgetLimit":{"Amount":"1","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":50,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"you@example.com"}]}]'
```

Also enable **Free Tier usage alerts** in the AWS Billing console (Billing preferences). Budgets are
alerts, not limits: they do not stop resources.

## 2. Free-tier rules that affect these labs

### AWS

| Account | Offer | What it means here |
|---|---|---|
| Created **before 2025-07-15** | Legacy 12-month free tier: 750 h/month of t2.micro or t3.micro (region dependent), 30 GB EBS, 750 h public IPv4, 100 GB data out | AWS 01–03 cost $0 if each is the only instance running |
| Created **on/after 2025-07-15** | Free plan with promotional credits for a limited period; eligible instance types include t3.micro, t3.small, t4g.micro, t4g.small | AWS 01–03 consume a few cents of credits per session |
| Any | Always-free offers (e.g. some Lambda, DynamoDB allowances) | Not used by these labs |

Things that are **never free** and appear in later labs: EKS control plane (hourly), NAT Gateway
(hourly + per GB), and anything left running after the allowance is used up. Free-tier hours are shared
by all instances in the account (or AWS Organization).

Sources: [AWS Free Tier](https://aws.amazon.com/free/) ·
[Free Tier eligibility](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-eligibility.html).
The details above were compiled from AWS pages and secondary sources on 2026-11-09 — check your own
account's Free Tier page, which is authoritative.

### Azure and GCP (for later phases)

| Cloud | Relevant offer (verify before use) | Never free in our labs |
|---|---|---|
| Azure | 12-month free services include B-series VM hours and managed disks; AKS **Free** tier has no control-plane fee | Worker node VMs beyond free hours, NAT Gateway, Standard Load Balancer |
| GCP | Always Free e2-micro in selected US regions with 30 GB standard PD; GKE free tier covers one cluster's management fee | Cloud NAT, load-balancer forwarding rules, nodes |

## 3. How each lab estimates cost

```text
session_cost = Σ(hourly_rate × hours) + Σ(monthly_rate × hours / 730)
monthly_cost = Σ(hourly_rate × 730)   + Σ(monthly_rate)
```

Each `cost.md` lists region, resource types and quantities, session length, rates with source links,
the pricing date, exclusions, free-tier fit, what makes it more expensive, and cleanup.

## 4. Design rules that keep labs cheap

| Rule | Implementation |
|---|---|
| Smallest instance that works | `t3.micro` default, validated against free-tier eligible types |
| No surprise CPU bills | `cpu_credits = "standard"` on burstable instances |
| No NAT Gateway in single-host labs | Public subnet with tightly scoped security groups |
| No billed monitoring by default | Detailed monitoring and flow logs off until the labs that teach them |
| Disks within allowance | Root volume validated at ≤ 30 GB |
| Everything tagged | `Repository=devops-sre-engineering-labs` on every resource |
| Easy verification of cleanup | [`aws-find-lab-resources.sh`](../shared/scripts/aws-find-lab-resources.sh) |

## 5. Clean up

```bash
terraform -chdir=projects/aws/<lab>/terraform destroy
shared/scripts/aws-find-lab-resources.sh us-east-1
```

Then check the Billing console the next day: some charges appear with a delay.
