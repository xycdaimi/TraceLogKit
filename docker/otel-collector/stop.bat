@echo off
setlocal
REM Stop OpenTelemetry Collector

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose down
if errorlevel 1 (
  echo [ERROR] Failed to stop OTel Collector
  exit /b 1
)

echo [OK] OTel Collector stopped

