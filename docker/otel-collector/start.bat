@echo off
setlocal
REM Start OpenTelemetry Collector

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose --env-file ..\\..\\.env up -d
if errorlevel 1 (
  echo [ERROR] Failed to start OTel Collector
  exit /b 1
)

echo [OK] OTel Collector started: OTLP gRPC localhost:4317

