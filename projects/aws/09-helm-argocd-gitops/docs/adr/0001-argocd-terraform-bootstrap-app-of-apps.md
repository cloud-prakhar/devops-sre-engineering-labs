# ADR-0001: Argo CD bootstrapped by Terraform, everything else app-of-apps from Git

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-12 |
| **Scope** | AWS 09 |

## Context

The cluster needs a GitOps agent. Something has to install it and point it at Git, and that something
should not keep managing what Git now owns.

## Decision drivers

- Reproducible bootstrap with the same tooling as the rest of the labs.
- After bootstrap, Git is the only source of truth.
- No `terraform apply` failures from CRDs that do not exist at plan time.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. Terraform: `helm_release` argo-cd + `helm_release` argocd-apps (root app only)** | One apply; no CRD planning problem; Terraform hands over to Git | Two Helm releases to upgrade |
| B. Terraform `kubernetes_manifest` for the root Application | Pure Terraform | Fails to plan before the CRD exists; needs two applies |
| C. `helm install` + `kubectl apply` from a script | Simple | Not declarative, no state, drift-prone |
| D. Flux (`flux bootstrap`) | Bootstraps itself into Git | Different tool; the lab targets Argo CD |
| E. Terraform manages every Application | Single tool | Terraform and Argo CD fight over the same objects; deploys need Terraform access |

## Decision

Option A. Argo CD chart 10.18.0 (v3.6.1) with a minimal footprint (no Dex or notifications, small
requests), and argocd-apps 2.0.8 creating one root Application (`gitops-root`) with the
`resources-finalizer`, pointing at `gitops/root` in your fork and passing the repository URL as Helm values.

## Consequences

**Positive:** one apply bootstraps everything; adding environments or apps never needs Terraform.

**Negative:** Argo CD upgrades are Terraform changes (or could later move into Git: Argo CD managing
itself).

**Risks and tradeoffs:** `server.insecure` relies on port-forward for transport security — fine for a lab,
not for an exposed UI.

**Cost implications:** no AWS resources; needs a third small node.

**Security implications:** the local admin account remains (rotate it, exercise); SSO via Dex/OIDC is the
production step.
