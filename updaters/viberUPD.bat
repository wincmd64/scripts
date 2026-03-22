:: Viber UPDATER
:: by github.com/wincmd64

:: Look for Viber.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.
:: Use /h to update the hosts file and disable Viber ads.

@echo off
cd /d "%~dp0"

:: arguments
if /i "%~1"=="/h" goto remove_ads

:: get local ver
if exist "Viber.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'Viber.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    for /f "tokens=*" %%d in ('powershell -command "(Get-Item 'Viber.exe').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    echo  Getting latest version...
    for /f "usebackq tokens=*" %%a in (`powershell -command "$req = [Net.HttpWebRequest]::Create('http://download.cdn.viber.com/desktop/windows/update/update.zip'); $res = $req.GetResponse(); $res.LastModified.ToString('dd.MM.yyyy'); $res.Close()"`) do set "latest_date=%%a"
    cls
)
if not defined current_version (echo. & echo  Download Viber to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version% ^(%file_date%^)
    echo  Latest update.zip: %latest_date%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq Viber.exe" | find /i "Viber.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Viber is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe "http://download.cdn.viber.com/desktop/windows/update/update.zip" -RLO# --output-dir "%temp%"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
curl.exe "https://www.7-zip.org/a/7zr.exe" -RLO# --output-dir "%temp%"
echo. & echo  Extracting ...
tar -xf "%temp%\update.zip" -C "%temp%" --strip-components=1
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
"%temp%\7zr.exe" x "%temp%\pack.exe" -o".\" -y -bso0
color A & echo. & echo  DONE. Running Viber...  & echo.

start "" Viber.exe
timeout 3 & exit

:remove_ads
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/h' & Exit /B)
set "HOSTS=%WINDIR%\System32\drivers\etc\hosts"

call :add 127.0.0.1 ads.viber.com
call :add 127.0.0.1 ads.aws.viber.com
call :add 127.0.0.1 ads-d.viber.com
call :add 127.0.0.1 s-bid.rmp.rakuten.com
call :add 127.0.0.1 s-imp.rmp.rakuten.com
call :add 127.0.0.1 api.mixpanel.com

echo. & echo  DONE. & echo. & pause & exit /b

:add
set "LINE=%1 %2"
findstr /x /i /c:"%LINE%" "%HOSTS%" >nul || (
    echo %LINE%>>"%HOSTS%"
    echo + %LINE%
)
exit /b
