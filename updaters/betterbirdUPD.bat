:: Betterbird (portable) UPDATER
:: by github.com/wincmd64

:: Look for core\application.ini in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "core\application.ini" (for /f "tokens=2 delims==" %%v in ('findstr /i "^Version=" "core\application.ini"') do (set "current_version=%%v"))

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
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%" 2>nul
if errorlevel 1 (color C & echo. & echo  Error: extraction failed. & echo. & pause & exit /b) else (color A & echo. & echo. & echo  DONE. & echo.)

choice /c YN /m "Create desktop shortcut"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Betterbird.lnk'); ^
$s.TargetPath = '%~dp0betterbird.exe'; ^
$s.WorkingDirectory = '%~dp0'; ^
$s.IconLocation = '%~dp0betterbird.exe'; ^
$s.Save()"
echo. & echo Shortcut 'Betterbird.lnk' created. & echo. & timeout 3
