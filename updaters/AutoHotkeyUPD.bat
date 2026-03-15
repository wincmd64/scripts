:: AutoHotkey v2 x64 UPDATER
:: by github.com/wincmd64

:: Look for AutoHotkey64.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

echo. & echo  Getting version...
if exist "AutoHotkey64.exe" (for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'AutoHotkey64.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v")
for /f "delims=" %%a in ('curl -s "https://www.autohotkey.com/download/2.0/version.txt"') do set "LATEST=%%a"
cls

if not defined current_version (echo. & echo  Download AutoHotkey v%LATEST% to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: v%current_version%
    echo   Latest version: v%LATEST%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq AutoHotkey64.exe" | find /i "AutoHotkey64.exe" >nul
if not errorlevel 1 (echo. & echo  [!] AutoHotkey is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading: https://www.autohotkey.com/download/ahk-v2.zip
curl.exe -RLO# "https://www.autohotkey.com/download/ahk-v2.zip" --output-dir "%temp%"
echo. & echo  Extracting ...
if exist "%temp%\ahk-v2.zip" (tar -xf "%temp%\ahk-v2.zip" AutoHotkey64.exe AutoHotkey.chm UX/WindowSpy.ahk) else (echo. & echo  ahk-v2.zip not found. & pause)
move /y "UX\WindowSpy.ahk" "WindowSpy.ahk" >nul
rd "UX"
color A & echo. & echo. & echo  DONE. & timeout 3
