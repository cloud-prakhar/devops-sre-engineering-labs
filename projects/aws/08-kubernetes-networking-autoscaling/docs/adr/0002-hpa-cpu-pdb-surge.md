# ADR-0002: HPA on CPU, a PodDisruptionBudget, and surge-only rollouts

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 08 |

## Context

Capacity must follow load, and deploys and node maintenance must not drop requests, on a small cluster
without node autoscaling.

## Decision drivers

- Built-in components only (metrics-server is an AWS 07 add-on).
- Behaviour learners can predict and verify.
- Never reduce serving capacity during voluntary changes.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. HPA on CPU utilisation + PDB `minAvailable: 1` + `maxSurge 1 / maxUnavailable 0`** | Built in; predictable formula; safe rollouts and drains | CPU is a proxy for load; needs correct requests |
| B. HPA on request rate (custom metrics via Prometheus adapter) | Closer to user load | Needs Prometheus (AWS 11) |
| C. KEDA | Event-driven, scale to zero | Another controller to run |
| D. VPA | Right-sizes requests | Restarts pods; conflicts with HPA on the same metric |
| E. Fixed replicas | Simple | Over- or under-provisioned |

## Decision

Option A: HPA 2–6 replicas at 60% of the 50m CPU request, scale-up up to 2 pods per 30 s, scale-down
after 120 s stabilisation at 1 pod per minute; the kustomization removes `spec.replicas` so the HPA owns
it; PDB `minAvailable: 1`.

## Consequences

**Positive:** load drill, rollout drill and drain drill all keep the probe green (by design; to be
confirmed in a real deployment).

**Negative:** pods can stay `Pending` when nodes are full — the HPA scales pods, not nodes.

**Risks and tradeoffs:** a PDB with `minAvailable` equal to the replica count would block drains; kept below
`minReplicas`.

**Cost implications:** none directly; more replicas use existing node capacity.

**Security implications:** none.
