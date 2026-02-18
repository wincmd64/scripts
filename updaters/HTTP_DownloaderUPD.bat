:: HTTP Downloader UPDATER
::   Alternative to winget
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: get local ver
if exist "HTTP_Downloader.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'HTTP_Downloader.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download HTTP Downloader to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/erickutcher/httpdownloader/releases/latest'; $a=$r.assets|?{$_.name -like '*64.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/erickutcher/httpdownloader/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq HTTP_Downloader.exe" | find /i "HTTP_Downloader.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] HTTP Downloader is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -RL# "%url%" -o "%temp%\%filename%"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" 2>nul) else (echo. & echo  %filename% not found. & echo. & pause)

color A & echo. & echo. & echo  DONE. & timeout 5
