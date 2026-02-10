:: VIBER UPDATER
::   Alternative to installer/winget using official SFX.
::   Use /h to update the hosts file and disable Viber ads.
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: arguments
if /i "%~1"=="/h" goto remove_ads

:: get local ver
if exist "Viber.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'Viber.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    for /f "tokens=*" %%d in ('powershell -command "(Get-Item 'Viber.exe').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    cls
)
if not defined current_version (echo. & echo  Download Viber to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% ^(%file_date%^) & echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq Viber.exe" | find /i "Viber.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Viber is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe -RL#z "%temp%\update.zip" "http://download.cdn.viber.com/desktop/windows/update/update.zip" -o "%temp%\update.zip" 2>nul
curl.exe -RL#z "%temp%\7zr.exe" "https://www.7-zip.org/a/7zr.exe" -o "%temp%\7zr.exe" 2>nul
if exist "%temp%\update.zip" (tar -xf "%temp%\update.zip" -C "%temp%" --strip-components=1) else (echo. & echo  update.zip not found. & pause)
echo. & echo  Extracting ...
"%temp%\7zr.exe" x "%temp%\pack.exe" -o".\" -y -bso0
echo. & echo  DONE. & echo.

choice /c YN /m "Create desktop shortcut"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Viber.lnk'); ^
$s.TargetPath = '%~dp0Viber.exe'; $s.WorkingDirectory='%~dp0'; $s.IconLocation = '%~dp0Viber.exe'; $s.Save()"
echo. & echo  Shortcut 'Viber.lnk' created. & echo. & timeout 2 & exit

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
