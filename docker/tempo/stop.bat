@echo off
setlocal
REM Stop Tempo (Tracing backend)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose down
if errorlevel 1 (
  echo [ERROR] Failed to stop Tempo
  exit /b 1
)

echo [OK] Tempo stopped

