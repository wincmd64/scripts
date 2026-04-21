:: Ventoy UPDATER
:: by github.com/wincmd64

:: Look for Ventoy2Disk.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "ventoy\version" set /p ventoy_raw=<"ventoy\version" & call set "current_version=v%%ventoy_raw%%"
if not defined current_version (echo. & echo  Download Ventoy to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ventoy/Ventoy/releases/latest'; $a=$r.assets|?{$_.name -like '*windows.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/ventoy/Ventoy/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq Ventoy2Disk.exe" | find /i "Ventoy2Disk.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] Ventoy is running. Please close it to continue. & echo. & pause & goto check_task)
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
tar -xf "%temp%\%filename%" --strip-components=1 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DOWNLOADED. Now launching Ventoy... & echo.)
start "" /b powershell -windowstyle hidden -C "Start-Process 'Ventoy2Disk.exe' -Verb RunAs"
