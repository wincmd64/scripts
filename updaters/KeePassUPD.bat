:: KeePass 2x UPDATER
:: by github.com/wincmd64

:: Look for KeePass.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "KeePass.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'KeePass.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
)

echo. & echo  Getting latest version...
for /f %%a in ('powershell -command "$req = [System.Net.HttpWebRequest]::Create('https://sourceforge.net/projects/keepass/files/latest/download'); $req.AllowAutoRedirect = $true; $res = $req.GetResponse(); $finalUrl = $res.ResponseUri.ToString(); if ($finalUrl -match 'KeePass-([\d\.]+)\.zip') { $matches[1] }"') do (
    set "latest_version=%%a"
    set "download_url=https://sourceforge.net/projects/keepass/files/KeePass%%202.x/%%a/KeePass-%%a.zip/download"
)
cls

if not defined current_version (echo. & echo  Download KeePass to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: v%current_version%
    echo  Latest version: v%latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq KeePass.exe" | find /i "KeePass.exe" >nul
if not errorlevel 1 (echo. & echo  [!] KeePass is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading: %download_url%
curl.exe -RL# "%download_url%" -o "%temp%\kpass.zip"
curl.exe -RLO# "https://downloads.sourceforge.net/keepass/KeePass-%latest_version%-Russian.zip" --output-dir "%temp%"
echo. & echo  Extracting ...
if exist "%temp%\kpass.zip" (tar -xf "%temp%\kpass.zip" 2>nul) else (echo. & echo  kpass.zip not found. & pause)
if exist "%temp%\KeePass-%latest_version%-Russian.zip" tar -xf "%temp%\KeePass-%latest_version%-Russian.zip" -C "Languages" 2>nul
color A & echo. & echo. & echo  DONE. & echo.

choice /c YN /m "Create desktop shortcut"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\KeePass.lnk'); ^
$s.TargetPath = '%~dp0KeePass.exe'; ^
$s.WorkingDirectory = '%~dp0'; ^
$s.IconLocation = '%~dp0KeePass.exe'; ^
$s.Save()"
echo. & echo Shortcut 'KeePass.lnk' created. & echo. & timeout 3
