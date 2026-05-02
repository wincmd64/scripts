:: Wrapper for Caesium CLI — image compression utility
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
set "name=Caesium CLI"
set "app=caesiumclt.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local ver
if exist "%app%" (for /f "tokens=2" %%i in ('"%app%" -V') do set current_version=%%i)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: github latest ver
call :github "Lymphatus/caesium-clt" "*windows-msvc.zip" "https://github.com/Lymphatus/caesium-clt/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
tar -xf "%temp%\%filename%" --strip-components=1 *.exe 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

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