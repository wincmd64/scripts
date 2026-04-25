:: opera-proxy (x64) UPDATER
:: by github.com/wincmd64

:: Look for opera-proxy.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=opera-proxy"
set "app=opera-proxy.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f %%a in ('%app% -version') do set "current_version=%%a"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github latest ver
call :github "Alexey71/opera-proxy" "*windows-amd64.exe" "https://github.com/Alexey71/opera-proxy/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
curl.exe -fRL# "https://github.com/Alexey71/opera-proxy/releases/latest/download/opera-proxy.windows-amd64.exe" -o "opera-proxy.exe"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
if defined current_version (start "" "%app%" & exit /b)

echo.
choice /c YN /m "Add to Startup"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup') + '\opera-proxy.lnk'); ^
$s.TargetPath = '%dir%%app%'; ^
$s.WorkingDirectory = '%dir%'; ^
$s.IconLocation = '%dir%%app%'; ^
$s.WindowStyle = 7; ^
$s.Save()"
echo. & echo Shortcut 'opera-proxy.lnk' created. & echo. & timeout 2 & exit

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference='SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; $rel = $r | Where-Object { !$_.prerelease -and ($_.assets.name -like '%filter%') } | Select-Object -First 1; if(!$rel){exit}; $a=$rel.assets | Where-Object { $_.name -like '%filter%' } | Select-Object -First 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
for /f "usebackq tokens=*" %%a in (`powershell -command "%ps_cmd%" 2^>nul`) do (
    if not defined latest_version (
        set "latest_version=%%a"
    ) else if not defined url (
        set "url=%%a"
    ) else if not defined filename (
        set "filename=%%a"
    ) else (
        set "server_date=%%a"
    )
)

:: if PS failed, latest_version will contain error text or be empty
if "%url:~0,4%" NEQ "http" (
    set "url="
    set "latest_version="
    echo.
    echo  Error: Repository "%repo%" not found or API limit reached.
    echo  Try manual: %manual_url%  & echo. & pause
    exit /b
)

echo. & echo  Repo: %repo%
echo   Ver: %latest_version% (%server_date%)
echo  File: %filename%
echo  Link: %url%
echo.
goto :eof