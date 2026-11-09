# AWS 03 — Hands-on exercises

Run on the VM in `/opt/lab03` (`ssh ubuntu@<ip>`), or locally with `scripts/local-test.sh --keep` and
`cd stack` (local ports are 18080/18443 instead of 80/443).

```mermaid
flowchart LR
    e1[1 Compose model]:::app --> e2[2 Service discovery]:::net --> e3[3 Network isolation]:::sec
    e3 --> e4[4 TLS]:::sec --> e5[5 Secrets]:::sec --> e6[6 Start-up order]:::k8s
    e6 --> e7[7 Backup & restore]:::data --> e8[8 Failure drills]:::risk --> e9[9 Limits & logs]:::obs
    classDef app fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef net fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef sec fill:#ffedd5,stroke:#c2410c,color:#7c2d12
    classDef k8s fill:#ede9fe,stroke:#6d28d9,color:#4c1d95
    classDef data fill:#fef9c3,stroke:#a16207,color:#713f12
    classDef risk fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
    classDef obs fill:#ccfbf1,stroke:#0f766e,color:#134e4a
```

## 1. The Compose model

```bash
docker compose config | less          # fully resolved file: anchors merged, .env substituted
docker compose ps
docker compose images
docker network ls --filter label=com.docker.compose.project=taskboard
docker volume ls --filter label=com.docker.compose.project=taskboard
```

**Expected:** the `x-hardening` anchor appears expanded in every service; four containers, two
networks (`taskboard_edge`, `taskboard_backend`), two volumes. Explain what Compose adds over `docker
run` (declarative desired state, project scoping, ordering) and what it does not (multi-host
scheduling, rescheduling after host failure).

## 2. Service discovery through embedded DNS

```bash
docker compose exec api python -c "import socket; print(socket.gethostbyname('db'))"
docker compose exec proxy cat /etc/resolv.conf          # nameserver 127.0.0.11
docker compose exec proxy nslookup api 127.0.0.11
docker compose exec proxy nslookup db 127.0.0.11        # fails: proxy is not on backend
```

**Expected:** service names resolve only on networks the container shares with the service. `proxy`
cannot even resolve `db`. Explain why nginx uses `set $api_upstream http://api:8000;` plus `resolver`
instead of `proxy_pass http://api:8000;` (without variables, nginx resolves once at start and fails to
start if `api` does not exist yet).

## 3. Network isolation

```bash
docker network inspect taskboard_backend --format '{{.Internal}} {{range .Containers}}{{.Name}} {{end}}'
docker run --rm --network taskboard_backend alpine:3.23 wget -T 3 -O /dev/null https://example.com   # fails
docker run --rm --network taskboard_edge postgres:18-alpine pg_isready -h db -t 3                     # fails
docker compose exec db sh -c 'cat /proc/net/route'      # no default route
sudo ss -tlnp | grep -E ':(80|443|5432|8000)\b'
```

**Expected:** `Internal: true`, only `api` and `db` are members; no internet from `backend`; no host
socket on 5432 or 8000. Draw the reachability matrix (who can open a connection to whom).

## 4. TLS

```bash
echo | openssl s_client -connect <ip>:443 -servername <ip> 2>/dev/null | openssl x509 -noout -subject -dates -ext subjectAltName
curl -vk https://<ip>/api/info 2>&1 | grep -E 'SSL connection|ALPN|subject'
curl -v --tlsv1.2 --tls-max 1.2 -k https://<ip>/ -o /dev/null 2>&1 | grep 'SSL connection'
curl -I http://<ip>/api/info
```

**Expected:** `CN=taskboard-lab`, valid 30 days, SAN `IP Address:<ip>`; TLS 1.3 with ALPN `h2`; TLS 1.2
also accepted; HTTP returns `301`. Explain the browser warning (no trusted CA signed the certificate)
and the path to a trusted certificate (domain name + ACME/Let's Encrypt, or ACM on a load balancer in
AWS 05).

## 5. Secrets

```bash
docker compose exec api ls -l /run/secrets/
docker compose exec api env | grep -i -E 'pass|database'
docker inspect "$(docker compose ps -q api)" --format '{{json .Config.Env}}' | jq
stat -c '%a %U %n' secrets secrets/db_password.txt
```

**Expected:** the password is only in `/run/secrets/db_password`; `DATABASE_URL` has no password;
`docker inspect` shows no secret. Explain what Compose secrets are without Swarm (bind-mounted files —
host permissions apply) and what a real secret manager would add (rotation, audit, encryption at rest —
AWS Secrets Manager in AWS 15).

## 6. Start-up ordering and dependency restarts

```bash
docker compose down            # volumes are kept
docker compose up -d && docker compose events --json | jq -r '.service + " " + .action' &
sleep 60; kill %1
docker compose restart db
docker compose ps --format '{{.Service}} {{.Status}}'
```

**Expected:** `db` becomes healthy before `api` starts; `proxy` starts last. `docker compose restart db`
also restarts `api` (`restart: true`). Explain why `depends_on` does not help if `db` dies *later*
without Compose being involved — that is what `/readyz` and the API's per-request connections are for.

## 7. Backup and restore

```bash
./backup-db.sh
ls -lh backups/
curl -sk -X POST https://localhost/api/tasks -H 'content-type: application/json' -d '{"title":"written after backup"}'
./restore-db.sh "$(ls -1t backups/*.dump | head -n1)"
curl -sk https://localhost/api/tasks | jq '.[].title'
```

**Expected:** the task written after the backup is gone — the recovery point is the backup time.
Measure how long the restore took (recovery time). Answer: where must backups live to survive the loss
of this VM (not on its own disk — S3 with lifecycle rules, AWS 10)?

## 8. Failure drills

| Run | Expected symptom | Recover | Playbook |
|---|---|---|---|
| `./failure-drill.sh db-down` | `/readyz` 503 and `GET /api/tasks` 500 within ~0.2 s (observed locally); occasionally 504 when the DNS lookup for the stopped `db` stalls — see [#5](troubleshooting.md#5-504-gateway-timeout); frontend 200 | `./failure-drill.sh recover` | [#4](troubleshooting.md#4-readyz-returns-503) |
| `./failure-drill.sh api-crash` | brief 502 on `/api/*` | restart policy | [#3](troubleshooting.md#3-502-bad-gateway) |
| `./failure-drill.sh api-partition` | `/readyz` 503 after ~3 s; api stays healthy | `recover` | [#4](troubleshooting.md#4-readyz-returns-503) |
| `./failure-drill.sh proxy-down` | connection refused on 80/443 | `recover` | [#1](troubleshooting.md#1-connection-refused-or-timeout-on-443) |
| `./failure-drill.sh recreate-api` | none, if DNS re-resolution works | — | [#3](troubleshooting.md#3-502-bad-gateway) |

For each, record: first symptom you saw, command that proved the cause, time to recover.

## 9. Resource limits and logs

```bash
docker stats --no-stream
docker compose exec proxy cat /sys/fs/cgroup/memory.max
for i in $(seq 1 100); do curl -sk -o /dev/null -w '%{http_code}\n' https://localhost/api/info & done | sort | uniq -c
docker compose logs proxy --since 1m | jq -r 'select(.status==429) | .remote' | sort | uniq -c
```

**Expected:** limits match `compose.yaml` (proxy 64 MiB); a burst produces some `429`s from the rate
limiter; JSON access logs make the `429` count a one-liner. Total limits ≈ 608 MiB on a 1 GiB host —
explain what happens if they are set above physical memory (overcommit: the host OOM killer decides
instead of the cgroup).
