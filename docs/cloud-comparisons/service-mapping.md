# Cloud service mapping: AWS, Azure, Google Cloud

Services in the same row solve a similar problem. They are **not** identical: the "Differences that
matter" column is where outages, surprise bills and interview follow-ups come from. Verify details in
the linked documentation — providers change these often.

## Compute and access

| Need | AWS | Azure | GCP | Differences that matter |
|---|---|---|---|---|
| Virtual machine | EC2 | Virtual Machines | Compute Engine | GCP bills per second with sustained-use discounts on some families; Azure VMs live in a resource group; AWS burstable T-family has credit modes (standard/unlimited) |
| Small/burstable VM | t3/t4g | B-series | e2-micro / e2-small (shared-core) | Each has a CPU baseline; behaviour when credits run out differs |
| Boot image lookup | SSM public parameters, AMI IDs per region | Marketplace URN (publisher:offer:sku:version) | Image families (`ubuntu-2404-lts-amd64`) | AMI IDs are regional; Azure/GCP names are global |
| Instance identity for API calls | Instance profile (IAM role), IMDSv2 | Managed identity, IMDS | Service account, metadata server | AWS requires a session token with IMDSv2; GCP requires the `Metadata-Flavor: Google` header; Azure requires `Metadata: true` |
| Shell without open ports | Systems Manager Session Manager | Azure Bastion (billed) / Run Command | IAP TCP forwarding | Bastion is a billed resource; SSM and IAP have no per-session charge |
| First-boot configuration | user data → cloud-init | custom data → cloud-init | startup-script / user-data → cloud-init (Ubuntu) | Same cloud-init file usually works; delivery and size limits differ |

## Networking

| Need | AWS | Azure | GCP | Differences that matter |
|---|---|---|---|---|
| Private network | VPC (regional) | VNet (regional) | VPC (global), subnets regional | A GCP VPC spans regions; AWS/Azure need peering or transit between regions |
| Instance firewall | Security group (stateful, allow-only, per ENI) | NSG (stateful, allow + deny, priorities, per subnet or NIC) | VPC firewall rules (stateful, allow + deny, priorities, target tags/service accounts) | Only Azure/GCP rules support explicit deny and priorities at this layer; AWS adds NACLs (stateless) |
| Outbound internet for private subnets | NAT Gateway | NAT Gateway | Cloud NAT | All billed; GCP Cloud NAT is a software-defined service on the router, no appliance per AZ |
| Public IPv4 | Auto-assigned / Elastic IP, billed hourly | Public IP resource | Ephemeral / static external IP | All three now charge for public IPv4 in most cases — check free-tier allowances |
| DNS inside the network | Route 53 Resolver (VPC base + 2) | Azure-provided DNS 168.63.129.16 | Metadata server 169.254.169.254 | Different addresses; matters when you hard-code resolvers |

## Containers and Kubernetes

| Need | AWS | Azure | GCP | Differences that matter |
|---|---|---|---|---|
| Container registry | ECR | ACR | Artifact Registry | ACR has tiers billed per day; ECR/AR bill per GB-month; auth flows differ |
| Managed Kubernetes | EKS | AKS | GKE (Standard / Autopilot) | EKS control plane is billed hourly; AKS Free tier has no control-plane fee (no SLA); GKE gives a monthly credit for one cluster's management fee |
| Pod-level cloud identity | EKS Pod Identity / IRSA | Entra Workload ID | Workload Identity Federation for GKE | Same idea (no static keys), different setup and token audiences |
| Ingress / L7 | AWS Load Balancer Controller → ALB | Application Routing add-on / Application Gateway for Containers | GKE Gateway / Ingress → Cloud Load Balancing | Annotations and Gateway API support differ; health-check semantics differ |
| Block storage for pods | EBS CSI (AZ-bound) | Azure Disk CSI (zone-bound) | PD CSI (zonal or regional PD) | Zonal volumes pin pods to a zone; GCP offers regional PDs |

## Observability, security, delivery

| Need | AWS | Azure | GCP | Differences that matter |
|---|---|---|---|---|
| Metrics and logs | CloudWatch | Azure Monitor / Log Analytics | Cloud Monitoring / Cloud Logging | Pricing models (ingestion vs retention) differ a lot for logs |
| Managed Prometheus | Amazon Managed Service for Prometheus | Azure Monitor managed Prometheus | Google Cloud Managed Service for Prometheus | All accept PromQL; ingestion pricing and retention differ |
| Secrets | Secrets Manager / SSM Parameter Store | Key Vault | Secret Manager | Rotation features and per-secret pricing differ |
| CI/CD federation from GitHub | IAM OIDC identity provider + role | Entra federated credential on an app/managed identity | Workload Identity Federation pool + provider | All avoid long-lived keys; subject-claim matching rules differ |
| IaC state backend | S3 (native lock file) | Storage Account blob (lease lock) | Cloud Storage bucket (object lock) | Locking mechanism differs; all support encryption and versioning |

## How the labs use this mapping

The same Taskboard application and the same 15 themes are implemented on every cloud. When the Azure
and GCP versions of a lab are built, their README "Concepts used" section links back to the row above
and records which differences changed the design (for example, NSG deny rules or GCP's global VPC).

References: [AWS documentation](https://docs.aws.amazon.com/) · [Azure documentation](https://learn.microsoft.com/azure/) · [Google Cloud documentation](https://cloud.google.com/docs) · [Azure for AWS professionals](https://learn.microsoft.com/azure/architecture/aws-professional/) · [Google Cloud for AWS professionals](https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison)
