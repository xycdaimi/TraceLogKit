@echo off
REM ========================================
REM TraceLogKit - Stop infrastructure containers
REM ========================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."

echo ========================================
echo    TraceLogKit - Stop Infrastructure
echo ========================================
echo.

REM Check Docker
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running.
    pause
    popd
    exit /b 1
)

REM Stop Grafana
echo [1/6] Stopping Grafana...
cd /d "%SCRIPT_DIR%..\docker\grafana"
docker compose down -v 2>nul
echo [OK] Grafana stopped

REM Stop Promtail
echo [2/6] Stopping Promtail...
cd /d "%SCRIPT_DIR%..\docker\promtail"
docker compose down 2>nul
echo [OK] Promtail stopped

REM Stop Loki
echo [3/6] Stopping Loki...
cd /d "%SCRIPT_DIR%..\docker\loki"
docker compose down 2>nul
echo [OK] Loki stopped

REM Stop Prometheus
echo [4/6] Stopping Prometheus...
cd /d "%SCRIPT_DIR%..\docker\prometheus"
docker compose down 2>nul
echo [OK] Prometheus stopped

REM Stop OTel Collector
echo [5/6] Stopping OTel Collector...
cd /d "%SCRIPT_DIR%..\docker\otel-collector"
docker compose down 2>nul
echo [OK] OTel Collector stopped

REM Stop Tempo
echo [6/6] Stopping Tempo...
cd /d "%SCRIPT_DIR%..\docker\tempo"
docker compose down 2>nul
echo [OK] Tempo stopped

cd /d "%SCRIPT_DIR%.."

echo.
echo ========================================
echo    TraceLogKit Stopped!
echo ========================================
echo.
echo Note: Data volumes are preserved.
echo To remove volumes, run "docker compose down -v" in each directory.
popd
pause

