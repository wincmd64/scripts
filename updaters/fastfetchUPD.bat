:: Fastfetch UPDATER
:: by github.com/wincmd64

:: Look for fastfetch.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "fastfetch.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'fastfetch.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download Fastfetch to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest'; $a=$r.assets|?{$_.name -like '*windows-amd64.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/fastfetch-cli/fastfetch/releases & pause & exit /b)

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
tar -xf "%temp%\%filename%" fastfetch.exe
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DONE. & timeout 2)

if not exist "fastfetch.jsonc" (
    echo. & echo  Creating fastfetch.jsonc ...
    (
      echo {
      echo   "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      echo   "logo": {
      echo         "source": "windows"
      echo   },
      echo   "modules": [
      echo   {
      echo   "type": "version",
      echo   "key": "fastfetch",
      echo   "keyColor": "red",
      echo   "format": "{version}"
      echo   },
      echo   {
      echo   "type": "title",
      echo   "key": "Host",
      echo   "format": "{2}, {1}",
      echo   "keyColor": "green"
      echo   },
      echo   {
      echo     "type": "os",
      echo     "keyColor": "green"
      echo   },
      echo   {
      echo     "type": "uptime",
      echo     "keyColor": "green"
      echo   },
      echo   {
      echo     "type": "disk",
      echo     "folders": "/",
      echo     "keyColor": "green"
      echo   },
      echo   {
      echo     "type": "bios",
      echo     "key": "BIOS",
      echo     "format": "{type}, {vendor}"
      echo   },
      echo   "TPM",
      echo   "CPU",
      echo   "GPU",
      echo   "PhysicalMemory",
      echo   {
      echo     "type": "PhysicalDisk",
      echo     "temp": true
      echo   },
      echo   {
      echo     "type": "BluetoothRadio",
      echo     "keyColor": "cyan"
      echo   },
      echo   {
      echo     "type": "Bluetooth",
      echo     "keyColor": "cyan"
      echo   },
      echo   {
      echo     "type": "Display",
      echo     "keyColor": "cyan"
      echo   },
      echo   {
      echo     "type": "Wifi",
      echo     "keyColor": "yellow"
      echo   },
      echo   {
      echo     "type": "LocalIp",
      echo     "keyColor": "yellow"
      echo   },
      echo   {
      echo     "type": "dns",
      echo     "keyColor": "yellow"
      echo   },
      echo   {
      echo     "type": "PublicIp",
      echo     "keyColor": "yellow"
      echo   }
      echo   ]
      echo }
    ) > fastfetch.jsonc
)
cls
%comspec% /k fastfetch.exe -c fastfetch.jsonc
