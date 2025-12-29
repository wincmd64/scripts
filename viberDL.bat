:: VIBER DOWNLOADER
::   Alternative to installer / winget using official SFX.
::   Use /h to update the hosts file and disable Viber ads.
:: by github.com/wincmd64

@echo off
:: arguments
if /i "%~1"=="/h" (if "%~2"=="" goto :remove_ads)

cd /d "%~dp0"
if not exist "Viber\" (
    echo. & echo  Download Viber to "%~dp0Viber" ? & echo. & pause
    md "Viber"
) else (
    echo. & echo  Download and update existing installation in "%~dp0Viber" ? & echo. & pause
    :check_viber
    tasklist /fi "imagename eq Viber.exe" | find /i "Viber.exe" >nul
    if not errorlevel 1 (echo. & echo  Viber is currently running. & echo  Please close Viber before updating. & echo. & pause & goto check_viber)
)
if not exist "%temp%\7zr.exe" curl.exe "https://www.7-zip.org/a/7zr.exe" -RLO# --output-dir "%temp%"
curl.exe "http://download.cdn.viber.com/desktop/windows/update/update.zip" -RLO# --output-dir "%temp%"
if exist "%temp%\update.zip" (tar -xf "%temp%\update.zip" -C "Viber" 2>nul) else (echo. & echo  update.zip not found. & pause)
set "VERDIR="
for /d %%D in ("Viber\*") do (
    if exist "%%D\pack.exe" (
        set "VERDIR=%%~fD"
        goto found
    )
)
:found
echo  Extracting: %VERDIR%\pack.exe
"%temp%\7zr.exe" x "%VERDIR%\pack.exe" -o"Viber" -y -bso0
rd /s /q "%VERDIR%"
del "Viber\ViberUpdater.cmd" /q

echo. & echo  DONE. & echo.
choice /c YN /m "Create desktop shortcut? "
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Viber.lnk'); ^
$s.TargetPath = '%~dp0Viber\Viber.exe'; $s.WorkingDirectory='%~dp0Viber'; $s.IconLocation = '%~dp0Viber\Viber.exe'; $s.Save()"
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