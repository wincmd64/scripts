:: KeePass 2x UPDATER
:: by github.com/wincmd64

:: Look for KeePass.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: [COMMAND LINE ARGUMENTS]
:: /a - associate with .kdbx files (admin rights required)

:: [DEPENDENCIES] -- searching in PATH
:: SetUserFTA.exe -- https://setuserfta.com/SetUserFTA.zip
:: eget.exe -- https://github.com/inherelab/eget/releases/latest/download/eget-windows-amd64.exe

@echo off
setlocal

:: [SETTINGS]
set "name=KeePass"
set "app=KeePass.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if exist "%app%" if /i "%~1"=="/a" goto associate
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
) else (echo. & echo  Download %name% to "%dir%" ? & echo. & pause & echo.)

if defined current_version (
    echo. & echo  Getting server version... & echo.
    "eget.exe" query "sourceforge:keepass/KeePass 2.x"
    echo  %ESC%[7mUpdate current %current_version% ?%ESC%[0m & echo. & pause & echo.
)

:: download and unpack
"eget.exe" dl --extract-all --asset "zip,^REG:Source" "sourceforge:keepass/KeePass 2.x"
"eget.exe" dl --fallback-versions 5 --asset "Ukrainian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
"eget.exe" dl --fallback-versions 2 --asset "Russian,zip" --extract-all --to .\Languages "sourceforge:keepass/Translations 2.x"
echo. & echo  %ESC%[7mDONE.%ESC%[0m & timeout 3 & exit

:associate
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
assoc .kdbx=kpass2
ftype kpass2="%dir%%app%" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"SetUserFTA.exe" .kdbx kpass2
reg add "HKCU\Software\Classes\kpass2\DefaultIcon" /ve /d "%dir%%app%" /f >nul
echo. & echo Current associations: & "SetUserFTA.exe" get | findstr /i "kpass2" & echo. & pause & exit
