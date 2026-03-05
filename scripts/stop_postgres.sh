#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker/postgres/docker-compose.yml"

echo "========================================"
echo "  TraceLogKit - Stop Postgres"
echo "========================================"
echo "Project Root: ${PROJECT_ROOT}"
echo "Compose File: ${COMPOSE_FILE}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker not found in PATH."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Nothing to stop."
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[ERROR] docker compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Neither 'docker compose' nor 'docker-compose' is available."
  exit 1
fi

echo "Stopping PostgreSQL containers (docker compose down)..."
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" down

echo "PostgreSQL containers stopped."
