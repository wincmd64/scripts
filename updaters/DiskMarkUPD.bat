:: CrystalDiskMark x64 UPDATER
:: by github.com/wincmd64

:: Look for DiskMark64.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

@echo off
cd /d "%~dp0"

:: get local ver
if exist "DiskMark64.exe" (
    echo. & echo  Getting local version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item 'DiskMark64.exe').VersionInfo.ProductVersion.Trim()"') do set "current_version=v%%v"
    echo  Getting latest version...
    for /f %%a in ('powershell -command "$req = [System.Net.WebRequest]::Create('https://sourceforge.net/projects/crystaldiskmark/files/latest/download'); $req.Method = 'HEAD'; $res = $req.GetResponse(); $res.ResponseUri.Segments[4].Trim('/')"') do set "latest_version=%%a"
    cls
)

if not defined current_version (echo. & echo  Download CrystalDiskMark to "%~dp0" ? & echo. & pause
) else (
    echo. & echo  Current version: %current_version%
    echo   Latest version: %latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq DiskMark64.exe" | find /i "DiskMark64.exe" >nul
if not errorlevel 1 (echo. & echo  [!] CrystalDiskMark is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe -fRL# "https://sourceforge.net/projects/crystaldiskmark/files/latest/download" -o "%temp%\cdm.zip" 2>nul
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
echo. & echo  Extracting ...
tar -xf "%temp%\cdm.zip" DiskMark64.exe CdmResource
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (color A & echo. & echo. & echo  DONE. & echo.)

choice /c YN /m "Create desktop shortcut"
if errorlevel 2 goto :eof
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\CrystalDiskMark.lnk'); ^
$s.TargetPath = '%~dp0DiskMark64.exe'; ^
$s.WorkingDirectory = '%~dp0'; ^
$s.IconLocation = '%~dp0DiskMark64.exe'; ^
$s.Save()"
echo. & echo Shortcut 'CrystalDiskMark.lnk' created. & echo. & timeout 3
