@echo off
setlocal
REM Start Tempo (Tracing backend)

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

docker compose --env-file ..\\..\\.env up -d
if errorlevel 1 (
  echo [ERROR] Failed to start Tempo
  exit /b 1
)

echo [OK] Tempo started: http://localhost:3200/ready
