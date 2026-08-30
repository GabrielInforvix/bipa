@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

rem O endereco da API fica GRAVADO dentro do APK. Um celular nao enxerga o
rem "localhost" do PC, entao aqui vai o IP da maquina na rede Wi-Fi.
set API=%~1
if "%API%"=="" (
  for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /c:"IPv4" ^| findstr /v "127."') do (
    if not defined IP set IP=%%i
  )
  set IP=%IP: =%
  set API=http://%IP%:3010/api
  echo Nenhuma URL informada. Usando o IP desta maquina: %API%
  echo Para escolher outro: build-apk-mercado.bat http://SEU-IP:3010/api
  echo.
)

echo Compilando o APK apontando para %API% ...
cd web
call flutter build apk --release --split-per-abi --dart-define=API_BASE=%API% || goto :erro
cd ..

copy /y web\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk bipa-arm64.apk >nul

echo.
echo ============================================
echo   Pronto: bipa-arm64.apk
echo.
echo   Antes de instalar, confira:
echo    1. a API precisa estar rodando (start-mercado.bat)
echo    2. celular e PC na MESMA rede Wi-Fi
echo    3. o IP %API% precisa estar liberado no
echo       arquivo web\android\app\src\main\res\xml\
echo       network_security_config.xml
echo ============================================
pause
exit /b 0

:erro
echo.
echo [X] Falhou. Veja a mensagem acima.
pause
exit /b 1
