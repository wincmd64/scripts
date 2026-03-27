:: Viber UPDATER
:: by github.com/wincmd64

:: Look for Viber.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: Use /h to update the hosts file and disable Viber ads.

@echo off
setlocal

:: [SETTINGS]
set "dir=%~dp0"
cd /d "%dir%"

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
if not defined current_version (echo. & echo  Download Viber to "%dir%" ? & echo. & pause
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
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/h' & Exit /B)
set "HOSTS=%WINDIR%\System32\drivers\etc\hosts"

call :add 0.0.0.0 ads.viber.com
call :add 0.0.0.0 ads.aws.viber.com
call :add 0.0.0.0 ads-d.viber.com
call :add 0.0.0.0 ads.cdn.viber.com
call :add 0.0.0.0 ad.primis.tech
call :add 0.0.0.0 api.taboola.com
call :add 0.0.0.0 api.mixpanel.com
call :add 0.0.0.0 ams1-mobile.adnxs.com
call :add 0.0.0.0 cdn.taboola.com
call :add 0.0.0.0 contact.primis.tech
call :add 0.0.0.0 data.mixpanel.com
call :add 0.0.0.0 feed.avplayer.com
call :add 0.0.0.0 fra1-ib.adnxs.com
call :add 0.0.0.0 images.taboola.com
call :add 0.0.0.0 locp-ir.viber.com
call :add 0.0.0.0 live.primis.tech
call :add 0.0.0.0 live-eu-am.primis.tech
call :add 0.0.0.0 live-us-ny.primis.tech
call :add 0.0.0.0 live.primis-amp.tech
call :add 0.0.0.0 mediation.adnxs.com
call :add 0.0.0.0 mobile.anycast.adnxs.com
call :add 0.0.0.0 mobile.geo.appnexusgslb.net
call :add 0.0.0.0 pagead2.googlesyndication.com
call :add 0.0.0.0 player.avplayer.com
call :add 0.0.0.0 primis-d.openx.net
call :add 0.0.0.0 primisttd-d.openx.net
call :add 0.0.0.0 primis.tech
call :add 0.0.0.0 primis-amp.tech
call :add 0.0.0.0 rtb.primis.tech
call :add 0.0.0.0 rmp.rakuten.com
call :add 0.0.0.0 stats.viber.com
call :add 0.0.0.0 securepubads.g.doubleclick.net
call :add 0.0.0.0 s-clk.rmp.rakuten.com
call :add 0.0.0.0 s-bid.rmp.rakuten.com
call :add 0.0.0.0 s-imp.rmp.rakuten.com
call :add 0.0.0.0 s-cs.rmp.rakuten.com
call :add 0.0.0.0 s.pc.qq.com
call :add 0.0.0.0 sy.guanjia.qq.com
call :add 0.0.0.0 syzs.qq.com
call :add 0.0.0.0 tracking.viber.com
call :add 0.0.0.0 viberee.olasent.top
call :add 0.0.0.0 video.primis.tech
call :add 0.0.0.0 www.viberee.olasent.top
call :add 0.0.0.0 www.primis.tech
call :add 0.0.0.0 geolocation.onetrust.com
call :add 0.0.0.0 cdn.cookielaw.org
call :add 0.0.0.0 privacyportal.onetrust.com
call :add 0.0.0.0 sendtonews.com
call :add 0.0.0.0 mp.mmvideocdn.com
call :add 0.0.0.0 embed.sendtonews.com 

echo. & echo  DONE. & echo. & pause & exit /b

:add
set "LINE=%1 %2"
findstr /x /i /c:"%LINE%" "%HOSTS%" >nul || (
    echo %LINE%>>"%HOSTS%"
    echo + %LINE%
)
exit /b
