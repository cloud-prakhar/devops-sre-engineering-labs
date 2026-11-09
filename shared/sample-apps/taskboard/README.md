# Taskboard — shared sample application

Taskboard is the workload deployed by every lab in this repository. Using one application everywhere
lets you compare clouds and techniques fairly: when the platform changes, the app does not.

```mermaid
flowchart LR
    user([Browser]):::client --> fe[frontend<br/>NGINX static files]:::app
    user -->|/api/*| api[api<br/>FastAPI + Uvicorn]:::app
    api -->|DATABASE_URL| db[(SQLite file<br/>or PostgreSQL)]:::data
    prom[Prometheus]:::obs -.->|scrape /metrics| api
    classDef client fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
    classDef app fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef data fill:#fef9c3,stroke:#a16207,color:#713f12
    classDef obs fill:#ccfbf1,stroke:#0f766e,color:#134e4a
```

| Component | Path | Image base | Port | Runs as |
|---|---|---|---|---|
| API | [api/](api/) | `python:3.14-slim-trixie` (multi-stage) | 8000 | UID 10001 |
| Frontend | [frontend/](frontend/) | `nginxinc/nginx-unprivileged:1.31-alpine` | 8080 | UID 101 |

## API contract

| Method | Path | Purpose | Notes |
|---|---|---|---|
| GET | `/healthz` | Liveness | Never checks dependencies. A DB outage must not trigger restarts. |
| GET | `/readyz` | Readiness | Returns 503 when the database does not answer within `DB_CONNECT_TIMEOUT`. |
| GET | `/api/info` | Version, hostname, backend | Shows which instance served you behind a load balancer. |
| GET/POST | `/api/tasks` | List / create | Title is 1–200 characters. |
| PATCH/DELETE | `/api/tasks/{id}` | Update / delete | 404 for unknown IDs. |
| GET | `/metrics` | Prometheus metrics | Labels use route templates to keep cardinality bounded. |

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `DATABASE_URL` | `sqlite:////data/taskboard.db` | `sqlite:////abs/path.db` or `postgresql://user:pass@host:5432/db` |
| `DATABASE_PASSWORD_FILE` | unset | File containing the PostgreSQL password (Docker/Kubernetes secret). Preferred over a password in the URL. |
| `DB_CONNECT_TIMEOUT` | `3` | Seconds before a PostgreSQL connection attempt fails |
| `APP_VERSION` | `dev` | Reported by `/api/info`; set at build time with `--build-arg APP_VERSION=...` |
| `LOG_LEVEL` | `INFO` | Logs are JSON lines on stdout |

## Run and test locally

```bash
cd shared/sample-apps/taskboard/api
python3.14 -m venv .venv && . .venv/bin/activate      # Python 3.14 required
pip install -r requirements-dev.txt
pytest -q                                   # unit tests
DATABASE_URL=sqlite:///./taskboard.db uvicorn app.main:app --port 8000
```

```bash
# Container build (from the repository root)
docker build -t taskboard-api:dev shared/sample-apps/taskboard/api
docker build -t taskboard-frontend:dev shared/sample-apps/taskboard/frontend
```

Labs that use it: [AWS 01](../../../projects/aws/01-linux-server-engineering/) (systemd service),
[AWS 02](../../../projects/aws/02-dockerized-app-on-vm/) (single container),
[AWS 03](../../../projects/aws/03-multi-service-docker-app/) (Compose stack).
