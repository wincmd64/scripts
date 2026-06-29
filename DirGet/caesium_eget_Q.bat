:: Wrapper for Caesium CLI — image compression utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir   /!\ REQUIRED: https://github.com/inherelab/eget

@echo off
setlocal

:: [SETTINGS]
set "name=Caesium CLI"
set "app=caesiumclt.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:download
if exist "%app%" (
    eget.exe query Lymphatus/caesium-clt
    echo. & echo  Update? & echo. & pause
    eget.exe dl --file "*.exe" --strip-components 1 --asset "zip" Lymphatus/caesium-clt
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
) else (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    eget.exe dl --file "*.exe" --strip-components 1 --asset "zip" Lymphatus/caesium-clt
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo. & pause) else (echo. & echo  Processing %count% objects. & echo. & pause)

FOR %%k IN (%*) DO (echo. & "%app%" --lossless --exif --keep-dates --same-folder-as-input --overwrite bigger "%%~k")
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Image compression.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,139'; $s.Save()"
echo. & echo  Shortcut 'Image compression.lnk' created. & echo. & timeout 2 & exit
