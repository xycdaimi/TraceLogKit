@echo off
REM Prometheus Stack Stop Script (Windows)

echo Stopping Prometheus stack...

REM Change to script directory
cd /d "%~dp0"

REM Stop stack
docker compose down

echo Prometheus stack stopped successfully!
