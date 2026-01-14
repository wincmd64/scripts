:: Wrapper for TrID — file identifier utility
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder
:: /u - update TrID

@echo off
chcp 1251 >nul

for /f "tokens=* delims=" %%a in ('where trid.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0trid.exe" set "app=%~dp0trid.exe"
if not exist "%app%" (
    echo. & echo  "trid.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    curl.exe "https://mark0.net/download/trid_win64.zip" -RLO# --output-dir "%temp%"
    if exist "%temp%\trid_win64.zip" (tar -xf "%temp%\trid_win64.zip" -C "%temp%.") else (echo. & echo  where trid_win64.zip ? & pause)
    "%temp%\TrID_setup.exe" /VERYSILENT /DIR="%~dp0"
    "%~dp0trid.exe" -u
    color A & echo. & echo  DONE. Please re-run this script. & echo. & pause & exit
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)
if /i "%~1"=="/u" (if "%~2"=="" goto update)

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

:update
curl.exe "https://mark0.net/download/trid_win64.zip" -RLO# --output-dir "%temp%" -z "%temp%\trid_win64.zip"
if exist "%temp%\trid_win64.zip" (tar -xf "%temp%\trid_win64.zip" -C "%temp%.") else (echo. & echo  where trid_win64.zip ? & pause)
for %%I in ("%app%") do set "app_folder=%%~dpI"
"%temp%\TrID_setup.exe" /VERYSILENT /DIR="%app_folder%"
"trid.exe" -u
if errorlevel 1 (color C & echo. & pause & exit) else (color A & echo. & echo  UPDATED. & echo. & pause & exit)

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\File Identifier.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app%'; $s.Save()"
echo. & echo  Shortcut 'File Identifier.lnk' created. & echo. & timeout 2
