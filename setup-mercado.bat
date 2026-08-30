@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ============================================
echo   Bipa - instalacao (rodar uma vez so)
echo ============================================
echo.

if not exist "api\.env" (
  echo [!] Falta o arquivo api\.env
  echo     Copie api\.env.example para api\.env e ajuste a senha do Postgres.
  echo.
  pause
  exit /b 1
)

echo [1/5] Criando o banco "mercado" (ignore o erro se ja existir)...
set PSQL="C:\Program Files\PostgreSQL\16\bin\psql.exe"
if exist %PSQL% (
  %PSQL% -U postgres -c "CREATE DATABASE mercado" 2>nul
  rem Banco separado para os testes de integracao. Eles APAGAM dados.
  %PSQL% -U postgres -c "CREATE DATABASE mercado_test" 2>nul
) else (
  echo     psql nao encontrado - crie o banco na mao:
  echo     CREATE DATABASE mercado;
)

echo [2/5] Instalando dependencias da API...
cd api
call npm install || goto :erro

echo [3/5] Aplicando as migracoes...
call npx prisma migrate deploy || goto :erro
call npx prisma generate || goto :erro

echo [4/5] Populando com dados de exemplo...
call npx prisma db seed || goto :erro
cd ..

echo [5/5] Instalando dependencias do front...
cd web
call flutter pub get || goto :erro
cd ..

echo.
echo ============================================
echo   Pronto.
echo   Login: gabriel@bipa.local / bipa123
echo   Agora rode: start-mercado.bat
echo ============================================
pause
exit /b 0

:erro
echo.
echo [X] A instalacao falhou no passo acima. Veja a mensagem de erro.
pause
exit /b 1
