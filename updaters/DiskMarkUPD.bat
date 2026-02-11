:: CrystalDiskMark (X64) UPDATER
::   Alternative to winget
:: by github.com/wincmd64

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
    echo  Latest version: %latest_version%
    echo. & echo  Update? & echo. & pause
)

:check_task
tasklist /fi "imagename eq DiskMark64.exe" | find /i "DiskMark64.exe" >nul
if not errorlevel 1 (echo. & echo  [!] CrystalDiskMark is running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
echo. & echo  Downloading...
curl.exe -RLz "%temp%\cdm.zip" "https://sourceforge.net/projects/crystaldiskmark/files/latest/download" -o "%temp%\cdm.zip" 2>nul
echo. & echo  Extracting ...
if exist "%temp%\cdm.zip" (tar -xf "%temp%\cdm.zip" DiskMark64.exe CdmResource) else (echo. & echo  cdm.zip not found. & pause)
color A & echo. & echo. & echo  DONE. & timeout 5
