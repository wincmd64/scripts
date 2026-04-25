:: Victoria UPDATER
:: by github.com/wincmd64

:: Look for Victoria.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=Victoria"
set "app=Victoria.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item '%app%').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    echo  Getting latest version...
    for /f "delims=" %%a in ('powershell -command "$req = [System.Net.HttpWebRequest]::Create('https://sourceforge.net/projects/victoria-ssd-hdd/files/latest/download'); $req.AllowAutoRedirect = $true; $req.Method = 'HEAD'; $res = $req.GetResponse(); $res.ResponseUri.Segments[-1]; $res.Close()"') do set "latest_version=%%a"
    cls
)

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version%
    echo   Latest version: %latest_version%
    echo. & echo  Update? & echo. & pause
)
:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
echo. & echo  Downloading: %N%
curl -fL# "https://sourceforge.net/projects/victoria-ssd-hdd/files/latest/download" -o "%temp%\victoria.zip"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\victoria.zip" --strip-components=1 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DOWNLOADED. Now launching... & echo.)
start "" %app%
timeout 3 & exit