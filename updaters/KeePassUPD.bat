:: KeePass 2x UPDATER
:: by github.com/wincmd64

:: Look for KeePass.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: arguments
if /i "%~1"=="/a" goto associate

:: get local ver
if exist "KeePass.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'KeePass.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
)

echo. & echo  Getting latest version...
for /f %%a in ('powershell -command "$req = [System.Net.HttpWebRequest]::Create('https://sourceforge.net/projects/keepass/files/latest/download'); $req.AllowAutoRedirect = $true; $res = $req.GetResponse(); $finalUrl = $res.ResponseUri.ToString(); if ($finalUrl -match 'KeePass-([\d\.]+)\.zip') { $matches[1] }"') do (
    set "latest_version=%%a"
    set "download_url=https://sourceforge.net/projects/keepass/files/KeePass%%202.x/%%a/KeePass-%%a.zip/download"
)
cls

if not defined current_version (echo. & echo  Download KeePass to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: v%current_version%
    echo   Latest version: v%latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq KeePass.exe" | find /i "KeePass.exe" >nul
if not errorlevel 1 (echo. & echo  [!] KeePass is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading: %download_url%
curl.exe -fRL# "%download_url%" -o "%temp%\kpass.zip"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
curl.exe -RLO# "https://downloads.sourceforge.net/keepass/KeePass-%latest_version%-Russian.zip" --output-dir "%temp%"
echo. & echo  Extracting ...
tar -xf "%temp%\kpass.zip" 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
if exist "%temp%\KeePass-%latest_version%-Russian.zip" tar -xf "%temp%\KeePass-%latest_version%-Russian.zip" -C "Languages" 2>nul

start "" KeePass.exe
timeout 3 & exit

:associate
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
if not exist "KeePass.exe" (echo. & echo  KeePass.exe not found. & echo. & pause & exit)
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
if not defined fta if exist "%~dp0SetUserFTA.exe" set "fta=%~dp0SetUserFTA.exe"
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
ftype kpass2="%~dp0KeePass.exe" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%fta%" .kdbx kpass2
reg add "HKCU\Software\Classes\kpass2\DefaultIcon" /ve /d "%~dp0KeePass.exe" /f >nul
echo. & echo Current KeePass associations: & "%fta%" get | findstr /i "kpass2" & echo. & pause & exit
