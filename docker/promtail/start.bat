@echo off
setlocal
REM Start Promtail (Log shipping agent)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose --env-file ..\\..\\.env up -d
if errorlevel 1 (
  echo [ERROR] Failed to start Promtail
  exit /b 1
)

echo [OK] Promtail started (metrics: http://localhost:9080/metrics)

