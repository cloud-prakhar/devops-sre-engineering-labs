# AWS 06 — Cost estimate

> **Pricing status: reference rates, not live-verified.** us-east-1 list prices as last known on
> 2026-11-09, not checked against the live price list in this session. Confirm with the
> [AWS Pricing Calculator](https://calculator.aws/) and your GitHub plan.

## Assumptions

| Item | Value |
|---|---|
| Region | us-east-1 |
| Session | 2 hours, ~5 pipeline runs, then `terraform destroy` |
| Deploy host | 1 × `t3.micro`, 20 GB gp3, 1 public IPv4 |
| ECR | ≤ 10 images × ~60 MB compressed ≈ 0.6 GB, plus small attestation manifests |
| Image pulls | EC2 → ECR in the same region |
| GitHub Actions | public fork, GitHub-hosted runners |
| Excluded | Taxes; Amazon Inspector enhanced scanning (not enabled) |

## Rates used

| Resource | Reference rate | Source |
|---|---|---|
| t3.micro | $0.0104 / hour | [EC2 on-demand](https://aws.amazon.com/ec2/pricing/on-demand/) |
| gp3 | $0.08 / GB-month | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |
| Public IPv4 | $0.005 / hour | [VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| ECR private storage | $0.10 / GB-month (legacy free tier: 500 MB/month for 12 months) | [ECR pricing](https://aws.amazon.com/ecr/pricing/) |
| ECR data transfer to EC2, same region | no charge | [ECR pricing](https://aws.amazon.com/ecr/pricing/) |
| ECR basic scanning | no charge | [ECR image scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-basic.html) |
| IAM, OIDC provider, STS, SSM Run Command | no charge | — |
| GitHub Actions, public repository, standard runners | no charge | [GitHub Actions billing](https://docs.github.com/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions) |
| GitHub artifact attestations, public repository | no charge | [Artifact attestations](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations) |

## Formula

```text
session = hours × (0.0104 + 0.005) + 20 × 0.08 × hours / 730 + ecr_GB × 0.10 × hours / 730
```

| Scenario | Calculation | Without free tier |
|---|---|---|
| 2-hour session | 2 × 0.0154 + 1.6 × 2/730 + 0.6 × 0.10 × 2/730 | **≈ $0.04** |
| Left running a month | 730 × 0.0154 + 1.6 + 0.06 | **≈ $12.90** |
| Repository kept, host destroyed | 0.6 GB × $0.10 | **≈ $0.06 / month** |

## Free-tier fit

Fits on legacy free-tier accounts (one `t3.micro`, ECR under 500 MB). On the Free plan the session uses a
few cents of credits. GitHub Actions minutes are free for public repositories; private repositories use
the account's included minutes.

## What makes this lab more expensive

| Variable | Impact |
|---|---|
| Amazon Inspector enhanced scanning | Billed per image scanned and rescanned |
| Keeping many images | +$0.10 per GB-month; the lifecycle policy keeps 10 |
| Private repository with heavy pipeline use | GitHub Actions minutes beyond the plan allowance |
| Cross-region pulls | Data transfer charges |
| KMS-encrypted repository | Key $1/month + requests |

## Cleanup

```bash
gh variable set AWS06_ENABLED --repo <owner/repo> --body false
terraform -chdir=terraform destroy
../../../shared/scripts/aws-find-lab-resources.sh
aws ecr describe-repositories --query 'repositories[?starts_with(repositoryName, `lab06`)].repositoryName'
```

`force_delete_repository = true` lets destroy remove the repository with its images and attestation
manifests.
