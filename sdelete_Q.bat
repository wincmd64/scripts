:: Wrapper for SDelete x64 — secure delete utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal

:: [SETTINGS]
set "name=SDelete CLI"
set "app=sdelete64.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: /s arg
if exist "%app%" if /i "%~1"=="/s" goto shortcut

:download
if not exist "%app%" (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    curl.exe -fRLO# "https://live.sysinternals.com/sdelete64.exe"
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

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
if %count% equ 0 (
    cls
    echo. & echo  %ESC%[41mZero free drive space%ESC%[0m & echo.
    set /p "drive=> Enter drive letter to zero free space (e.g. C): "
    if not defined drive (echo. & echo  No drive specified. & pause & exit)
    echo.
    set "drive=!drive:~0,1!"
    choice /c YN /m "> WARNING: This will clean ZERO SPACE on drive '!drive!:' Continue?"
    if errorlevel 2 (echo. & echo  Operation cancelled. & echo. & pause & exit)
    echo.
    "%app%" -nobanner -accepteula -z "!drive!:"
    echo. & echo. & echo  DONE. & echo. & pause & exit
)

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