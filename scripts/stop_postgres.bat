@echo off
setlocal enabledelayedexpansion

REM ========================================
REM TraceLogKit - Stop Postgres (Windows)
REM ========================================

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"

set "COMPOSE_FILE=%PROJECT_ROOT%\docker\postgres\docker-compose.yml"

echo "========================================"
echo "  TraceLogKit - Stop Postgres"
echo "========================================"
echo "Project Root: %PROJECT_ROOT%"
echo "Compose File: %COMPOSE_FILE%"

where docker >nul 2>&1
if errorlevel 1 (
  echo "[ERROR] docker not found in PATH."
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo "[ERROR] Docker is not running. Nothing to stop."
  exit /b 1
)

if not exist "%COMPOSE_FILE%" (
  echo "[ERROR] docker compose file not found: %COMPOSE_FILE%"
  exit /b 1
)

set "USE_V2="
docker compose version >nul 2>&1 && set "USE_V2=1"

echo "Stopping PostgreSQL containers (docker compose down)..."
if defined USE_V2 (
  docker compose -f "%COMPOSE_FILE%" down
  if errorlevel 1 exit /b 1
) else (
  where docker-compose >nul 2>&1
  if errorlevel 1 (
    echo "[ERROR] Neither 'docker compose' nor 'docker-compose' is available."
    exit /b 1
  )
  docker-compose -f "%COMPOSE_FILE%" down
  if errorlevel 1 exit /b 1
)

echo "PostgreSQL containers stopped."
