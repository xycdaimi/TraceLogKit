#!/bin/bash
# Prometheus Stack Stop Script

set -e

echo "Stopping Prometheus stack..."

# Change to script directory
cd "$(dirname "$0")"

# Stop stack
docker compose down

echo "Prometheus stack stopped successfully!"
