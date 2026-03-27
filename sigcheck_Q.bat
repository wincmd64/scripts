:: Wrapper for SigCheck x64 CLI — check a files status on VirusTotal
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir

@echo off
setlocal

:: [SETTINGS]
set "app=sigcheck64.exe"
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

if not defined file_date (echo. & echo  Download SigCheck CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current file date: %file_date% & echo  Checking for updates...)

:: getting server file date
for /f "tokens=3-5" %%a in ('curl -sI "https://live.sysinternals.com/sigcheck64.exe" ^| findstr /i "Last-Modified"') do (set "server_date=%%a %%b %%c")

:: update logic
if defined file_date (
    echo   Server file date: %server_date%
    echo. & echo  Update? & echo.
    pause
)

:: download
curl.exe -fRLO# "https://live.sysinternals.com/sigcheck64.exe"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% objects. & echo.)

echo   [1]  -v    query VirusTotal.com based on file hash
echo   [2]  -vr   open report for files with non-zero detection
echo   [3]  -vs   upload files not previously scanned
echo   [4]  -vrs  upload and open reports if detections found
echo. 
CHOICE /C 1234 /M "Your choice?:" >nul 2>&1
if errorlevel 4 set "flag=-vrs" & goto next
if errorlevel 3 set "flag=-vs" & goto next
if errorlevel 2 set "flag=-vr" & goto next
if errorlevel 1 set  "flag=-v"
:next

TITLE %app% -nobanner -accepteula -vt %flag%
for %%k in (%*) do "%app%" -nobanner -accepteula -vt %flag% "%%~k"
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\VirusTotal.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'imageres.dll,101'; $s.Save()"
echo. & echo  Shortcut 'VirusTotal.lnk' created. & echo. & timeout 2
