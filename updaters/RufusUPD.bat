:: Rufus x64 UPDATER
:: by github.com/wincmd64

:: Look for rufus-p.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "rufus-p.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'rufus-p.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download Rufus to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/pbatard/rufus/releases/latest'; $a=$r.assets|?{$_.name -like '*p.exe'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/pbatard/rufus/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
)
:check_task
tasklist /nh | findstr /i "rufus.*\.exe" >nul && (echo. & echo  [!] Rufus is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
curl.exe -fRL# "%url%" -o "rufus-p.exe" 2>nul
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b) else (color A & echo. & echo. & echo  DONE. & echo.)
start "" /b powershell -windowstyle hidden -C "Start-Process 'rufus-p.exe' -Verb RunAs"