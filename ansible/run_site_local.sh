#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "${DB_MASTER_PASSWORD:-}" ]; then
  echo "Error: DB_MASTER_PASSWORD is not set."
  echo "Run: export DB_MASTER_PASSWORD='RDS作成時のパスワード'"
  exit 1
fi

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  export SECRET_KEY_BASE
  SECRET_KEY_BASE=$(openssl rand -hex 64)
fi

ansible-playbook playbooks/site.yml
