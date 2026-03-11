@echo off
echo ========================================
echo Health System - Starting Backend
echo ========================================
echo.

cd ..\backend

REM Check if venv exists
if not exist "venv\" (
    echo [INFO] Virtual environment not found. Creating...
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create virtual environment
        pause
        exit /b 1
    )
)

echo [1/3] Activating virtual environment...
call venv\Scripts\activate
echo.

echo [2/3] Installing dependencies...
pip install -r requirements.txt
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo.

echo [3/3] Starting FastAPI server...
echo.
echo Backend will run at: http://localhost:8080
echo API Docs: http://localhost:8080/docs
echo.
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
