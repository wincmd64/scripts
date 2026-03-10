:: Rufus x64 UPDATER
:: by github.com/wincmd64

:: Look for rufus*.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: resetting variables
set "latest_version=" & set "url=" & set "filename=" & set "exist="

:: get local ver
if exist "rufus*.exe" (
    echo. & echo  Current version^(s^):
    for %%f in (rufus*.exe) do (echo    %%f)
    set exist=1
) else (echo. & echo  Download Rufus to "%~dp0" ? & echo. & pause)

echo. & echo  Checking for updates...
:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/pbatard/rufus/releases/latest'; $a=$r.assets|?{$_.name -like '*p.exe'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/pbatard/rufus/releases & pause & exit /b)

:: update logic
if defined exist (
    echo    Latest version: %latest_version%
    echo. & echo  Update? & echo. 
    pause
)

:check_task
tasklist /nh | findstr /i "rufus.*\.exe" >nul && (echo. & echo  [!] Rufus is running. Please close it to continue. & echo. & pause & goto check_task)

:: download
echo. & echo  Downloading: %filename%
curl.exe -RLO# "%url%" && (color A & echo. & echo  DONE. & echo.) || (echo. & echo DOWNLOAD FAILED. & echo.)
pause