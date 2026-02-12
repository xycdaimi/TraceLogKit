@echo off
REM PostgreSQL Container Start Script (Windows)

echo "Starting PostgreSQL container..."

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo "ERROR: Docker is not running. Please start Docker first."
    exit /b 1
)

REM Change to script directory
cd /d "%~dp0"

REM Start container
docker-compose up -d

REM Wait for container to start
echo "Waiting for PostgreSQL to start..."
timeout /t 5 /nobreak >nul

REM Check container status
docker-compose ps | findstr "Up" >nul
if errorlevel 1 (
    echo "ERROR: Failed to start PostgreSQL container"
    echo "Run 'docker-compose logs' to see error details"
    exit /b 1
)

echo "PostgreSQL container started successfully!"
echo.
echo "PostgreSQL Port: 5432"
echo "Database: admin"
echo "Username: admin"
echo "Password: admin"
echo.
echo "Connection string: postgresql://admin:admin@localhost:5432/admin"
echo.
echo "Run 'docker-compose logs -f' to view logs"



