:: Notepad++ x64 UPDATER
:: by github.com/wincmd64

:: Look for notepad++.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if "%~1" NEQ "" (if exist "notepad++.exe" (start "" "notepad++.exe" %* & exit))

if exist "notepad++.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'notepad++.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=v%%v"
    cls
)

if not defined current_version (echo. & echo  Download Notepad++ to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest'; $a=$r.assets|?{$_.name -like '*portable.x64.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/notepad-plus-plus/notepad-plus-plus/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq notepad++.exe" | find /i "notepad++.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] Notepad++ is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\npp_update" rd /s /q "%temp%\npp_update"
mkdir "%temp%\npp_update"
tar -xf "%temp%\%filename%" -C "%temp%\npp_update"
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
robocopy "%temp%\npp_update\localization" "%dir%localization" english.xml russian.xml ukrainian.xml /move /r:0 /w:0 >nul
if exist "notepad++.exe" (
    :: ignore root *.xml
    robocopy "%temp%\npp_update" "%dir%." /move /xf *.xml /xd localization updater /r:0 /w:0 >nul
) else (
    robocopy "%temp%\npp_update" "%dir%." /e /move /xd localization updater /r:0 /w:0 >nul
)
color A & echo. & echo. & echo  DOWNLOADED. Now launching Notepad++... & echo.
start "" notepad++.exe
timeout 2 & exit
