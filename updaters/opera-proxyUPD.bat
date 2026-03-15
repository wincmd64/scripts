:: opera-proxy (x64) UPDATER
:: by github.com/wincmd64

:: Look for opera-proxy.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "opera-proxy.exe" (
    echo. & echo  Getting current version...
    for /f %%a in ('opera-proxy.exe -version') do set "current_version=%%a"
    cls
)

if not defined current_version (echo. & echo  Download opera-proxy to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=(Invoke-RestMethod 'https://api.github.com/repos/Snawoot/opera-proxy/releases/latest').tag_name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do set "latest_version=%%a"
if "%latest_version%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/Snawoot/opera-proxy/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
)

:check_task
tasklist /fi "imagename eq opera-proxy.exe" | find /i "opera-proxy.exe" >nul
if not errorlevel 1 (echo. & echo  [!] opera-proxy is running. Please close it to continue. & echo. & pause & goto check_task)

:: download
curl.exe -RL# "https://github.com/Snawoot/opera-proxy/releases/latest/download/opera-proxy.windows-amd64.exe" -o "opera-proxy.exe"
echo. & echo. & echo  DONE. & echo.

choice /c YN /m "Add to Startup"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup') + '\opera-proxy.lnk'); ^
$s.TargetPath = '%~dp0opera-proxy.exe'; ^
$s.WorkingDirectory = '%~dp0'; ^
$s.IconLocation = '%~dp0opera-proxy.exe'; ^
$s.WindowStyle = 7; ^
$s.Save()"
echo. & echo Shortcut 'opera-proxy.lnk' created. & echo. & timeout 3
