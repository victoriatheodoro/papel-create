@echo off
echo ================================================
echo   Analog Sync - Versao Web
echo ================================================
echo.

cd /d "H:\Claude\Papelaria\analog_sync_project"

echo [1/2] Compilando app...
"C:\Users\jhona\.puro\envs\stable\flutter\bin\flutter.bat" build web --no-tree-shake-icons

echo.
echo [2/2] Abrindo no navegador em http://localhost:8080
start http://localhost:8080
python -m http.server 8080 --directory build\web

pause
