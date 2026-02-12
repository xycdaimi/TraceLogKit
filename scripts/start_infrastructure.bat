@echo off
setlocal enabledelayedexpansion

REM ========================================
REM TraceLogKit - Start infrastructure stack
REM Minimal, ASCII-only script to avoid encoding issues
REM ========================================

REM Resolve project root from script location
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"

echo ========================================
echo   TraceLogKit - Start Infrastructure
echo ========================================
echo Project Root: %PROJECT_ROOT%
echo.

REM Check Docker
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running. Please start Docker first.
    pause
    exit /b 1
)

REM Check .env at project root (do NOT stop if missing, services have defaults)
if not exist "%PROJECT_ROOT%\.env" (
    echo [WARN] .env not found at %PROJECT_ROOT%\.env
    echo        Services will use default values or OS environment variables.
    echo.
)

echo ========================================
echo   Services to Start:
echo   1. Tempo
echo   2. OTel Collector
echo   3. Prometheus
echo   4. Loki
echo   5. Promtail
echo   6. Grafana
echo ========================================
echo.

REM 1. Tempo
echo [1/6] Starting Tempo...
cd /d "%PROJECT_ROOT%\docker\tempo"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start Tempo
) else (
    echo [OK] Tempo started (http://localhost:3200/ready)
)
echo.

REM 2. OTel Collector
echo [2/6] Starting OTel Collector...
cd /d "%PROJECT_ROOT%\docker\otel-collector"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start OTel Collector
) else (
    echo [OK] OTel Collector started (OTLP gRPC: 4317, HTTP: 4318)
)
echo.

REM 3. Prometheus
echo [3/6] Starting Prometheus...
cd /d "%PROJECT_ROOT%\docker\prometheus"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start Prometheus
) else (
    echo [OK] Prometheus started (http://localhost:9090)
)
echo.

REM 4. Loki
echo [4/6] Starting Loki...
cd /d "%PROJECT_ROOT%\docker\loki"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start Loki
) else (
    echo [OK] Loki started (http://localhost:3100/ready)
)
echo.

REM 5. Promtail
echo [5/6] Starting Promtail...
cd /d "%PROJECT_ROOT%\docker\promtail"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start Promtail
) else (
    echo [OK] Promtail started (http://localhost:9080/metrics)
)
echo.

REM 6. Grafana
echo [6/6] Starting Grafana...
cd /d "%PROJECT_ROOT%\docker\grafana"
docker compose --env-file "%PROJECT_ROOT%\.env" up -d --build
if errorlevel 1 (
    echo [ERROR] Failed to start Grafana
) else (
    echo [OK] Grafana started (http://localhost:3000)
)
echo.

cd /d "%PROJECT_ROOT%"

echo ========================================
echo   TraceLogKit Started
echo ========================================
echo Service URLs:
echo   - Grafana:     http://localhost:3000
echo   - Tempo:       http://localhost:3200/ready
echo   - Loki:        http://localhost:3100/ready
echo   - Prometheus:  http://localhost:9090
echo   - OTLP gRPC:   localhost:4317
echo   - OTLP HTTP:   http://localhost:4318
echo.
echo Run "docker ps" to check container status.
echo Run "scripts\\stop_infrastructure.bat" to stop all.

pause

