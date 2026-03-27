:: Firefox ESR x64 UPDATER
:: by github.com/wincmd64

:: Look for application.ini in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "application.ini" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /i "Version= RemotingName=" "application.ini"') do (
        if /i "%%a"=="Version" set "current_version=v%%b"
        if /i "%%a"=="RemotingName" (
            echo %%b | findstr /i "esr" >nul && (set "ff_type=ESR") || (set "ff_type=Standard")
        )
    )
)

echo. & echo  Getting latest version...
set "url=https://download.mozilla.org/?product=firefox-esr-latest&os=win64&lang=en-US"
for /f "tokens=*" %%a in ('powershell -command "$req = [System.Net.WebRequest]::Create('%url%'); $res = $req.GetResponse(); $final = $res.ResponseUri.ToString(); $res.Close(); $final"') do set "final_url=%%a"
for /f "tokens=*" %%v in ('powershell -command "if ('%final_url%' -match 'releases/([^/]+)/') { $matches[1] }"') do set "latest_version=%%v"
cls

if not defined current_version (echo. & echo  Download Firefox v%latest_version% to "%dir%" ?
) else (
    echo. & echo  Current version: %current_version% %ff_type%
    echo   Latest version: v%latest_version%
    echo. & echo  Update?
)

set "lang=en-US"
echo.
echo   Default language: %lang%
set /p "lang=> Enter language code (e.g. uk, ru) or press ENTER for default: "
set "url=https://download.mozilla.org/?product=firefox-esr-latest&os=win64&lang=%lang%"

:check_task
tasklist /fi "imagename eq firefox.exe" | find /i "firefox.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Firefox is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe -RL# "%url%" -e"https://download.mozilla.org" -o "%temp%/ffwin.exe.7z"
curl.exe -RLO# "https://www.7-zip.org/a/7zr.exe" --output-dir "%temp%"
echo. & echo  Extracting ...
"%temp%\7zr.exe" x -t7z -bso0 "%temp%/ffwin.exe.7z" -o"%dir%" -xr!setup.exe
xcopy "%dir%core\*" "%dir%" /s /e /y /q
rd /s /q "core"
if not exist "distribution" md "distribution"
if not exist "distribution\policies.json" (
    echo. & echo  Creating policies.json ...
    (
        echo {
        echo   "policies": {
        echo     "NoDefaultBookmarks": true,
        echo     "Extensions": {
        echo       "Install": [
        echo         "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
        echo       ]
        echo     }
        echo   }
        echo }
    )>"distribution\policies.json"
)
:: use Profile Manager (-p) for fresh installs
if not defined current_version (start "" firefox.exe -p) else (start "" firefox.exe)
timeout 3 & exit
