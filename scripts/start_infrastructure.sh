#!/bin/bash
# ========================================
# TraceLogKit - Start infrastructure containers
# Includes: Tempo, OTel Collector, Prometheus(+exporters), Grafana, Loki, Promtail
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "========================================"
echo "   TraceLogKit - Start Infrastructure"
echo "========================================"
echo ""
echo "Project Root: $(pwd)"
echo ""

if [ ! -f ".env" ]; then
  echo "[WARNING] .env file not found in TraceLogKit root"
  echo "Services will use default values or environment variables"
  echo ""
fi

if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi
echo "[OK] Docker is running"
echo ""

trace_net="${TRACELOGKIT_NETWORK_NAME:-tracelogkit-network}"
if [ -f "$SCRIPT_DIR/../.env" ]; then
  v="$(grep -E '^TRACELOGKIT_NETWORK_NAME=' "$SCRIPT_DIR/../.env" | tail -n1 | cut -d= -f2- | tr -d '\r' | tr -d ' ')"
  if [ -n "$v" ]; then trace_net="$v"; fi
fi
if ! docker network inspect "$trace_net" >/dev/null 2>&1; then
  echo "[INFO] Creating docker network: $trace_net"
  docker network create "$trace_net" >/dev/null
fi

echo "[1/6] Starting Tempo..."
cd "$SCRIPT_DIR/../docker/tempo"
docker compose --env-file ../../.env up -d
sleep 2

echo ""
echo "[2/6] Starting OTel Collector..."
cd "$SCRIPT_DIR/../docker/otel-collector"
docker compose --env-file ../../.env up -d
sleep 2

echo ""
profile_args=""


echo ""
echo "[3/6] Starting Prometheus..."
cd "$SCRIPT_DIR/../docker/prometheus"
docker compose --env-file ../../.env $profile_args up -d --build
sleep 2

echo ""
echo "[4/6] Starting Loki..."
cd "$SCRIPT_DIR/../docker/loki"
docker compose --env-file ../../.env up -d
sleep 2

echo ""
echo "[5/6] Starting Promtail..."
cd "$SCRIPT_DIR/../docker/promtail"
docker compose --env-file ../../.env up -d
sleep 2

echo ""
echo "[6/6] Starting Grafana..."
cd "$SCRIPT_DIR/../docker/grafana"
docker compose --env-file ../../.env up -d
sleep 2

cd "$SCRIPT_DIR/.."

echo ""
echo "========================================"
echo "   TraceLogKit Started!"
echo "========================================"
echo ""
echo "Service URLs:"
echo "  - Grafana:     http://localhost:3000"
echo "  - Tempo:       http://localhost:3200/ready"
echo "  - Loki:        http://localhost:3100/ready"
echo "  - Prometheus:  http://localhost:9090"
echo "  - OTLP gRPC:   localhost:4317"
echo "  - OTLP HTTP:   http://localhost:4318"
echo ""
echo "Run 'docker ps' to check container status"
echo "Run 'TraceLogKit/scripts/stop_infrastructure.sh' to stop all"
echo ""

