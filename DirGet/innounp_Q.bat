:: Wrapper for InnoUnp CLI — Inno Setup unpacker
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%N parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir

@echo off
setlocal

:: [SETTINGS]
set "app=innounp.exe"
set "dir=%~dp0"
set "app_path=%dir%%app%"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local file date
if exist "%app%" (
    echo. & echo  Getting local file date...
    for /f "tokens=*" %%d in ('powershell -C "(Get-Item '%app%').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    cls
)

if not defined file_date (echo. & echo  Download InnoUnp CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current file date: %file_date% & echo  Checking for updates...)

:: getting server file date
for /f "tokens=3-5" %%a in ('curl -sI "https://www.rathlev-home.de/tools/download/innounp-2.zip" ^| findstr /i "Last-Modified"') do (set "server_date=%%a %%b %%c")

:: update logic
if defined file_date (
    echo   Server file date: %server_date%
    echo. & echo  Update? & echo.
    pause
)

:: download and unpack
curl.exe -fRLO# "https://www.rathlev-home.de/tools/download/innounp-2.zip" --output-dir "%temp%"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
tar -xf "%temp%\innounp-2.zip" innounp.exe
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

if "%~1"=="" (echo. & echo  No objects selected & echo. & pause & exit)
"%app%" "%~1" >nul 2>&1
if errorlevel 1 ("%app%" "%~1" & echo. & pause & exit)
"%app%" -x -d"%~dpn1_unpacked" "%~1"
if errorlevel 1 (echo. & pause & exit) else (if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /T "%~dpn1_unpacked") else (explorer "%~dpn1_unpacked"))
color A & timeout 2 & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\InnoUnpacker.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app_path%'; $s.Save()"
echo. & echo  Shortcut 'InnoUnpacker.lnk' created. & echo. & timeout 2