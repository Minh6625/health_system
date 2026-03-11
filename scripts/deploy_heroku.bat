@echo off
echo ========================================
echo Health System - Deploy to Heroku
echo ========================================
echo.

REM Check if Heroku CLI is installed
where heroku >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Heroku CLI not found!
    echo Please install from: https://devcenter.heroku.com/articles/heroku-cli
    pause
    exit /b 1
)

echo [1/6] Checking Heroku login...
heroku auth:whoami
if %ERRORLEVEL% NEQ 0 (
    echo Please login to Heroku:
    heroku login
)
echo.

echo [2/6] Moving to backend directory...
cd ..\backend
echo.

echo [3/6] Creating Heroku app (if not exists)...
set /p APP_NAME="Enter your Heroku app name (e.g., healthguard-api): "
heroku create %APP_NAME% 2>nul
echo.

echo [4/6] Adding PostgreSQL addon...
heroku addons:create heroku-postgresql:mini -a %APP_NAME% 2>nul
echo.

echo [5/6] Setting environment variables...
echo Generating SECRET_KEY...
for /f "delims=" %%i in ('python -c "import secrets; print(secrets.token_hex(32))"') do set SECRET_KEY=%%i
heroku config:set SECRET_KEY=%SECRET_KEY% -a %APP_NAME%
heroku config:set ALGORITHM=HS256 -a %APP_NAME%
heroku config:set ACCESS_TOKEN_EXPIRE_MINUTES=30 -a %APP_NAME%
echo.

echo [6/6] Deploying to Heroku...
git init 2>nul
git add .
git commit -m "Deploy to Heroku" 2>nul
heroku git:remote -a %APP_NAME%
git push heroku main
echo.

echo ========================================
echo Deployment completed!
echo ========================================
echo.
echo Your API is available at:
echo https://%APP_NAME%.herokuapp.com
echo.
echo API Docs:
echo https://%APP_NAME%.herokuapp.com/docs
echo.
echo Next steps:
echo 1. Run SQL scripts: heroku pg:psql -a %APP_NAME%
echo 2. Update Flutter app API endpoint to: https://%APP_NAME%.herokuapp.com/api/v1
echo 3. Build new APK: flutter build apk --release
echo.
pause
