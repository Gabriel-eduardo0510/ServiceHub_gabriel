@echo off
setlocal
cd /d "%~dp0"
set "SERVICEHUB_JAVA="
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "SERVICEHUB_JAVA=%JAVA_HOME%\bin\java.exe"
if not defined SERVICEHUB_JAVA if exist "C:\Program Files\JetBrains\IntelliJ IDEA 2025.2.3\jbr\bin\java.exe" set "SERVICEHUB_JAVA=C:\Program Files\JetBrains\IntelliJ IDEA 2025.2.3\jbr\bin\java.exe"
if not defined SERVICEHUB_JAVA set "SERVICEHUB_JAVA=java"
echo ServiceHub API - requer Java 21 ou superior.
echo Apos iniciar, abra http://localhost:8080/swagger-ui.html
echo Mantenha esta janela aberta. Para encerrar, pressione Ctrl+C.
"%SERVICEHUB_JAVA%" -jar "dist\servicehub-api-1.0.0.jar"
if errorlevel 1 (
 echo Falha ao iniciar. Verifique o Java 21 e se a porta 8080 ja esta em uso.
 pause
)
