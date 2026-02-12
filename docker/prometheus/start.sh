#!/bin/bash
# Prometheus Stack Start Script
# Includes: Prometheus, Redis Exporter, Postgres Exporter, Kafka Exporter

set -e

echo "Starting Prometheus stack..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Change to script directory
cd "$(dirname "$0")"

# Start stack
docker compose --env-file ../../.env up -d --build

# Wait for containers to start
echo "Waiting for Prometheus stack to start..."
sleep 5

# Check container status
if docker compose ps | grep -q "Up"; then
    echo "Prometheus stack started successfully!"
    echo ""
    echo "Prometheus UI:        http://localhost:9090"
    echo "Redis Exporter:       http://localhost:9121/metrics"
    echo "Postgres Exporter:    http://localhost:9187/metrics"
    echo "Kafka Exporter:       http://localhost:9308/metrics"
    echo ""
    echo "Run 'docker compose logs -f' to view logs"
else
    echo "ERROR: Failed to start Prometheus stack"
    echo "Run 'docker compose logs' to see error details"
    exit 1
fi
