@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo Subindo a API (porta 3010) e o front (porta 4310)...
echo Cada um abre em uma janela separada. Feche as janelas para parar.
echo.

start "Bipa - API" cmd /k "cd /d %~dp0api && npm run start:dev"

rem Espera a API subir antes de abrir o navegador no front.
timeout /t 6 /nobreak >nul

start "Bipa - Web" cmd /k "cd /d %~dp0web && flutter run -d chrome --web-port=4310 --dart-define=API_BASE=http://localhost:3010/api"

echo.
echo   API : http://localhost:3010/api
echo   App : http://localhost:4310
echo   Login: gabriel@bipa.local / bipa123
echo.
