:: Wrapper for InnoUnp CLI — Inno Setup unpacker
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%N parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
for /f "tokens=* delims=" %%a in ('where innounp.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0innounp.exe" set "app=%~dp0innounp.exe"
if not exist "%app%" (
    echo. & echo  "innounp.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    cd /d "%~dp0"
    curl.exe --ssl-no-revoke -RO# "https://www.rathlev-home.de/tools/download/innounp-2.zip"
    tar -xf innounp-2.zip innounp.exe
    del innounp-2.zip
    if errorlevel 1 (color C & echo. & pause & exit) else (color A & echo. & echo  DONE. Please re-run this script. & echo. & pause & exit)
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

if "%~1"=="" (echo. & echo  No objects selected & echo. & pause & exit)
"%app%" "%~1" >nul 2>&1
if errorlevel 1 ("%app%" "%~1" & echo. & pause & exit)
"%app%" -x -d"%~dpn1_unpacked" "%~1"
if errorlevel 1 (echo. & pause & exit) else (timeout 2 & exit)

:shortcut
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\InnoUnpacker.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app%'; $s.Save()"
echo. & echo  Shortcut 'InnoUnpacker.lnk' created. & echo. & pause & exit