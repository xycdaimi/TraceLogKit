#!/bin/bash
# ========================================
# TraceLogKit - Stop infrastructure containers
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "========================================"
echo "   TraceLogKit - Stop Infrastructure"
echo "========================================"
echo ""

if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running."
  exit 1
fi

echo "[1/6] Stopping Grafana..."
cd "$SCRIPT_DIR/../docker/grafana"
docker compose down 2>/dev/null || true
echo "[OK] Grafana stopped"

echo "[2/6] Stopping Promtail..."
cd "$SCRIPT_DIR/../docker/promtail"
docker compose down 2>/dev/null || true
echo "[OK] Promtail stopped"

echo "[3/6] Stopping Loki..."
cd "$SCRIPT_DIR/../docker/loki"
docker compose down 2>/dev/null || true
echo "[OK] Loki stopped"

echo "[4/6] Stopping Prometheus..."
cd "$SCRIPT_DIR/../docker/prometheus"
docker compose down 2>/dev/null || true
echo "[OK] Prometheus stopped"

echo "[5/6] Stopping OTel Collector..."
cd "$SCRIPT_DIR/../docker/otel-collector"
docker compose down 2>/dev/null || true
echo "[OK] OTel Collector stopped"

echo "[6/6] Stopping Tempo..."
cd "$SCRIPT_DIR/../docker/tempo"
docker compose down 2>/dev/null || true
echo "[OK] Tempo stopped"

cd "$SCRIPT_DIR/.."

echo ""
echo "========================================"
echo "   TraceLogKit Stopped!"
echo "========================================"
echo ""
echo "Note: Data volumes are preserved."
echo "To remove volumes, run 'docker compose down -v' in each directory."
echo ""

