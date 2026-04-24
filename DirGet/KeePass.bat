:: KeePass 2x UPDATER
:: by github.com/wincmd64

:: Look for KeePass.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: Use /a to associate with .kdbx files

@echo off
setlocal

:: [SETTINGS]
set "name=KeePass"
set "app=KeePass.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if /i "%~1"=="/a" goto associate

:: get local ver
if exist "%app%" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

for /f %%a in ('powershell -command "$req = [System.Net.HttpWebRequest]::Create('https://sourceforge.net/projects/keepass/files/latest/download'); $req.AllowAutoRedirect = $true; $res = $req.GetResponse(); $finalUrl = $res.ResponseUri.ToString(); if ($finalUrl -match 'KeePass-([\d\.]+)\.zip') { $matches[1] }"') do (
    set "latest_version=%%a"
    set "download_url=https://sourceforge.net/projects/keepass/files/KeePass%%202.x/%%a/KeePass-%%a.zip/download"
)

if defined current_version (
    echo   Latest version: v%latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading: %download_url%
curl.exe -fRL# "%download_url%" -o "%temp%\kpass.zip"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
curl.exe -RLO# "https://downloads.sourceforge.net/keepass/KeePass-%latest_version%-Russian.zip" --output-dir "%temp%"
echo. & echo  Extracting ...
tar -xf "%temp%\kpass.zip" 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
if exist "%temp%\KeePass-%latest_version%-Russian.zip" tar -xf "%temp%\KeePass-%latest_version%-Russian.zip" -C "Languages" 2>nul
color A & echo. & echo. & echo  DOWNLOADED. Now launching... & echo.
start "" %app%
timeout 3 & exit

:associate
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
if not exist "%app%" (echo. & echo  %app% not found. & echo. & pause & exit)
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
if not defined fta if exist "%dir%SetUserFTA.exe" set "fta=%dir%SetUserFTA.exe"
:: get SetUserFTA.exe
if not exist "%fta%" (
    echo. & echo  SetUserFTA.exe required. Try to download it to TEMP ? & echo. & pause
    curl.exe -fRLO# "https://setuserfta.com/SetUserFTA.zip" --output-dir "%temp%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo  Try manual: https://setuserfta.com/SetUserFTA.zip & echo. & pause & exit /b)
    tar -xf "%temp%\SetUserFTA.zip" -C "%temp%"
    if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
    set "fta=%temp%\SetUserFTA.exe"
)
assoc .kdbx=kpass2
ftype kpass2="%dir%%app%" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%fta%" .kdbx kpass2
reg add "HKCU\Software\Classes\kpass2\DefaultIcon" /ve /d "%dir%%app%" /f >nul
echo. & echo Current KeePass associations: & "%fta%" get | findstr /i "kpass2" & echo. & pause & exit
