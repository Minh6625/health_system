@echo off
echo ========================================
echo Health System - Database Setup Script
echo ========================================
echo.

REM Check if PostgreSQL is installed
where psql >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] PostgreSQL not found! Please install PostgreSQL first.
    echo Download: https://www.postgresql.org/download/
    pause
    exit /b 1
)

echo [1/3] Creating database 'hg_db'...
psql -U postgres -c "CREATE DATABASE hg_db;" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Database created successfully
) else (
    echo [INFO] Database may already exist, continuing...
)
echo.

echo [2/3] Running SQL scripts...
cd "..\SQL SCRIPTS"

for %%f in (*.sql) do (
    echo Running %%f...
    psql -U postgres -d hg_db -f "%%f"
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to run %%f
        pause
        exit /b 1
    )
)
echo.

echo [3/3] Verifying database setup...
psql -U postgres -d hg_db -c "\dt"
echo.

echo ========================================
echo Database setup completed successfully!
echo ========================================
echo.
echo Next steps:
echo 1. cd backend
echo 2. venv\Scripts\activate
echo 3. pip install -r requirements.txt
echo 4. uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
echo.
pause
