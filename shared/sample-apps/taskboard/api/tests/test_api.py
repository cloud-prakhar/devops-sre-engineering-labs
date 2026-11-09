import os

import pytest

os.environ["DATABASE_URL"] = "sqlite:///:memory:"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def test_health_and_readiness(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    ready = client.get("/readyz")
    assert ready.status_code == 200
    assert ready.json()["backend"] == "sqlite"


def test_task_lifecycle(client):
    created = client.post("/api/tasks", json={"title": "  patch the kernel  "})
    assert created.status_code == 201
    task = created.json()
    assert task["title"] == "patch the kernel"
    assert task["done"] is False

    assert any(t["id"] == task["id"] for t in client.get("/api/tasks").json())

    updated = client.patch(f"/api/tasks/{task['id']}", json={"done": True})
    assert updated.json()["done"] is True

    assert client.delete(f"/api/tasks/{task['id']}").status_code == 204
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 404


def test_validation_rejects_empty_title(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422


def test_readiness_fails_when_storage_breaks(client, monkeypatch):
    def broken():
        raise ConnectionError("db down")

    monkeypatch.setattr(app.state.storage, "ping", broken)
    resp = client.get("/readyz")
    assert resp.status_code == 503
    assert resp.json()["status"] == "not-ready"
    # Liveness must stay green: restarting the API would not fix a database outage.
    assert client.get("/healthz").status_code == 200


def test_metrics_use_route_templates(client):
    client.patch("/api/tasks/424242", json={"done": True})
    body = client.get("/metrics").text
    assert "taskboard_http_requests_total" in body
    assert 'route="/api/tasks/{task_id}"' in body
    assert "424242" not in body
