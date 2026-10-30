@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title SmartDental - Inicializador
color 0B

rem ===== CONFIGURACAO =====
set "PROJETO=C:\Users\Suporte\Downloads\smartdental-app\smartdental-app"
set "MVN=C:\Ferramentas\apache-maven-3.10.0\bin\mvn.cmd"
set "PORTA=8081"
set "URL=http://localhost:%PORTA%"
set "PS1=%~dp0smartdental.ps1"
set "MAX_TENTATIVAS=90"
set "INICIOU_BACKEND=0"

echo.
echo  ==============================================
echo    SMARTDENTAL - Inicializador
echo  ==============================================
echo.

rem ===== VERIFICACOES =====
if not exist "%PS1%" (
    echo  [ERRO] Arquivo smartdental.ps1 nao encontrado em: %~dp0
    echo         Salve o smartdental.ps1 na mesma pasta deste .bat.
    pause
    exit /b 1
)
if not exist "%MVN%" (
    echo  [ERRO] Maven nao encontrado em: %MVN%
    pause
    exit /b 1
)
if not exist "%PROJETO%\pom.xml" (
    echo  [ERRO] pom.xml nao encontrado em: %PROJETO%
    pause
    exit /b 1
)
where java >nul 2>&1
if errorlevel 1 (
    if not defined JAVA_HOME (
        echo  [ERRO] Java nao encontrado. Instale o JDK 17 ou configure o JAVA_HOME.
        pause
        exit /b 1
    )
)

rem ===== BACKEND =====
echo  [1/3] Verificando se a API ja esta no ar...
call :testar_api
if not errorlevel 1 (
    echo        A API ja esta em execucao na porta %PORTA%. Nada a iniciar.
    goto api_pronta
)

echo  [2/3] Iniciando o backend Java Spring Boot...
echo        Uma janela minimizada chamada "SmartDental API" sera aberta.
echo        Nao feche essa janela enquanto estiver usando o sistema.
set "INICIOU_BACKEND=1"
start "SmartDental API" /D "%PROJETO%" /MIN cmd /k ""%MVN%" spring-boot:run"

echo.
echo        Aguardando a API ficar pronta. A primeira vez pode demorar.
set /a TENTATIVA=0
:aguardar
call :testar_api
if not errorlevel 1 goto api_pronta
set /a TENTATIVA+=1
if !TENTATIVA! geq %MAX_TENTATIVAS% goto api_timeout
<nul set /p "=."
timeout /t 2 /nobreak >nul
goto aguardar

:api_timeout
echo.
echo.
echo  [ERRO] A API nao respondeu a tempo em %URL%/pacientes
echo         Veja a janela "SmartDental API" na barra de tarefas para ler o erro.
echo         Confira tambem se server.port=%PORTA% em application.properties
echo         e se o PostgreSQL esta em execucao.
pause
exit /b 1

:api_pronta
echo.
echo  [3/3] API pronta. Abrindo a interface PowerShell...
timeout /t 1 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -BaseUrl "%URL%"

rem ===== ENCERRAMENTO =====
if "%INICIOU_BACKEND%"=="1" (
    echo.
    choice /c SN /n /m "  Encerrar o backend Java agora? [S/N] "
    if not errorlevel 2 (
        echo  Encerrando o backend...
        for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORTA% .*LISTENING"') do taskkill /PID %%P /T /F >nul 2>&1
        taskkill /FI "WINDOWTITLE eq SmartDental API*" /T /F >nul 2>&1
        echo  Backend encerrado.
    ) else (
        echo  Backend mantido em execucao. Feche a janela "SmartDental API" para encerrar.
    )
)
echo.
pause
endlocal
exit /b 0

:testar_api
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%URL%/pacientes' -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %errorlevel%
