:: FIREFOX ESR x64 UPDATER
::   Alternative to winget
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: get local ver
if exist "firefox.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'firefox.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
)

echo. & echo  Getting latest version...
set "url=https://download.mozilla.org/?product=firefox-esr-latest&os=win64&lang=en-US"
for /f "tokens=*" %%a in ('powershell -command "$req = [System.Net.WebRequest]::Create('%url%'); $res = $req.GetResponse(); $final = $res.ResponseUri.ToString(); $res.Close(); $final"') do set "final_url=%%a"
for /f "tokens=*" %%v in ('powershell -command "if ('%final_url%' -match 'releases/([^/]+)/') { $matches[1] }"') do set "latest_version=%%v"
cls

if not defined current_version (echo. & echo  Download Firefox ESR to "%~dp0" ?
) else (
    echo. & echo  Current version: %current_version%
    echo  Latest version: v%latest_version%
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
"%temp%\7zr.exe" x -t7z -bso0 "%temp%/ffwin.exe.7z" -o"%~dp0" -xr!setup.exe
xcopy "%~dp0core\*" "%~dp0" /s /e /y /q
rd /s /q "%~dp0core"
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

echo. & echo  DONE. & echo. & timeout 3
