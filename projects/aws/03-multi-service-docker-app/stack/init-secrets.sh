#!/usr/bin/env bash
# Creates secrets/db_password.txt once, on the machine that runs the stack.
# The password is generated where it is used and never leaves that host.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
install -d -m 0700 secrets
if [[ -s secrets/db_password.txt ]]; then
  echo "secrets/db_password.txt exists, keeping it"
  exit 0
fi
umask 077
openssl rand -base64 32 | tr -d '/+=\n' | head -c 32 > secrets/db_password.txt
# Compose (without Swarm) bind-mounts secret files with their host permissions. The API runs
# as UID 10001 and PostgreSQL as UID 70, so the file must be world-readable; the 0700
# directory keeps other host users out.
chmod 0644 secrets/db_password.txt
echo "created secrets/db_password.txt"
