:: Wrapper for HandBrake CLI — convert video using presets
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
set "name=HandBrake CLI"
set "app=HandBrakeCLI.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:download
if exist "%app%" (
    eget.exe query HandBrake/HandBrake
    echo. & echo  Update? & echo. & pause
    eget.exe dl --file "HandBrakeCLI.exe" --asset "cli,x86_64,zip" HandBrake/HandBrake
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
) else (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    eget.exe dl --file "HandBrakeCLI.exe" --asset "cli,x86_64,zip" HandBrake/HandBrake
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% objects. & echo.)
if "%~x1"=="" echo  %ESC%[31m [!] NOTICE: first argument is likely a folder or has no extension.%ESC%[0m & echo.

echo %ESC%[7m  Full list of presets: https://handbrake.fr/docs/en/latest/technical/official-presets.html 
echo   Some examples: "Very Fast 1080p30", "Super HQ 1080p30 Surround", "Fast 1080p30" (default) & echo.%ESC%[0m

SET /p preset= Enter HandBrake preset name or press Enter for default: 
if "%preset%"=="" (SET preset=Fast 1080p30)
TITLE %preset%

FOR %%k IN (%*) DO (
    echo. & echo FILE: %%k
    "%app%" -v0 -Z "%preset%" -E copy -i "%%~k" -o "%%~dpnk_%preset%.mp4"
    FOR /f "tokens=1-5 delims=.-/: " %%m IN ("%%~tk") DO (
        powershell "Get-ChildItem '%%~dpnk_%preset%.mp4' | ForEach-Object{$_.CreationTime = $_.LastWriteTime = $_.LastAccessTime = New-Object DateTime %%o,%%n,%%m,%%p,%%q,00}"
    )
)
color A & timeout 2 & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\HandBrake.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,203'; $s.Save()"
echo. & echo  Shortcut 'HandBrake.lnk' created. & echo. & timeout 2 & exit
