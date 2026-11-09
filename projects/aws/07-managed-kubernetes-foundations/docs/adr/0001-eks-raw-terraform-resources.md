# ADR-0001: EKS with managed node groups, built from raw Terraform resources

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 07 (base for AWS 08–15) |

## Context

Later labs need a Kubernetes cluster on AWS. The lab must teach what each piece is for, be reproducible,
and keep the unavoidable cost visible and small.

## Decision drivers

- Every component visible and explainable in an interview.
- Production-relevant (what teams actually run).
- Lowest honest cost for a short session.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. EKS + managed node group, raw `aws_eks_*` resources** | Every IAM role, add-on and access entry is explicit; standard production setup | More code than a module; you own add-on ordering |
| B. `terraform-aws-modules/eks` | Battle-tested, concise | Hides the moving parts this lab teaches; large input surface |
| C. eksctl | Fast | Imperative CLI, CloudFormation underneath; not Terraform |
| D. EKS Auto Mode | AWS manages nodes, CNI, storage, load balancers | Extra per-instance management fee; hides node and CNI behaviour the lab explains |
| E. Self-managed (kubeadm / k3s on EC2) | No control-plane fee; k3s fits free-tier sizes | You run etcd and upgrades; not what "managed Kubernetes" interviews ask about |
| F. EKS with Fargate | No nodes to manage | Per-pod pricing, no DaemonSets, different networking |

## Decision

Option A on Kubernetes 1.37 (EKS default on 2026-11-09), API authentication mode with explicit access
entries, `upgrade_policy = STANDARD`, AL2023 managed node group on `t3.small`, managed add-ons pinned to the
newest compatible version via `aws_eks_addon_version`. Networking add-ons are created before the node
group, CoreDNS and metrics-server after it.

## Consequences

**Positive:** the whole cluster is ~200 lines of readable Terraform that map 1:1 to the architecture
diagram; upgrades are a variable change.

**Negative:** add-on ordering and IAM must be maintained by hand; no Cluster Autoscaler or Karpenter yet.

**Risks and tradeoffs:** `STANDARD` support means EKS upgrades the cluster automatically at end of standard
support — safer for cost, but you must test upgrades before that date.

**Cost implications:** $0.10/h control plane is unavoidable with EKS; see [cost](../cost.md).

**Security implications:** no implicit creator admin; endpoint public only to your CIDR and private
endpoint enabled; nodes in private subnets with IMDS hop limit 1.
