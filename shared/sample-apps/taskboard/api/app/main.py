"""Taskboard API — the sample workload used across all labs.

Endpoints
  GET    /healthz          liveness: the process is up (never touches dependencies)
  GET    /readyz           readiness: the database answers; 503 otherwise
  GET    /api/info         version, hostname and backend (useful behind load balancers)
  GET    /api/tasks        list tasks
  POST   /api/tasks        create a task {"title": "..."}
  PATCH  /api/tasks/{id}   update {"done": true|false}
  DELETE /api/tasks/{id}   delete a task
  GET    /metrics          Prometheus metrics
"""

from __future__ import annotations

import json
import logging
import os
import socket
import sys
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

from .storage import Storage, storage_from_url

APP_VERSION = os.getenv("APP_VERSION", "dev")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:////data/taskboard.db")
DB_CONNECT_TIMEOUT = int(os.getenv("DB_CONNECT_TIMEOUT", "3"))
# Docker/Kubernetes secrets are mounted as files; reading them keeps passwords out of
# `docker inspect`, /proc/<pid>/environ and crash dumps.
DATABASE_PASSWORD_FILE = os.getenv("DATABASE_PASSWORD_FILE")


def read_secret(path: str | None) -> str | None:
    if not path:
        return None
    with open(path, encoding="utf-8") as fh:
        return fh.read().strip()


class JsonFormatter(logging.Formatter):
    """One JSON object per line, so log shippers can parse fields without regex."""

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(record.created)) + "Z",
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        payload.update(getattr(record, "extra_fields", {}))
        return json.dumps(payload)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
log = logging.getLogger("taskboard")
log.handlers = [handler]
log.setLevel(os.getenv("LOG_LEVEL", "INFO"))
log.propagate = False

REQUESTS = Counter(
    "taskboard_http_requests_total", "HTTP requests", ["method", "route", "status"]
)
LATENCY = Histogram(
    "taskboard_http_request_duration_seconds", "HTTP request latency", ["method", "route"]
)


def get_storage(app: FastAPI) -> Storage:
    return app.state.storage


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.storage = storage_from_url(
        DATABASE_URL, DB_CONNECT_TIMEOUT, read_secret(DATABASE_PASSWORD_FILE)
    )
    # Schema creation is retried by the orchestrator (restart policy) if the DB is not up yet.
    # We log instead of crashing so /healthz stays up and /readyz reports the real problem.
    try:
        app.state.storage.init_schema()
        log.info("schema ready", extra={"extra_fields": {"backend": app.state.storage.backend}})
    except Exception as exc:  # noqa: BLE001 - surface any driver error in logs
        log.error("schema init failed", extra={"extra_fields": {"error": str(exc)}})
    yield


app = FastAPI(title="Taskboard API", version=APP_VERSION, lifespan=lifespan)


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        # Use the route template (/api/tasks/{task_id}), not the raw path, to keep
        # metric cardinality bounded.
        route_name = route.path if route is not None else "unmatched"
        elapsed = time.perf_counter() - start
        REQUESTS.labels(request.method, route_name, str(status)).inc()
        LATENCY.labels(request.method, route_name).observe(elapsed)
        if route_name not in ("/healthz", "/metrics"):
            log.info(
                "request",
                extra={
                    "extra_fields": {
                        "method": request.method,
                        "route": route_name,
                        "status": status,
                        "duration_ms": round(elapsed * 1000, 2),
                    }
                },
            )


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class TaskPatch(BaseModel):
    done: bool


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response) -> dict:
    try:
        get_storage(app).ping()
        return {"status": "ready", "backend": get_storage(app).backend}
    except Exception as exc:  # noqa: BLE001
        response.status_code = 503
        log.warning("readiness failed", extra={"extra_fields": {"error": str(exc)}})
        return {"status": "not-ready", "error": exc.__class__.__name__}


@app.get("/api/info")
def info() -> dict:
    return {
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "backend": get_storage(app).backend,
    }


@app.get("/api/tasks")
def list_tasks() -> list[dict]:
    return [t.as_dict() for t in get_storage(app).list_tasks()]


@app.post("/api/tasks", status_code=201)
def create_task(body: TaskIn) -> dict:
    return get_storage(app).create_task(body.title.strip()).as_dict()


@app.patch("/api/tasks/{task_id}")
def update_task(task_id: int, body: TaskPatch) -> dict:
    task = get_storage(app).set_done(task_id, body.done)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    return task.as_dict()


@app.delete("/api/tasks/{task_id}", status_code=204)
def delete_task(task_id: int) -> Response:
    if not get_storage(app).delete_task(task_id):
        raise HTTPException(status_code=404, detail="task not found")
    return Response(status_code=204)


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
