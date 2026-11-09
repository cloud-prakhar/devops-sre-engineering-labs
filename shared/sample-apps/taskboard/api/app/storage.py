"""Storage backends for Taskboard.

Two backends share one interface so the same image runs in every lab:
- SQLite: single-container labs (project 02) where data lives on a Docker volume.
- PostgreSQL: multi-service labs (project 03 onward).

The backend is chosen from DATABASE_URL:
  sqlite:////data/taskboard.db
  postgresql://user@host:5432/dbname   (password from DATABASE_PASSWORD_FILE)
"""

from __future__ import annotations

import sqlite3
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Protocol
from urllib.parse import urlparse


@dataclass(frozen=True)
class Task:
    id: int
    title: str
    done: bool
    created_at: str

    def as_dict(self) -> dict:
        return {"id": self.id, "title": self.title, "done": self.done, "created_at": self.created_at}


class Storage(Protocol):
    backend: str

    def init_schema(self) -> None: ...
    def ping(self) -> None: ...
    def list_tasks(self) -> list[Task]: ...
    def create_task(self, title: str) -> Task: ...
    def set_done(self, task_id: int, done: bool) -> Task | None: ...
    def delete_task(self, task_id: int) -> bool: ...


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class SQLiteStorage:
    backend = "sqlite"

    def __init__(self, path: str) -> None:
        self.path = path
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        # One shared connection guarded by a lock: SQLite allows a single writer,
        # and uvicorn runs sync endpoints in a thread pool.
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._lock = threading.Lock()

    def init_schema(self) -> None:
        with self._lock, self._conn:
            self._conn.execute(
                "CREATE TABLE IF NOT EXISTS tasks ("
                " id INTEGER PRIMARY KEY AUTOINCREMENT,"
                " title TEXT NOT NULL,"
                " done INTEGER NOT NULL DEFAULT 0,"
                " created_at TEXT NOT NULL)"
            )

    def ping(self) -> None:
        with self._lock:
            self._conn.execute("SELECT 1").fetchone()

    def list_tasks(self) -> list[Task]:
        with self._lock:
            rows = self._conn.execute("SELECT id, title, done, created_at FROM tasks ORDER BY id").fetchall()
        return [Task(r[0], r[1], bool(r[2]), r[3]) for r in rows]

    def create_task(self, title: str) -> Task:
        created = _now()
        with self._lock, self._conn:
            cur = self._conn.execute(
                "INSERT INTO tasks (title, done, created_at) VALUES (?, 0, ?)", (title, created)
            )
        return Task(int(cur.lastrowid), title, False, created)

    def set_done(self, task_id: int, done: bool) -> Task | None:
        with self._lock, self._conn:
            self._conn.execute("UPDATE tasks SET done = ? WHERE id = ?", (int(done), task_id))
            row = self._conn.execute(
                "SELECT id, title, done, created_at FROM tasks WHERE id = ?", (task_id,)
            ).fetchone()
        return Task(row[0], row[1], bool(row[2]), row[3]) if row else None

    def delete_task(self, task_id: int) -> bool:
        with self._lock, self._conn:
            cur = self._conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
        return cur.rowcount > 0


class PostgresStorage:
    backend = "postgresql"

    def __init__(self, url: str, connect_timeout: int = 3, password: str | None = None) -> None:
        import psycopg  # imported lazily so SQLite-only runs do not need libpq

        self._psycopg = psycopg
        self.url = url
        self.connect_timeout = connect_timeout
        # Passed separately so the secret can come from a file instead of the URL/environment.
        self._extra = {"password": password} if password else {}

    def _connect(self):
        # A short connect timeout makes /readyz fail fast when the database is down,
        # instead of hanging the health check and every request behind it.
        return self._psycopg.connect(
            self.url, connect_timeout=self.connect_timeout, autocommit=True, **self._extra
        )

    def init_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS tasks ("
                " id BIGSERIAL PRIMARY KEY,"
                " title TEXT NOT NULL,"
                " done BOOLEAN NOT NULL DEFAULT FALSE,"
                " created_at TEXT NOT NULL)"
            )

    def ping(self) -> None:
        with self._connect() as conn:
            conn.execute("SELECT 1").fetchone()

    def list_tasks(self) -> list[Task]:
        with self._connect() as conn:
            rows = conn.execute("SELECT id, title, done, created_at FROM tasks ORDER BY id").fetchall()
        return [Task(r[0], r[1], r[2], r[3]) for r in rows]

    def create_task(self, title: str) -> Task:
        created = _now()
        with self._connect() as conn:
            row = conn.execute(
                "INSERT INTO tasks (title, done, created_at) VALUES (%s, FALSE, %s) RETURNING id",
                (title, created),
            ).fetchone()
        return Task(row[0], title, False, created)

    def set_done(self, task_id: int, done: bool) -> Task | None:
        with self._connect() as conn:
            row = conn.execute(
                "UPDATE tasks SET done = %s WHERE id = %s RETURNING id, title, done, created_at",
                (done, task_id),
            ).fetchone()
        return Task(row[0], row[1], row[2], row[3]) if row else None

    def delete_task(self, task_id: int) -> bool:
        with self._connect() as conn:
            cur = conn.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
        return cur.rowcount > 0


def storage_from_url(url: str, connect_timeout: int = 3, password: str | None = None) -> Storage:
    parsed = urlparse(url)
    if parsed.scheme == "sqlite":
        # sqlite:////abs/path.db -> /abs/path.db ; sqlite:///:memory: -> :memory:
        path = url.split("sqlite:///", 1)[1] if "sqlite:///" in url else ""
        return SQLiteStorage(path or ":memory:")
    if parsed.scheme in ("postgresql", "postgres"):
        return PostgresStorage(url, connect_timeout, password)
    raise ValueError(f"Unsupported DATABASE_URL scheme: {parsed.scheme!r}")
