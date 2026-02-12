#!/bin/bash
# PostgreSQL Container Stop Script

echo "Stopping PostgreSQL container..."

# Change to script directory
cd "$(dirname "$0")"

# Stop container
docker-compose down

echo "PostgreSQL container stopped successfully!"

