@echo off
echo ========================================
echo Health System - Starting Frontend
echo ========================================
echo.

cd ..

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter not found! Please install Flutter first.
    echo Download: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo [1/2] Getting Flutter dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo [2/2] Starting Flutter app...
echo.
echo Note: Make sure backend is running at http://localhost:8080
echo.
flutter run
