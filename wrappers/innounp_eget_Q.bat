:: Wrapper for InnoUnp CLI — Inno Setup unpacker
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%N parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir   /!\ REQUIRED: https://github.com/inherelab/eget

@echo off
setlocal

:: [SETTINGS]
set "name=InnoUnp CLI"
set "app=innounp.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:download
if exist "%app%" (
    eget.exe query jrathlev/InnoUnpacker-Windows-GUI
    echo. & echo  Update? & echo. & pause
    eget.exe dl --file "*.exe" --asset "zip" jrathlev/InnoUnpacker-Windows-GUI
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
) else (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    eget.exe dl --file "*.exe" --asset "zip" jrathlev/InnoUnpacker-Windows-GUI
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

if "%~1"=="" (echo. & echo  No objects selected & echo. & pause & exit)
"%app%" "%~1" >nul 2>&1
if errorlevel 1 ("%app%" "%~1" & echo. & pause & exit)
"%app%" -x -d"%~dpn1_unpacked" "%~1"
if errorlevel 1 (echo. & pause & exit) else (if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /T "%~dpn1_unpacked") else (explorer "%~dpn1_unpacked"))
color A & timeout 2 & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\InnoUnpacker.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%dir%%app%'; $s.Save()"
echo. & echo  Shortcut 'InnoUnpacker.lnk' created. & echo. & timeout 2