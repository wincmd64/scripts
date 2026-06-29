:: Wrapper for SigCheck x64 CLI — check a files status on VirusTotal
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal

:: [SETTINGS]
set "name=SigCheck CLI"
set "app=sigcheck64.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: /s arg
if exist "%app%" if /i "%~1"=="/s" goto shortcut

:download
if not exist "%app%" (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    curl.exe -fRLO# "https://live.sysinternals.com/sigcheck64.exe"
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%

set count=0
for %%A in (%*) do set /a count+=1
:: active processes VT check
if %count% equ 0 (
    echo. & echo  No objects selected. Scan all running processes with VirusTotal instead ? & echo. & pause
    powershell -NoP -C "Get-Process | Where-Object {$_.Path} | Select-Object -ExpandProperty Path -Unique" > "%TEMP%\paths.txt"
    (
        for /f "usebackq delims=" %%A in ("%TEMP%\paths.txt") do (
            echo   %%~A >con
            @"%app%" -nobanner -accepteula -vt -v "%%~A"
        )
    ) > "%TEMP%\vt_process_check.txt" 2>&1
    del "%TEMP%\paths.txt"
    echo. & echo  DONE. See "%TEMP%\vt_process_check.txt"
    timeout /t 2 >nul
    explorer /select,"%TEMP%\vt_process_check.txt"
    timeout 3 & exit
)
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
