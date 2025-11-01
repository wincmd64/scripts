:: Office Deployment Tool
::   You need to specify YOUR configuration .xml for XML_SOURCE
::   Both local files and web links are supported.
::   You can use https://config.office.com/deploymentsettings to configure .xml 
:: by github.com/wincmd64

@echo off
chcp 1251 >nul
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs & Exit /B)
for /F "tokens=3 delims=." %%O in ('reg query "HKCR\Word.Application\CurVer" 2^>nul') do set officeVer=%%O
if defined officeVer (TITLE Office v%officeVer% detected) else (TITLE Office not found)

:: ===== USER XML =====
:: This example for Office 2021 x64 ru
set "XML_SOURCE=https://raw.githubusercontent.com/wincmd64/blog/refs/heads/main/office2021std.xml"
:: ====================

:: get downloads folder path
for /f "delims=" %%a in ('powershell -NoP -C "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"

pushd "%DOWNLOADS%"
if not exist "setup.exe" (
    echo. & echo  download "setup.exe" to "%DOWNLOADS%" ? & echo. & pause
    curl.exe --ssl-no-revoke https://officecdn.microsoft.com/pr/wsus/setup.exe -OR#
    if errorlevel 1 (color C & echo. & echo  ERROR: setup.exe download failed. & echo. & pause & exit)
)

:: web
if "%XML_SOURCE:~0,7%"=="http://" goto DOWNLOAD_CONFIG
if "%XML_SOURCE:~0,8%"=="https://" goto DOWNLOAD_CONFIG

:: local
if not exist "%XML_SOURCE%" (color C & echo. & echo  ERROR: "%XML_SOURCE%" not found. & echo. & pause & exit)
set "CONFIG_FILE=%XML_SOURCE%"
goto :run

:DOWNLOAD_CONFIG
for %%a in ("%XML_SOURCE%") do set "CONFIG_FILE=%%~nxa"
if not exist "%CONFIG_FILE%" (
    echo. & echo  download "%CONFIG_FILE%" ? & echo. & pause
    curl.exe --ssl-no-revoke "%XML_SOURCE%" -#O
    if errorlevel 1 (color C & echo. & echo  ERROR: xml config download failed. & echo. & pause & exit)
)

:RUN
echo. & echo  run: setup.exe /configure "%CONFIG_FILE%" ? & echo. & pause
start "" "%DOWNLOADS%\setup.exe" /configure "%CONFIG_FILE%"
echo. & echo  Installation started...
timeout 3
