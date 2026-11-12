# ADR-0001: ALB Ingress through the AWS Load Balancer Controller with IP targets

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 08 |

## Context

The Taskboard API on EKS must be reachable over HTTP from outside the cluster, with health-checked
routing to pods, and the setup must teach the dominant EKS pattern.

## Decision drivers

- Standard, production-relevant on EKS.
- Per-pod health checks and fast draining.
- One load balancer that can later serve several services.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. Ingress → ALB, `target-type: ip`** | L7 routing, one ALB for many services, direct-to-pod | Controller to install and secure; ALB billed |
| B. `Service type: LoadBalancer` (NLB) | Simple L4 | One NLB per service; no path routing |
| C. Ingress with `target-type: instance` | Works with any CNI | Extra hop via NodePort/kube-proxy; node-level health checks |
| D. Gateway API (controller's Gateway support) | Successor to Ingress, role-oriented | Newer; most existing clusters and interview questions still use Ingress |
| E. NGINX Ingress Controller behind an NLB | Portable across clouds | Two layers of load balancing to run and patch |

## Decision

Option A with the AWS Load Balancer Controller v3.6.2 (Helm chart 3.6.2), credentials via Pod Identity and
the vendored official IAM policy, Ingress annotations for `internet-facing`, `ip` targets, `/readyz`
health checks, a 30 s deregistration delay, your CIDR as `inbound-cidrs`, and repository tags.

## Consequences

**Positive:** traffic reaches pods in one hop; NetworkPolicy sees and can restrict the ALB's source range.

**Negative:** resources created by the controller are outside Terraform; teardown order matters.

**Risks and tradeoffs:** the controller's IAM policy is broad by necessity (it manages load balancers and
security groups); scope is limited by tag conditions in the official policy and by Pod Identity.

**Cost implications:** ≈ $0.04/hour for the ALB and its IPv4 addresses; see [cost](../cost.md).

**Security implications:** HTTP only and restricted to one CIDR in the lab; production adds HTTPS (ACM),
WAF and redirect rules.
