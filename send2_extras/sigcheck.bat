:: Wrapper for SigCheck CLI — check a files status on VirusTotal
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where sigcheck64.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0sigcheck64.exe" set "app=%~dp0sigcheck64.exe"
if not exist "%app%" (
    echo. & echo  "sigcheck64.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    curl.exe "https://live.sysinternals.com/sigcheck64.exe" -RLO# --output-dir "%~dp0."
    if errorlevel 1 (color C & echo. & pause & exit) else (echo. & echo  DONE. & echo. & pause & cls & goto start)
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% objects. & echo.)

echo  1 = -v    query VirusTotal.com based on file hash
echo  2 = -vr   open report for files with non-zero detection
echo  3 = -vs   upload files not previously scanned
echo  4 = -vrs  upload and open reports if detections found
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
