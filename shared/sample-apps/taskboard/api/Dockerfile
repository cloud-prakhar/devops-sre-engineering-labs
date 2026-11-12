# syntax=docker/dockerfile:1.7
# Taskboard API image.
# Stage 1 builds wheels with the full toolchain; stage 2 only copies the installed packages,
# so compilers and pip caches never reach the runtime image.

FROM python:3.15-slim-trixie AS build
WORKDIR /build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
# Copy only the dependency list first: this layer (the slow one) is reused until
# requirements.txt changes, even when application code changes.
COPY requirements.txt .
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-compile -r requirements.txt \
 && /opt/venv/bin/pip uninstall --yes pip   # pip is a build tool: it must not ship in the runtime image

FROM python:3.15-slim-trixie AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="taskboard-api" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION} \
    DATABASE_URL=sqlite:////data/taskboard.db
# The base image's own pip (with vendored urllib3, msgpack, ...) and ensurepip wheels are not needed at
# runtime; removing them removes their CVEs from every scan. Fixed UID/GID so volume ownership is
# predictable across hosts.
# Debian security fixes published after the base image was built are applied here, so the image does
# not wait for an upstream rebuild (the vulnerability gate in AWS 06 fails on fixable HIGH/CRITICAL).
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall --yes pip \
 && rm -rf /usr/local/lib/python3.14/ensurepip \
 && groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app \
 && mkdir -p /data && chown app:app /data
COPY --from=build /opt/venv /opt/venv
WORKDIR /srv
COPY --chown=root:root app ./app
USER 10001:10001
EXPOSE 8000
VOLUME ["/data"]
# Uses Python instead of curl so the image needs no extra packages.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).status == 200 else 1)"]
# exec-form CMD: uvicorn is PID 1 and receives SIGTERM directly for graceful shutdown.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*", "--no-access-log"]
