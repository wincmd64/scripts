:: Wrapper for HandBrake CLI — convert video using presets
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
set "name=HandBrake CLI"
set "app=HandBrakeCLI.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local ver
if not exist "%app%" goto update
echo. & echo  Getting current version...
for /f "usebackq tokens=2" %%a in (`""%app%" --version 2>&1 | findstr /C:"HandBrake ""`) do (
    set "current_version=%%a"
    goto :update
)

:update
cls
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: github latest ver
call :github "HandBrake/HandBrake" "*CLI*x86_64.zip" "https://github.com/HandBrake/HandBrake/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
tar -xf "%temp%\%filename%" *.exe 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

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

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference='SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; $rel = $r | Where-Object { !$_.prerelease -and ($_.assets.name -like '%filter%') } | Select-Object -First 1; if(!$rel){exit}; $a=$rel.assets | Where-Object { $_.name -like '%filter%' } | Select-Object -First 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
for /f "usebackq tokens=*" %%a in (`powershell -command "%ps_cmd%" 2^>nul`) do (
    if not defined latest_version (
        set "latest_version=%%a"
    ) else if not defined url (
        set "url=%%a"
    ) else if not defined filename (
        set "filename=%%a"
    ) else (
        set "server_date=%%a"
    )
)

:: if PS failed, latest_version will contain error text or be empty
if "%url:~0,4%" NEQ "http" (
    set "url="
    set "latest_version="
    echo.
    echo  Error: Repository "%repo%" not found or API limit reached.
    echo  Try manual: %manual_url%  & echo. & pause
    exit /b
)

echo. & echo  Repo: %repo%
echo   Ver: %latest_version% (%server_date%)
echo  File: %filename%
echo  Link: %url%
echo.
goto :eof