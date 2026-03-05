#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker/postgres/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"

echo "========================================"
echo "  TraceLogKit - Start Postgres"
echo "========================================"
echo "Project Root: ${PROJECT_ROOT}"
echo "Compose File: ${COMPOSE_FILE}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker not found in PATH."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[ERROR] docker compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE_FILE}" ]]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "[WARN] .env not found. Created from .env.example: ${ENV_FILE}"
  else
    echo "[ERROR] .env not found and .env.example is missing. Please create ${ENV_FILE}."
    exit 1
  fi
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Neither 'docker compose' nor 'docker-compose' is available."
  exit 1
fi

echo "Starting PostgreSQL containers..."
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" up -d

echo "PostgreSQL containers started."
echo "Checking status..."
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" ps

echo "----------------------------------------"
echo "Primary:  localhost:5432"
echo "Replica:  localhost:5433"
echo "Database: \${DB_WRITE_DB:-admin} / \${DB_READ_DB:-admin} (from .env)"
echo "User:     \${DB_WRITE_USER:-admin} / \${DB_READ_USER:-admin} (from .env)"
echo "----------------------------------------"
echo "View logs:"
echo "  ${COMPOSE_CMD[*]} -f \"${COMPOSE_FILE}\" logs -f"
