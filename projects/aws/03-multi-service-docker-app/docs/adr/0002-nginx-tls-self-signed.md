# ADR-0002: TLS terminated at an NGINX container with a generated self-signed certificate

| | |
|---|---|
| **Status** | Accepted (lab scope) |
| **Date** | 2026-11-09 |
| **Scope** | AWS 03 |

## Context

Traffic between users and the stack must be encrypted, and HTTP must redirect to HTTPS. The lab has
no domain name — users connect to the instance's public IP — so public CAs (which validate domain
control) cannot issue a certificate. The solution must cost nothing and work without manual steps.

## Decision drivers

- HTTPS from the first deploy, without a domain.
- No paid services (ALB + ACM, Route 53).
- Realistic NGINX TLS and proxy configuration that transfers to real deployments.
- Easy path to a trusted certificate later.

## Considered alternatives

| Option | Pros | Cons |
|---|---|---|
| **A. NGINX + self-signed cert generated at start-up** | Free; automatic; SAN matches the IP; teaches real TLS config | Browser warning; clients must use `-k` or pin the cert |
| B. Let's Encrypt via certbot / Caddy | Trusted certificate, auto-renewal | Requires a domain you control and public port 80 for HTTP-01 |
| C. ALB with an ACM certificate | Managed TLS and renewal | ALB is billed hourly + LCU; needs a domain for a public ACM cert |
| D. Caddy as proxy | Automatic HTTPS with less config | Hides the TLS settings this lab teaches; still needs a domain for trust |
| E. Plain HTTP | Simplest | Credentials and data in clear text; teaches a bad default |

## Decision

Option A. A start-up hook in the official image's `/docker-entrypoint.d/` generates an ECDSA P-256
certificate valid 30 days for `TLS_SAN` (set to `IP:<public-ip>` by `deploy.sh`) and regenerates it
when the SAN changes. NGINX allows TLS 1.2 and 1.3 only, with HTTP/2 and session tickets disabled.

## Consequences

**Positive:** HTTPS works on first deploy; the configuration is production-shaped; swapping in a real
certificate only means placing `tls.crt`/`tls.key` in the `tls-certs` volume.

**Negative:** every client shows a trust warning; learners may get used to clicking through warnings —
the README calls this out explicitly.

**Risks and tradeoffs:** no HSTS (inappropriate for an IP with a self-signed certificate); the private
key lives in a Docker volume on the instance disk (encrypted EBS).

**Cost implications:** none.

**Security implications:** encryption in transit without authentication of the server to new clients;
acceptable for a lab, not for users who cannot verify the certificate fingerprint.
