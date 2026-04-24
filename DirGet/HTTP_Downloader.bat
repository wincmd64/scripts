:: HTTP Downloader x64 UPDATER
:: by github.com/wincmd64

:: Look for HTTP_Downloader.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=HTTP Downloader"
set "app=HTTP_Downloader.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item '%app%').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=v%%v"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github latest ver
call :github "erickutcher/httpdownloader" "*64.zip" "https://github.com/erickutcher/httpdownloader/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DOWNLOADED. Now launching... & echo.)
type nul > "portable"

start "" %app% --clipboard
timeout 3 & exit

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference = 'SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; if($r -is [array]){$rel=$r[0]}else{$rel=$r}; $a=$rel.assets|?{$_.name -like '%filter%'}|select -f 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
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