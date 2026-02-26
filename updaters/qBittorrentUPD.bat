:: qBittorrent (PORTABLE) UPDATER
::   Alternative to winget
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: get local ver
if exist "qbittorrent.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'qbittorrent.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    echo  Getting latest version...
    for /f %%a in ('powershell -command "$req = [System.Net.WebRequest]::Create('https://sourceforge.net/projects/qbittorrent/files/latest/download'); $req.Method = 'HEAD'; $res = $req.GetResponse(); $res.ResponseUri.Segments[4].Trim('/')"') do set "latest_version=%%a"
    cls
)

if not defined current_version (echo. & echo  Download qBittorrent to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version%
    echo  Latest version: %latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq qbittorrent.exe" | find /i "qbittorrent.exe" >nul
if not errorlevel 1 (echo. & echo  [!] qBittorrent is running. Please close it to continue. & echo. & pause & goto check_task)

:: download
echo. & echo  Downloading...
curl.exe -RL# "https://sourceforge.net/projects/qbittorrent/files/latest/download" -o "%temp%\qbt_setup.exe"
echo. & echo  Extracting ...
:7z
for /f "tokens=* delims=" %%a in ('where 7z.exe 2^>nul') do set "app=%%a"
if not defined app if exist "C:\Program Files\7-Zip\7z.exe" set "app=C:\Program Files\7-Zip\7z.exe"
if not defined app if exist "%~dp07z.exe" set "app=%~dp07z.exe"
if exist "%app%" goto skip_download
echo. & echo  "7z.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ip7z/7zip/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.msi'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try: winget install 7zip.7zip & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -RL# "%url%" -o "%temp%\%filename%"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
md "%temp%\7z"
if exist "%temp%\%filename%" (msiexec /a "%temp%\%filename%" /qn TARGETDIR="%temp%\7z") else (echo. & echo  %filename% not found. & echo. & pause)
:: finds 7z.exe+7z.dll and move it
for /r "%temp%\7z" %%F in (7z.exe 7z.dll) do (if exist "%%~fF" move /y "%%~fF" "%~dp0" >nul)
rd /s /q "%temp%\7z"
goto 7z

:skip_download
if exist "%temp%\qbt_setup.exe" (7z e "%temp%\qbt_setup.exe" "qbittorrent.exe" -y) else (echo. & echo  qbt_setup.exe not found. & pause)
if not exist "profile" (
    echo. & echo  Creating "profile" folder for Portable mode...
    md "profile"
)
color A & echo. & echo. & echo  DONE. & echo. & pause
