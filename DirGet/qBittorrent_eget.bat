:: qBittorrent (portable) UPDATER
:: by github.com/wincmd64

:: Look for qbittorrent.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

::   COMMAND LINE ARGUMENTS:
:: /a - associate with .torrent files (admin rights required)

::   DEPENDENCIES (searching in PATH):
:: eget.exe -- https://github.com/inherelab/eget/releases/latest/download/eget-windows-amd64.exe
:: 7z.exe with 7z.dll -- https://www.7-zip.org
:: SetUserFTA.exe -- https://setuserfta.com/SetUserFTA.zip

@echo off
setlocal
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

:: [SETTINGS]
set "name=qBittorrent"
set "app=qbittorrent.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: dependencies
set "deps_missing="
echo. & echo  Checking dependencies:
call :check eget.exe
call :check 7z.exe
echo.
if not defined deps_missing cls
goto :continue
:check
where "%~1" >nul 2>&1 && (echo   [FOUND] %~1) || (echo   [MISSING] %~1 & set "deps_missing=1")
exit /b
:continue

:: arguments
if exist "%app%" if /i "%~1"=="/a" goto associate

:: get local ver
if exist "%app%" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
) else (echo. & echo  Download %name% to "%dir%" ? & echo. & pause & echo.)

:: get server ver
if defined current_version (
    echo. & echo  Getting server version... & echo.
    "eget.exe" query "sourceforge:qbittorrent/qbittorrent-win32"
    echo  %ESC%[7mUpdate current %current_version% ?%ESC%[0m & echo. & pause & echo.
)

:download
if not exist "profile\" (md "profile")
"eget.exe" dl --file "%app%" --asset "x64,setup,exe,^asc,^lt20" "sourceforge:qbittorrent/qbittorrent-win32"
if %errorlevel% neq 0 (echo. & pause & echo. & goto download) else (echo. & echo  %ESC%[7mDONE.%ESC%[0m & timeout 3 & exit)

:associate
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
where SetUserFTA.exe >nul 2>&1 || (echo. & echo    [ERROR] SetUserFTA.exe not found in PATH & echo. & pause)
assoc .torrent=qbit
ftype qbit="%dir%%app%" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"SetUserFTA.exe" .torrent qbit
reg add "HKCU\Software\Classes\qbit\DefaultIcon" /ve /d "%dir%%app%" /f >nul
echo. & echo Current associations: & "SetUserFTA.exe" get | findstr /i "qbit" & echo. & pause & exit
