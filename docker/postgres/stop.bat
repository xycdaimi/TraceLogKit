@echo off
REM PostgreSQL Container Stop Script (Windows)

echo "Stopping PostgreSQL container..."

REM Change to script directory
cd /d "%~dp0"

REM Stop container
docker-compose down

echo "PostgreSQL container stopped successfully!"



