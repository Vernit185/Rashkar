@echo off
echo ============================================================
echo Starting CropNet AI Platform (Backend & Frontend)
echo ============================================================
echo.

cd /d "%~dp0"

echo [1/2] Starting FastAPI Backend on http://localhost:8000...
start "CropNet AI Backend" cmd /k "python -m uvicorn cropnet.services.api.app.main:app --host 127.0.0.1 --port 8000"

timeout /t 3 /nobreak >nul

echo [2/2] Starting Flutter Web Server on http://localhost:8080...
start "CropNet AI Web Client" cmd /k "python scripts\serve_web.py"

echo.
echo ============================================================
echo All services running!
echo - Web Dashboard:  http://localhost:8080
echo - Backend API:    http://localhost:8000
echo - Swagger Docs:   http://localhost:8000/api/v1/docs
echo ============================================================
pause
