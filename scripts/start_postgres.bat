@echo off
setlocal enabledelayedexpansion

REM ========================================
REM TraceLogKit - Start Postgres (Windows)
REM ========================================

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"

set "COMPOSE_FILE=%PROJECT_ROOT%\docker\postgres\docker-compose.yml"
set "ENV_FILE=%PROJECT_ROOT%\.env"
set "ENV_EXAMPLE_FILE=%PROJECT_ROOT%\.env.example"

echo "========================================"
echo "  TraceLogKit - Start Postgres"
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
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit /b 1
)

if not exist "%COMPOSE_FILE%" (
  echo "[ERROR] docker compose file not found: %COMPOSE_FILE%"
  exit /b 1
)

if not exist "%ENV_FILE%" (
  if exist "%ENV_EXAMPLE_FILE%" (
    copy /Y "%ENV_EXAMPLE_FILE%" "%ENV_FILE%" >nul
    echo "[WARN] .env not found. Created from .env.example: %ENV_FILE%"
  ) else (
    echo "[ERROR] .env not found and .env.example is missing. Please create %ENV_FILE%."
    exit /b 1
  )
)

set "USE_V2="
docker compose version >nul 2>&1 && set "USE_V2=1"

echo "Starting PostgreSQL containers..."
if defined USE_V2 (
  docker compose -f "%COMPOSE_FILE%" up -d
  if errorlevel 1 exit /b 1
) else (
  where docker-compose >nul 2>&1
  if errorlevel 1 (
    echo "[ERROR] Neither 'docker compose' nor 'docker-compose' is available."
    exit /b 1
  )
  docker-compose -f "%COMPOSE_FILE%" up -d
  if errorlevel 1 exit /b 1
)

echo "PostgreSQL containers started."
echo "Checking status..."
if defined USE_V2 (
  docker compose -f "%COMPOSE_FILE%" ps
) else (
  docker-compose -f "%COMPOSE_FILE%" ps
)

echo "----------------------------------------"
echo "Primary:  localhost:5432"
echo "Replica:  localhost:5433"
echo "Note: credentials come from .env"
echo "----------------------------------------"
echo "View logs:"
if defined USE_V2 (
  echo "  docker compose -f ""%COMPOSE_FILE%"" logs -f"
) else (
  echo "  docker-compose -f ""%COMPOSE_FILE%"" logs -f"
)
