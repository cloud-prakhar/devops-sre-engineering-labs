# ADR-0001: Docker Compose on a single VM for the multi-service stack

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 03 |

## Context

Taskboard now has four processes: proxy, frontend, API and database. They need declared networks,
volumes, secrets, start-up ordering and restart policies. The lab must stay within the free tier and
teach multi-container fundamentals before orchestration.

## Decision drivers

- Declarative, version-controlled description of the whole stack.
- Runs identically on a laptop (`local-test.sh`) and on the VM.
- No paid control plane or load balancer.
- Every moving part inspectable with standard Docker commands.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. Docker Compose on one EC2 instance** | Simple; same file locally and remotely; free | Single host = single failure domain; no rolling updates; no rescheduling |
| B. Shell scripts with `docker run` | No new tool | Imperative, order-dependent, hard to review; networks/secrets by hand |
| C. Amazon ECS on EC2 / Fargate | Managed scheduling, rolling deploys, service discovery | Fargate is not free; needs ALB for routing (billed); hides Docker fundamentals |
| D. Kubernetes (k3s on the VM, or EKS) | Industry standard orchestration | k3s on 1 GiB is tight; EKS control plane is billed hourly; covered in AWS 07+ |
| E. Docker Swarm single node | Native secrets with uid/mode, rolling updates | Declining ecosystem; little transfer to job market |

## Decision

Option A. One `compose.yaml` with a shared hardening anchor; deploy by syncing files to the VM and running
`docker compose up -d --build --wait` there, so secrets are generated and kept on the host.

## Consequences

**Positive:** the full stack is described in ~120 lines; `local-test.sh` gives fast, free feedback with
the exact same file; failure drills are easy to reproduce.

**Negative:** a deploy rebuilds and recreates changed services with a brief interruption; an instance
failure takes everything down; capacity is one t3.micro.

**Risks and tradeoffs:** building on the VM uses CPU credits (standard mode throttles rather than bills);
Compose secret files have no rotation or audit.

**Cost implications:** $0 beyond the instance and its public IPv4 address (see [cost](../cost.md)).

**Security implications:** only the proxy publishes ports; the database is on an internal network;
all containers run read-only without capabilities.

## Revisit when

Availability matters (AWS 05: ALB + Auto Scaling) or the team needs rolling deploys and scheduling
(AWS 07–08: EKS).
