:: AutoHotkey v2 x64 UPDATER
:: by github.com/wincmd64

:: Look for AutoHotkey64.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=AutoHotkey"
set "app=AutoHotkey64.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

if not defined current_version echo. & echo  Download %name% to "%dir%" ? & echo. & pause & goto check_task
echo. & echo  Getting version...
for /f "delims=" %%a in ('curl -s "https://www.autohotkey.com/download/2.0/version.txt"') do set "LATEST=%%a"
cls
echo. & echo  Current version: v%current_version%
echo   Latest version: v%LATEST%
echo. & echo  Update? & echo. & pause

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
echo. & echo  Downloading: https://www.autohotkey.com/download/ahk-v2.zip
curl.exe -fRLO# "https://www.autohotkey.com/download/ahk-v2.zip" --output-dir "%temp%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\ahk-v2.zip" AutoHotkey64.exe AutoHotkey.chm UX/WindowSpy.ahk
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
move /y "UX\WindowSpy.ahk" "WindowSpy.ahk" >nul
rd "UX"
color A & echo. & echo. & echo  DONE. & timeout 3
