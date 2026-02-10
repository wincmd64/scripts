:: BETTERBIRD (PORTABLE) UPDATER
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

if exist "core\betterbird.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'core\betterbird.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    cls
)

if not defined current_version (echo. & echo  Download Betterbird to "%~dp0" ? & echo. & pause
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
    tasklist /fi "imagename eq betterbird.exe" | find /i "betterbird.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] Betterbird is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -command "Invoke-WebRequest -Uri '%url%' -OutFile '%temp%\%filename%'"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%") else (echo. & echo  %filename% not found. & echo. & pause)

color A & echo. & echo. & echo  DONE. & timeout 5
