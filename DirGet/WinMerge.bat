:: WinMerge x64 UPDATER
:: by github.com/wincmd64

:: Look for WinMergeU.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=WinMerge"
set "app=WinMergeU.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if "%~1" NEQ "" (if exist "%app%" (start "" "%app%" %* & exit))

if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github latest ver
call :github "WinMerge/winmerge" "*x64-exe.zip" "https://github.com/WinMerge/winmerge/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%" --strip-components=1 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
if not exist "winmerge.ini" (
    echo. & echo  Creating ini ...
    (
      echo [WinMerge]
      echo Settings/PredifferMode=1
      echo Settings/UnpackerMode=1
      echo Settings/CloseWithEsc=3
      echo Settings/SingleInstance=1
      echo Settings/ViewLineNumbers=1
      echo Settings/ViewZoom=750
      echo Backup/EnableFile=0
    ) > "winmerge.ini"
)

color A & echo. & echo. & echo  DOWNLOADED. Re-run compare tool if it was started from Total Commander. & timeout 5 & exit

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
