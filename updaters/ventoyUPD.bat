:: VENTOY UPDATER
::   Alternative to winget
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: get local ver
if exist "ventoy\version" set /p ventoy_raw=<"ventoy\version" & call set "current_version=v%%ventoy_raw%%"
if not defined current_version (echo. & echo  Download Ventoy to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ventoy/Ventoy/releases/latest'; $a=$r.assets|?{$_.name -like '*windows.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/ventoy/Ventoy/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq Ventoy2Disk.exe" | find /i "Ventoy2Disk.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] Ventoy is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -RL# "%url%" -o "%temp%\%filename%"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" --strip-components=1 2>nul) else (echo. & echo  %filename% not found. & echo. & pause)

color A & echo. & echo. & echo  DONE. & timeout 5
