# ADR-0002: One shared Helm chart, a small values file per environment, digest-only schema

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 09 and later Kubernetes labs |

## Context

Two environments must run the same application with different scale and exposure, deployed by Argo CD.
AWS 07/08 already express Taskboard as Kustomize manifests.

## Decision drivers

- One definition of the application, reusable by later labs.
- Environment differences small and reviewable.
- Invalid input (tags, open CIDRs, missing image) rejected before deployment.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. Helm chart in `shared/helm-charts/taskboard` + `environments/<env>/values.yaml` + `values.schema.json`** | Versioned package; schema validation; multi-source Argo CD apps | Templating logic to maintain alongside AWS 07/08's Kustomize |
| B. Kustomize overlays per environment (extend AWS 08) | No templating | No schema validation or packaging; overlays multiply |
| C. Separate manifests per environment | Explicit | Copy-paste drift between environments |
| D. Helm chart with values in the chart directory | Simple paths | Environment changes become chart changes |

## Decision

Option A. The chart mirrors the AWS 07/08 objects (same security context, probes, rollout strategy, HPA,
PDB, NetworkPolicies, optional ALB Ingress), omits `replicas` when autoscaling is enabled, and its schema
accepts only `sha256:` digests and rejects `0.0.0.0/0`. Values files live outside the chart and reach Argo
CD through a second source (`ref: values`).

## Consequences

**Positive:** promotion is a two-line diff; `scripts/validate.sh helm` lints and renders every environment.

**Negative:** the Kustomize manifests in AWS 07/08 and the chart describe the same app twice — kept
intentionally because those labs teach raw objects; future labs use the chart.

**Risks and tradeoffs:** the initial values contain a placeholder digest until `promote.sh dev` runs;
Argo CD would show a Degraded app if bootstrapped first (README orders the steps).

**Cost implications:** none.

**Security implications:** the schema turns policy (digests only, no open ALB) into a hard gate.
