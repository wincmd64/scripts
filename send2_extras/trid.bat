:: Wrapper for TrID — file identifier utility
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
chcp 1251 >nul

for /f "tokens=* delims=" %%a in ('where trid.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0trid.exe" set "app=%~dp0trid.exe"
if not exist "%app%" (
    echo. & echo  "trid.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    cd /d "%~dp0"
    if not exist "trid_win64.zip" (curl.exe --ssl-no-revoke -RO# "https://mark0.net/download/trid_win64.zip")
    if errorlevel 1 (color C & echo. & pause & exit)
    if not exist "triddefs.zip" (curl.exe --ssl-no-revoke -RO# "https://mark0.net/download/triddefs.zip")
    if exist "trid_win64.zip" (tar -xf "trid_win64.zip" 2>nul) else (echo. & echo  where trid_win64.zip ? & pause)
    if exist "triddefs.zip" (tar -xf "triddefs.zip" 2>nul) else (echo. & echo  where triddefs.zip ? & pause)
    "TrID_setup.exe" /VERYSILENT /DIR="%~dp0"
    del "TrID_setup.exe" "trid_win64.zip" "triddefs.zip" /q
    color A & echo. & echo  DONE. Please re-run this script. & echo. & pause & exit
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)

:: triddefs.trd path
set "appdir=%app%"
for %%p in ("%appdir%") do set "appdir=%%~dpp"

pushd "%~dp1"
(
    for %%i in (%*) do (
        if exist "%%~fi\" (
            rem directory - include only files from the top level
            for %%x in ("%%~fi\*") do @if not exist "%%~fx\" echo %%~fx
        ) else (
            rem file
            @echo %%~fi
        )
    )
) > "%TEMP%\tridlist.txt"
:: add -o "trid.csv" to generate the results in CSV format
"%app%" -d "%appdir%triddefs.trd" -f "%TEMP%\tridlist.txt"
del "%TEMP%\tridlist.txt"

echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\File Identifier.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app%'; $s.Save()"
echo. & echo  Shortcut 'File Identifier.lnk' created. & echo. & timeout 2
