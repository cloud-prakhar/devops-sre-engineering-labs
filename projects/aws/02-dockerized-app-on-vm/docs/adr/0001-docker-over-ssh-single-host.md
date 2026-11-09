# ADR-0001: Build and run on the VM through a remote Docker daemon over SSH, no registry

| | |
|---|---|
| **Status** | Accepted (lab scope); superseded for multi-host delivery by AWS 06 |
| **Date** | 2026-11-09 |
| **Scope** | AWS 02 |

## Context

The image must get from source to one EC2 host. The lab should teach containers, not CI/CD or registry
IAM, and must stay inside the free tier.

## Decision drivers

- One host, one operator, short-lived lab.
- No extra services or IAM roles to learn before Docker basics.
- Zero cost beyond the instance.
- Reproducible from a clean laptop with Docker CLI + SSH.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. `DOCKER_HOST=ssh://` — build on the VM** | No registry; teaches the client/daemon split; nothing new to pay for | Builds use the VM's 1 GiB RAM; every host builds its own image; `ubuntu` must be in the `docker` group |
| B. Push to Amazon ECR, pull on the VM | Production-like; one artefact for many hosts | Needs an instance role with ECR read, repository lifecycle policy, storage cost after the free allowance; covered properly in AWS 06 |
| C. `docker save | ssh docker load` | No registry, builds on the faster laptop | Transfers the whole image each time (~160 MB), no layer reuse; CPU-architecture mismatch on Apple Silicon unless `--platform` |
| D. Docker Hub public repo | Free | Publishes the image publicly; pull rate limits; credentials management |

## Decision

Option A. `deploy.sh` exports `DOCKER_HOST=ssh://ubuntu@<ip>` and calls `taskboard-ctl.sh`, which is the
same script `local-test.sh` runs against the local daemon. One script, two daemons.

## Consequences

**Positive:** no registry or credentials; the build context is the only data sent; layer cache on the
VM makes repeat deploys fast; learners see that the Docker CLI is only an API client.

**Negative:** builds happen on a small, burstable instance (mitigated by the 1 GiB swap file and
standard credits); no image provenance, signing or scanning in the delivery path.

**Risks and tradeoffs:** `docker` group membership is root-equivalent — anyone with the `ubuntu` SSH
key controls the host. Acceptable because the host is single-tenant and disposable.

**Cost implications:** none additional. ECR would add storage cost and is avoided.

**Security implications:** SSH (already locked to one IP) is the only control path; the Docker socket is
never exposed over TCP.

## Revisit when

There is more than one host (AWS 05) or a CI pipeline (AWS 06): build once, scan, push to ECR, deploy
by digest.
