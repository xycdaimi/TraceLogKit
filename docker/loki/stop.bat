@echo off
setlocal
REM Stop Loki (Logs backend)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose down
if errorlevel 1 (
  echo [ERROR] Failed to stop Loki
  exit /b 1
)

echo [OK] Loki stopped

