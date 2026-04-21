:: System Informer [canary] x64 UPDATER
:: by github.com/wincmd64

:: Look for SystemInformer.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=System Informer"
set "app=SystemInformer.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local file date
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github api
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/winsiderss/si-builds/releases'; $rel=$r[0]; $a=$rel.assets | ?{$_.name -like '*win64*.zip'} | select -f 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (color C & echo. & echo  Error: Could not find download URL. & echo  Try manual: https://github.com/winsiderss/si-builds/releases & echo. & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo.
    pause
)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:download
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (echo. & echo  Error: %url% download failed. & echo. & pause & goto download)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
tar -xf "%temp%\%filename%" --exclude=x86 --exclude=*.sig
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo  DOWNLOADED. Now launching %name%... & echo.)
if not exist "SystemInformer.exe.settings.xml" (
    echo. & echo  Creating SystemInformer.exe.settings.xml ...
    (
     echo ^<settings^>
     echo   ^<setting name="$schema"^>https://systeminformer.io/settings.schema.json^</setting^>
     echo ^</settings^>
    ) > "SystemInformer.exe.settings.xml"
)
start "" /b powershell -windowstyle hidden -C "Start-Process '%app%' -Verb RunAs"

