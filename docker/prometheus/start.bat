@echo off
REM Prometheus Stack Start Script (Windows)
REM Includes: Prometheus, Redis Exporter, Postgres Exporter, Kafka Exporter

echo Starting Prometheus stack...

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker first.
    exit /b 1
)

REM Change to script directory
cd /d "%~dp0"

REM Start stack
docker compose --env-file ../../.env up -d --build

REM Wait for containers to start
echo Waiting for Prometheus stack to start...
timeout /t 5 /nobreak >nul

REM Check container status
docker compose ps | findstr "Up" >nul
if errorlevel 1 (
    echo ERROR: Failed to start Prometheus stack
    echo Run 'docker compose logs' to see error details
    exit /b 1
)

echo Prometheus stack started successfully!
echo.
echo Prometheus UI:        http://localhost:9090
echo Redis Exporter:       http://localhost:9121/metrics
echo Postgres Exporter:    http://localhost:9187/metrics
echo Kafka Exporter:       http://localhost:9308/metrics
echo.
echo Run 'docker compose logs -f' to view logs
