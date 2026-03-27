:: Wrapper for SDelete x64 — secure delete utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir

@echo off
setlocal

:: [SETTINGS]
set "app=sdelete64.exe"
set "dir=%~dp0"
set "app_path=%dir%%app%"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local file date
if exist "%app%" (
    echo. & echo  Getting local file date...
    for /f "tokens=*" %%d in ('powershell -C "(Get-Item '%app%').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    cls
)

if not defined file_date (echo. & echo  Download SDelete CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current file date: %file_date% & echo  Checking for updates...)

:: getting server file date
for /f "tokens=3-5" %%a in ('curl -sI "https://live.sysinternals.com/sdelete64.exe" ^| findstr /i "Last-Modified"') do (set "server_date=%%a %%b %%c")

:: update logic
if defined file_date (
    echo   Server file date: %server_date%
    echo. & echo  Update? & echo.
    pause
)

:: download
curl.exe -fRLO# "https://live.sysinternals.com/sdelete64.exe"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %app%
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

:: file counts
setlocal enabledelayedexpansion
set count=0
set shown=0
echo. & echo  %ESC%[41mSelected for secure deletion%ESC%[0m:
for %%A in (%*) do set /a count+=1
for %%A in (%*) do (
    set /a shown+=1
    if !shown! LEQ 5 (
        echo    %%~A
    )
)
:: >5
if %count% GTR 5 (
    set /a remaining=%count%-5
    call echo  ... and %ESC%[41m%%remaining%% more%ESC%[0m
)
if %count% equ 0 (echo. & echo    ^(no objects selected^) & echo. & pause & exit)

:: confirm
endlocal
echo.
choice /c YN /m "> WARNING: This will permanently erase the selected object(s). Continue?"
if errorlevel 2 (echo. & echo  Operation cancelled. & echo. & pause & exit)
FOR %%k IN (%*) DO (echo. & "%app%" -nobanner -accepteula -s "%%~k")
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Secure Delete.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'imageres.dll,-5320'; $s.Save()"
echo. & echo  Shortcut 'Secure Delete.lnk' created. & echo. & timeout 2