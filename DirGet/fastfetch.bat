:: Fastfetch UPDATER
:: by github.com/wincmd64

:: Look for fastfetch.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
setlocal

:: [SETTINGS]
set "name=Fastfetch"
set "app=fastfetch.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: get local ver
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item '%app%').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github latest ver
call :github "fastfetch-cli/fastfetch" "*windows-amd64.zip" "https://github.com/fastfetch-cli/fastfetch/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
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
exit

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference = 'SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; if($r -is [array]){$rel=$r[0]}else{$rel=$r}; $a=$rel.assets|?{$_.name -like '%filter%'}|select -f 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
for /f "usebackq tokens=*" %%a in (`powershell -command "%ps_cmd%" 2^>nul`) do (
    if not defined latest_version (
        set "latest_version=%%a"
    ) else if not defined url (
        set "url=%%a"
    ) else if not defined filename (
        set "filename=%%a"
    ) else (
        set "server_date=%%a"
    )
)

:: if PS failed, latest_version will contain error text or be empty
if "%url:~0,4%" NEQ "http" (
    set "url="
    set "latest_version="
    echo.
    echo  Error: Repository "%repo%" not found or API limit reached.
    echo  Try manual: %manual_url%  & echo. & pause
    exit /b
)

echo. & echo  Repo: %repo%
echo   Ver: %latest_version% (%server_date%)
echo  File: %filename%
echo  Link: %url%
echo.
goto :eof