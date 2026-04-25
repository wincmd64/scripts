:: WinDirStat x64 UPDATER
:: by github.com/wincmd64

:: Look for WinDirStat.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: [COMMAND LINE ARGUMENTS]
:: /i - add WinDirStat to Folder/Drive context menu (hold Shift to activate)
:: /u - remove WinDirStat from context menu
:: (no arguments) - check/update software in script dir

@echo off
setlocal

:: [SETTINGS]
set "name=WinDirStat"
set "app=WinDirStat.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if /i "%~1" EQU "/i" (goto add_menu)
if exist "%app%" if /i "%~1" EQU "/u" (goto del_menu)

:: get local file date
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: github latest ver
call :github "windirstat/windirstat" "*x64.msi" "https://github.com/windirstat/windirstat/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:download
curl.exe -fRLO# "https://github.com/windirstat/windirstat/releases/latest/download/WinDirStat-x64.msi" --output-dir "%temp%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
msiexec /a "%temp%\WinDirStat-x64.msi" /qn TARGETDIR="%temp%\WDS_Extract"
move /y "%temp%\WDS_Extract\PFiles64\WinDirStat\WinDirStat.exe" "%dir%"
if not exist "WinDirStat.ini" (
    echo. & echo  Creating WinDirStat.ini ...
    (
     echo [Options]
     echo ShowElevationPrompt=0
     echo [TreeMapView]
     echo ShowTreeMap=0
    ) > "WinDirStat.ini"
)
color A & echo. & echo. & echo  DOWNLOADED. Now launching...
start "" %app% & timeout 2 & exit

:add_menu
reg add "HKCU\Software\Classes\Directory\shell\WinDirStat" /v "MUIVerb" /d "WinDirStat" /f
reg add "HKCU\Software\Classes\Directory\shell\WinDirStat" /v "Icon" /d "%dir%%app%" /f
reg add "HKCU\Software\Classes\Directory\shell\WinDirStat" /v "Position" /d "Bottom" /f
reg add "HKCU\Software\Classes\Directory\shell\WinDirStat" /v "Extended" /f
reg add "HKCU\Software\Classes\Directory\shell\WinDirStat\command" /ve /d "\"%dir%%app%\" \"%%1\"" /f

reg add "HKCU\Software\Classes\Drive\shell\WinDirStat" /v "MUIVerb" /d "WinDirStat" /f
reg add "HKCU\Software\Classes\Drive\shell\WinDirStat" /v "Icon" /d "%dir%%app%" /f
reg add "HKCU\Software\Classes\Drive\shell\WinDirStat" /v "Position" /d "Bottom" /f
reg add "HKCU\Software\Classes\Drive\shell\WinDirStat" /v "Extended" /f
reg add "HKCU\Software\Classes\Drive\shell\WinDirStat\command" /ve /d "\"%dir%%app%\" \"%%1\"" /f && (color A & timeout 2 & exit) || (echo. & pause & exit)

:del_menu
reg delete "HKCU\Software\Classes\Directory\shell\WinDirStat" /f
reg delete "HKCU\Software\Classes\Drive\shell\WinDirStat" /f && (color A & timeout 2 & exit) || (echo. & pause & exit)

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