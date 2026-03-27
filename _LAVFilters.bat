:: LAV Filters x64 UPDATER
:: by github.com/wincmd64

:: Look for LAVAudio.ax in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "dir=%COMMANDER_PATH%\FILTER64"
cd /d "%dir%"

if exist "LAVAudio.ax" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'LAVAudio.ax').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download LAV Filters ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/nevcairiel/lavfilters/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/nevcairiel/lavfilters/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%" *.ax *.dll *.manifest
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DONE. & echo.)
timeout 3