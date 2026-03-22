:: Geek Uninstaller UPDATER
:: by github.com/wincmd64

:: Look for geek.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "geek.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'geek.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    for /f "tokens=*" %%d in ('powershell -command "(Get-Item 'geek.exe').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    echo  Getting latest version...
    for /f "usebackq tokens=*" %%a in (`powershell -command "$req = [Net.HttpWebRequest]::Create('https://geekuninstaller.com/geek.zip'); $res = $req.GetResponse(); $res.LastModified.ToString('dd.MM.yyyy'); $res.Close()"`) do set "latest_date=%%a"
    cls
)
if not defined current_version (echo. & echo  Download Geek Uninstaller to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version% ^(%file_date%^)
    echo  Latest geek.zip: %latest_date%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq geek.exe" | find /i "geek.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Geek Uninstaller is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe "https://geekuninstaller.com/geek.zip" -fRLO# --output-dir "%temp%"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
echo. & echo  Extracting ...
tar -xf "%temp%\geek.zip"
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo  DONE. & echo.)
start "" /b powershell -windowstyle hidden -C "Start-Process 'geek.exe' -Verb RunAs"
