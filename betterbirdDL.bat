:: Betterbird (portable) downloader and updater
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

echo. & echo  Loading ...
:: get link
for /f "usebackq tokens=*" %%a in (`powershell -NoP -C "(Invoke-WebRequest 'https://www.betterbird.eu/downloads/getloc.php?os=win&lang=en-US&version=release&portable=true' -UseBasicParsing).Content.Trim()"`) do set "URL=%%a"
:: get server filename
for %%i in ("%URL%") do set "filename=%%~nxi"
:: get server ver
for /f "usebackq tokens=*" %%v in (`powershell -NoP -C "if ('%URL%' -match '(\d+\.\d+\.\d+[-a-z0-9]*)') { $Matches[1] }"`) do set "VERSION=%%v"
:: get local ver
if exist "core\betterbird.exe" (
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'core\betterbird.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
) else (
    set "current_version=Not installed"
)
cls
echo. & echo  Latest version found: %version%
echo  Current version: %current_version%
if "%current_version%"=="Not installed" (echo. & echo   Download to "%~dp0" ? & echo. & pause) else (echo. & echo   Update ? & echo. & pause) 
:: is running?
:check_task
tasklist /fi "imagename eq betterbird.exe" | find /i "betterbird.exe" >nul
if not errorlevel 1 (echo. & echo  Betterbird is currently running. & echo  Please close Betterbird before updating. & echo. & pause & goto check_task)
if not exist "%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -C "Invoke-WebRequest -Uri '%URL%' -OutFile '%filename%'"
) else (echo. & echo  %filename% already exist.)
echo. & echo  Extracting ...
if exist "%filename%" (tar -xf "%filename%") else (echo. & echo  %filename% not found. & echo. & pause)

color A & echo. & echo. & echo  DONE. & timeout 5