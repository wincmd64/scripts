:: qBittorrent (portable) UPDATER
:: by github.com/wincmd64

:: Look for qbittorrent.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: Use /a to associate with .torrent files

@echo off
setlocal

:: [SETTINGS]
set "name=qBittorrent"
set "app=qbittorrent.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if /i "%~1"=="/a" if exist "%app%" goto associate

:: get local ver
if exist "%app%" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'qbittorrent.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    echo  Getting latest version...
    for /f %%a in ('powershell -command "$req = [System.Net.WebRequest]::Create('https://sourceforge.net/projects/qbittorrent/files/latest/download'); $req.Method = 'HEAD'; $res = $req.GetResponse(); 'v' + $res.ResponseUri.Segments[4].Trim('/').Replace('qbittorrent-', '')"') do set "latest_version=%%a"
    cls
)

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version%
    echo   Latest version: %latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:: download
:download
echo. & echo  Downloading...
curl.exe -fRL# "https://sourceforge.net/projects/qbittorrent/files/latest/download" -o "%temp%\qbt_setup.exe"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
:7z
for /f "tokens=* delims=" %%a in ('where 7z.exe 2^>nul') do set "zp=%%a"
if not defined zp if exist "C:\Program Files\7-Zip\7z.exe" set "zp=C:\Program Files\7-Zip\7z.exe"
if exist "%zp%" goto skip_7z
echo. & echo  "7z.exe" not found. & echo  Try to download it to "%dir%" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting github link...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ip7z/7zip/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.msi'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try: winget install 7zip.7zip & pause & exit /b)
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Error: download failed. & echo. & pause & goto 7z)
echo. & echo  Extracting ...
msiexec /a "%temp%\%filename%" /qn TARGETDIR="%temp%\7z"
:: finds 7z.exe+7z.dll and move it
for /r "%temp%\7z" %%F in (7z.exe 7z.dll) do (if exist "%%~fF" move /y "%%~fF" "%dir%" >nul)
rd /s /q "%temp%\7z"
goto 7z

:skip_7z
"%zp%" e "%temp%\qbt_setup.exe" "qbittorrent.exe" -y
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DOWNLOADED. Now launching...)
if not exist "profile\" (md "profile")
start "" %app%
timeout 3 & exit

:associate
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
:: get SetUserFTA.exe
if not exist "%fta%" (
    echo. & echo  SetUserFTA.exe required. Try to download it to TEMP ? & echo. & pause
    curl.exe -fRLO# "https://setuserfta.com/SetUserFTA.zip" --output-dir "%temp%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo  Try manual: https://setuserfta.com/SetUserFTA.zip & echo. & pause & exit /b)
    tar -xf "%temp%\SetUserFTA.zip" -C "%temp%"
    if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
    set "fta=%temp%\SetUserFTA.exe"
    echo.
)
assoc .torrent=qbit
ftype qbit="%dir%%app%" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%fta%" .torrent qbit
reg add "HKCU\Software\Classes\qbit\DefaultIcon" /ve /d "%dir%%app%,1" /f >nul
echo. & echo Current associations: & "%fta%" get | findstr /i "qbit" & echo. & pause & exit
