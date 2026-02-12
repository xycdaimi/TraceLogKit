#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker compose --env-file ../../.env up -d
echo "[OK] Tempo started: http://localhost:3200/ready"
