@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  echo Uso: build-prod-mercado.bat https://seu-dominio.com.br/api
  echo.
  echo A URL da API precisa ser passada porque ela e gravada no build do
  echo Flutter. Sem isso o app publicado tentaria falar com localhost.
  pause
  exit /b 1
)

echo [1/3] Compilando o front (API_BASE=%~1)...
cd web
call flutter build web --release --dart-define=API_BASE=%~1 || goto :erro
cd ..

echo [2/3] Compilando a API...
cd api
call npm ci --omit=dev || goto :erro
call npx prisma generate || goto :erro
call npm run build || goto :erro
cd ..

echo [3/3] Montando a pasta deploy\...
if exist deploy rmdir /s /q deploy
mkdir deploy\api
mkdir deploy\web
xcopy /e /i /q api\dist deploy\api\dist >nul
xcopy /e /i /q api\node_modules deploy\api\node_modules >nul
xcopy /e /i /q api\prisma deploy\api\prisma >nul
copy api\package.json deploy\api\ >nul
copy api\.env.example deploy\api\.env.example >nul
xcopy /e /i /q web\build\web deploy\web >nul

echo.
echo ============================================
echo   Pronto: pasta deploy\
echo.
echo   No servidor:
echo    1. copie deploy\ para a maquina
echo    2. crie deploy\api\.env a partir do .env.example
echo       (troque os segredos JWT e aponte o DATABASE_URL)
echo    3. npx prisma migrate deploy
echo    4. SERVE_WEB=true para a API servir o front junto
echo    5. node dist/main
echo ============================================
pause
exit /b 0

:erro
echo.
echo [X] Falhou. Veja a mensagem acima.
pause
exit /b 1
