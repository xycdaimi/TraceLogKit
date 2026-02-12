@echo off
setlocal
REM Stop Promtail (Log shipping agent)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose down
if errorlevel 1 (
  echo [ERROR] Failed to stop Promtail
  exit /b 1
)

echo [OK] Promtail stopped

