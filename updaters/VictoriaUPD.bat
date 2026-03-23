:: Victoria UPDATER
:: by github.com/wincmd64

:: Look for Victoria.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "Victoria.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'Victoria.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download Victoria to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:getURL
for /f tokens^=2^ delims^=^" %%i in ('curl.exe -s -k -L -A "Mozilla/5.0" "https://hdd.by/victoria/" ^| findstr /i "kcc_link" ^| findstr /i "Victoria.*\.zip"') do set "L=%%i"
if not defined L (echo. & echo  Error: Could not find download URL. Try manual: https://hdd.by/victoria & echo. & pause & goto getURL)
set "L=%L:&#038;=&%"
for %%f in ("%L:/=" "%") do set "N=%%~f"

:: update logic
if defined current_version (
    echo   Latest version: %N%
    echo. & echo  Update? & echo. 
    pause
)
:check_task
tasklist /fi "imagename eq Victoria.exe" | find /i "Victoria.exe" >nul
if not errorlevel 1 (echo. & echo  [!] Victoria is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
if not exist "%temp%\%N%" (
    echo. & echo  Downloading: %N%
    curl.exe -fL# -A "Mozilla/5.0" -e "https://hdd.by/victoria/" -o "%temp%\%N%" "%L%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %N% ^(already in TEMP^)
)
echo. & echo  Extracting ...
tar -xf "%temp%\%N%" --strip-components=1 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DONE. & echo.)
start "" /b powershell -windowstyle hidden -C "Start-Process 'Victoria.exe' -Verb RunAs"