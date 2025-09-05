:: Wrapper for SDelete — secure delete utility
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
for /f "tokens=* delims=" %%a in ('where sdelete64.exe 2^>nul') do set "app=%%a"
if not exist "%app%" (
    echo. & echo  "sdelete64.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    cd /d "%~dp0"
    curl.exe --ssl-no-revoke -RO# "https://live.sysinternals.com/sdelete64.exe"
    if errorlevel 1 (color C & echo. & pause & exit) else (color A & echo. & echo  DONE. Please re-run this script. & echo. & pause & exit)
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Delete %* ? & echo. & pause) else (echo. & echo  Delete %count% objects? & echo. & pause)

FOR %%k IN (%*) DO (echo. & "%app%" -nobanner -s "%%~k")
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Secure Delete.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'imageres.dll,-5320'; $s.Save()"
echo. & echo  Shortcut 'Secure Delete.lnk' created. & echo. & pause & exit
