# ADR-0003: Access entries + RBAC for people, Pod Identity for pods, CNI permissions on the node role

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | AWS 07 |

## Context

People need scoped Kubernetes access; some pods need AWS permissions; the VPC CNI needs EC2 permissions to
manage ENIs.

## Decision drivers

- No shared admin credentials; least privilege per person and per pod.
- Infrastructure as code for access, not a hand-edited ConfigMap.
- Keep the first EKS lab understandable.

## Considered alternatives

| Area | Option | Notes |
|---|---|---|
| People | **Access entries (`authentication_mode = API`)** | Managed by the EKS API and Terraform; auditable |
| People | aws-auth ConfigMap | Legacy; a bad edit locks everyone out |
| Pods | **EKS Pod Identity** | No per-cluster OIDC provider; association per namespace/ServiceAccount |
| Pods | IRSA | Works without the agent; needs an OIDC provider and annotations |
| Pods | Node role | Every pod shares it — rejected; hop limit 1 blocks it |
| CNI | **`AmazonEKS_CNI_Policy` on the node role** | Simple, the default managed node group setup |
| CNI | Pod Identity for `aws-node` | Least privilege; adds add-on configuration and ordering complexity |

## Decision

An admin access entry with `AmazonEKSClusterAdminPolicy` for the Terraform caller (role ARN resolved from
the session), a developer IAM role mapped to group `lab07-developers` with no access policy (RBAC only),
Pod Identity for application pods (demo: one SSM parameter), and the CNI policy on the node role.

## Consequences

**Positive:** `verify.sh` can prove each boundary (developer allowed/denied actions, demo pod credentials).

**Negative:** the node role keeps EC2 network-interface permissions that any process with host-level access
on a node could use.

**Risks and tradeoffs:** moving the CNI to Pod Identity is the documented next hardening step.

**Cost implications:** none.

**Security implications:** IMDS hop limit 1 on nodes prevents pods from reaching the node role at all.
