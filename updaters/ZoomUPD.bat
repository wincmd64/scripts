:: Zoom x64 UPDATER
:: by github.com/wincmd64

:: Look for Zoom.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "Zoom.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'Zoom.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    for /f "tokens=*" %%d in ('powershell -command "(Get-Item 'Zoom.exe').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    echo  Getting latest version...
    for /f "usebackq tokens=*" %%a in (`powershell -command "$req = [Net.HttpWebRequest]::Create('https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64'); $res = $req.GetResponse(); $res.LastModified.ToString('dd.MM.yyyy'); $res.Close()"`) do set "latest_date=%%a"
    cls
)

if not defined current_version (echo. & echo  Download Zoom to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version% ^(%file_date%^)
    echo  Latest ZoomInstallerFull.msi: %latest_date%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq Zoom.exe" | find /i "Zoom.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Zoom is running. Please close it to continue. & echo. & pause & goto check_task)

echo. & echo  Downloading...
curl.exe "https://zoom.us/client/latest/ZoomInstallerFull.msi?archType=x64" -RLO# --output-dir "%temp%"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
echo. & echo  Extracting ...
msiexec /a "%temp%\ZoomInstallerFull.msi" /qn TARGETDIR="%temp%\zoom"
xcopy "%temp%\zoom\Program Files (64-bit) Folder\Zoom\bin\*" "%~dp0" /y /e /i /q >nul
echo. & echo  Registering Zoom URL Protocol...
reg add "HKCU\SOFTWARE\Classes\zoommtg" /ve /d "URL:Zoom Launcher" /f >nul
reg add "HKCU\SOFTWARE\Classes\zoommtg" /v "URL Protocol" /d "" /f >nul
reg add "HKCU\SOFTWARE\Classes\zoommtg" /v "UseOriginalUrlEncoding" /t REG_DWORD /d 1 /f >nul
reg add "HKCU\SOFTWARE\Classes\zoommtg\DefaultIcon" /ve /d "\"%~dp0Zoom.exe\",1" /f >nul
reg add "HKCU\SOFTWARE\Classes\zoommtg\shell\open\command" /ve /d "\"%~dp0Zoom.exe\" \"--url=%%1\"" /f >nul
color A & echo. & echo. & echo  DONE. Running Zoom... & echo.

start "" Zoom.exe
timeout 3 & exit
