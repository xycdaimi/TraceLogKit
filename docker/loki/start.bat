@echo off
setlocal
REM Start Loki (Logs backend)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose --env-file ..\\..\\.env up -d
if errorlevel 1 (
  echo [ERROR] Failed to start Loki
  exit /b 1
)

echo [OK] Loki started: http://localhost:3100/ready

