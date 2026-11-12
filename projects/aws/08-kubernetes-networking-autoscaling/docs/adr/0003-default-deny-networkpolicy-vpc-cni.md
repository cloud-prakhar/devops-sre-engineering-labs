# ADR-0003: Default-deny NetworkPolicy enforced by the VPC CNI network policy agent

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 07 (agent enabled), AWS 08 (policies) |

## Context

Without policies every pod can reach every other pod and the internet; a compromised pod in one namespace
could probe the whole cluster. EKS needs a policy enforcer: the VPC CNI includes one (eBPF agent), off by
default.

## Decision drivers

- Least-privilege network access between workloads.
- No additional CNI or vendor to operate.
- Policies testable with positive and negative probes.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. VPC CNI network policy agent + Kubernetes NetworkPolicy, default deny** | Managed with the add-on; standard API | L3/L4 only; no FQDN or L7 rules |
| B. Calico (policy-only mode) | Rich policy model, global policies | Extra component on every node |
| C. Cilium | L7 and FQDN policies, observability | Replaces or chains the CNI; bigger learning curve |
| D. Security groups for pods | AWS-native SG rules per pod | Instance-type limits; different model from Kubernetes policies |

## Decision

Option A: `enable_network_policy = true` in AWS 07 (vpc-cni `enableNetworkPolicy`), and in AWS 08 a
namespace-wide default deny (ingress and egress) plus allows for DNS, the ALB subnets
(`10.70.0.0/23` → `:8000`) and the `load-generator` label.

## Consequences

**Positive:** `verify.sh` demonstrates allowed and denied flows; the `break-policy` drill shows the failure
mode.

**Negative:** the ALB allow is tied to AWS 07's subnet layout; every new dependency needs a new egress rule.

**Risks and tradeoffs:** label-based allows trust anyone allowed to create pods with that label in the
namespace (RBAC limits who can).

**Cost implications:** none.

**Security implications:** a large reduction in lateral movement; egress to the internet is denied for app
pods.
