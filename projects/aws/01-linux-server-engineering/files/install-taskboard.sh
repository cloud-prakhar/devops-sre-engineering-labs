#!/usr/bin/env bash
# Installs or upgrades the Taskboard API as a systemd service.
# Run on the lab host:  sudo install-taskboard /tmp/taskboard-src
set -euo pipefail

SRC=${1:?usage: install-taskboard <source-dir containing app/ and requirements.txt>}
PREFIX=/opt/taskboard

[[ $EUID -eq 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }
[[ -f "$SRC/requirements.txt" && -d "$SRC/app" ]] || { echo "invalid source dir: $SRC" >&2; exit 1; }

# System account: no login shell, no home directory, cannot SSH (not in ssh-users).
if ! id taskboard >/dev/null 2>&1; then
  useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin taskboard
fi

install -d -o root -g root -m 0755 "$PREFIX" /etc/taskboard
# Code is owned by root and only readable by the service: a compromised process cannot
# rewrite its own code.
rsync -a --delete --chown=root:taskboard --chmod=D0750,F0640 "$SRC/app/" "$PREFIX/app/app/"
install -o root -g taskboard -m 0640 "$SRC/requirements.txt" "$PREFIX/app/requirements.txt"

if [[ ! -x "$PREFIX/venv/bin/python" ]]; then
  python3 -m venv "$PREFIX/venv"
fi
"$PREFIX/venv/bin/pip" install --quiet --disable-pip-version-check -r "$PREFIX/app/requirements.txt"

systemctl daemon-reload
systemctl enable taskboard.service
systemctl restart taskboard.service

for _ in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8000/readyz >/dev/null 2>&1; then
    echo "taskboard is ready: $(curl -fsS http://127.0.0.1:8000/api/info)"
    exit 0
  fi
  sleep 1
done
echo "taskboard did not become ready; check: journalctl -u taskboard -n 50 --no-pager" >&2
exit 1
