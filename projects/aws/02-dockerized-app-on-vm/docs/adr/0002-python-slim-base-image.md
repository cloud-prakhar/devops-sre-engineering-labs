# ADR-0002: `python:3.14-slim-trixie` multi-stage image instead of Alpine or distroless

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-09 |
| **Scope** | Shared Taskboard API image (all labs) |

## Context

The same API image is used by every lab on every cloud. It needs psycopg (PostgreSQL driver) and must be
small, patchable, debuggable by learners, and free of build tools at runtime.

## Decision drivers

- Compatible wheels for all dependencies (no compiling on a 1 GiB VM).
- Small attack surface and size.
- Learners can `docker exec ... sh` to explore.
- Regular upstream security rebuilds.

## Considered alternatives

| Option | Size (approx.) | Pros | Cons |
|---|---|---|---|
| **A. `python:3.14-slim-trixie`, multi-stage** | ~150 MB | glibc → prebuilt manylinux wheels (`psycopg[binary]`, `pydantic-core`); shell for learning; Debian security updates | Contains `sh`, `apt`, and Python; more packages to scan than distroless |
| B. `python:3.14-alpine` | ~80 MB | Smaller | musl libc: some wheels must compile from source; DNS and locale differences surprise learners |
| C. Distroless (`gcr.io/distroless/python3`) | ~70 MB | No shell or package manager; fewest CVEs | Python version tied to the distroless Debian release; no shell makes the debugging exercises impossible |
| D. Single-stage `python:3.14` | ~1 GB | Simplest | Ships compilers and headers; slow pulls; large CVE count |

## Decision

Option A, built in two stages: the build stage creates a virtualenv with all dependencies; the runtime
stage copies only `/opt/venv` (with pip uninstalled) and the app, applies pending Debian security
updates, removes the base image's pip and ensurepip wheels, creates UID/GID 10001, and declares a
`HEALTHCHECK` that uses Python's `urllib` (no curl needed).

## Consequences

**Positive:** fast installs from wheels; ~150 MB image; non-root with predictable volume ownership;
learners can inspect the container.

**Negative:** a shell and Python interpreter remain — useful to an attacker after an RCE. Compensated by
the runtime profile (read-only, no capabilities, `no-new-privileges`).

**Risks and tradeoffs:** base image tags float (`3.14-slim-trixie` gets rebuilt upstream). Builds are
reproducible only within a tag's lifetime; AWS 06 pins by digest and uses automated update PRs.

**Cost implications:** smaller images mean less registry storage (AWS 06) and faster node start-up on
Kubernetes (AWS 07+).

**Security implications:** rebuild regularly to pick up Debian patches; scan in CI (exercise 8 locally,
automated in AWS 06).
