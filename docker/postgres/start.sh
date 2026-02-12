#!/bin/bash
# PostgreSQL Container Start Script

echo "Starting PostgreSQL container..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Change to script directory
cd "$(dirname "$0")"

# Start container
docker-compose up -d

# Wait for container to start
echo "Waiting for PostgreSQL to start..."
sleep 5

# Check container status
if docker-compose ps | grep -q "Up"; then
    echo "PostgreSQL container started successfully!"
    echo ""
    echo "PostgreSQL Port: 5432"
    echo "Database: admin"
    echo "Username: admin"
    echo "Password: admin"
    echo ""
    echo "Connection string: postgresql://admin:admin@localhost:5432/admin"
    echo ""
    echo "Run 'docker-compose logs -f' to view logs"
else
    echo "ERROR: Failed to start PostgreSQL container"
    echo "Run 'docker-compose logs' to see error details"
    exit 1
fi

