:: Betterbird (portable) UPDATER
:: by github.com/wincmd64

:: Look for core\application.ini in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=Betterbird"
set "app=betterbird.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "core\application.ini" (for /f "tokens=2 delims==" %%v in ('findstr /i "^Version=" "core\application.ini"') do (set "current_version=%%v"))

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
for /f "usebackq tokens=*" %%a in (`powershell -NoP -C "(Invoke-WebRequest 'https://www.betterbird.eu/downloads/getloc.php?os=win&lang=en-US&version=release&portable=true' -UseBasicParsing).Content.Trim()"`) do set "URL=%%a"
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://www.betterbird.eu & pause & exit /b)
for %%i in ("%URL%") do set "filename=%%~nxi"
for /f "usebackq tokens=*" %%v in (`powershell -NoP -C "if ('%URL%' -match '(\d+\.\d+\.\d+[-a-z0-9]*)') { $Matches[1] }"`) do set "latest_version=%%v"

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
    if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%" 2>nul
if errorlevel 1 (color C & echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo  DOWNLOADED. Now launching... & echo.)
start "" BetterbirdLauncher.exe
timeout 3
