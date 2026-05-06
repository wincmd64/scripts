:: File uploader
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal
chcp 65001 >nul

:: [SETTINGS] User pixeldrain API Key
set "PD_KEY_FILE=%AppData%\pixeldrain"
set "PIXELDRAIN_KEY="
if exist "%PD_KEY_FILE%" set /p PIXELDRAIN_KEY=<"%PD_KEY_FILE%"

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

:menu
cls
set "keys=123"
set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% files. & echo.)
echo  [1] litterbox.catbox.moe -- 1 GB, 3 days
echo  [2] x0.at -- 1 GB, 3 days min
echo  [3] transfer.whalebone.io -- 250 MB, 7 days
if not defined PIXELDRAIN_KEY (echo  %ESC%[90m[4] pixeldrain.com -- 10 GB, 60 days -- API Key missing%ESC%[0m) else (echo  [4] pixeldrain.com -- 10 GB, 60 days & set "keys=1234")
echo.
CHOICE /C %keys% /M "Your choice?:" >nul 2>&1
set "err=%errorlevel%"
if %err% equ 4 (
    if not defined PIXELDRAIN_KEY (echo. & echo  Error: Pixeldrain key missing! & echo. & pause & goto menu)
    set "service=pixeldrain"
) else if %err% equ 3 (set "service=whalebone") else if %err% equ 2 (set "service=x0") else (set "service=litterbox")
TITLE Uploading to %service%

set "current=0"
FOR %%k IN (%*) DO (
    set /a current+=1
    call :upload "%%~k"
)

echo  %ESC%[7m%count% TASK^(S^) FINISHED%ESC%[0m & echo. & pause & exit
exit

:upload
set "LNK="
echo  [%current%/%count%] FILE: "%~nx1"

if /i "%service%"=="litterbox" (
    for /f "delims=" %%i in ('curl -# -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@%~1" https://litterbox.catbox.moe/resources/internals/api.php') do set "LNK=%%i"
) else if /i "%service%"=="x0" (
    for /f "delims=" %%i in ('curl -# -F "file=@%~1" https://x0.at') do set "LNK=%%i"
) else if /i "%service%"=="whalebone" (
    for /f "delims=" %%i in ('curl -# --upload-file "%~1" https://transfer.whalebone.io') do set "LNK=%%i"
) else if /i "%service%"=="pixeldrain" (
    for /f "delims=" %%i in ('curl -u :%PIXELDRAIN_KEY% -#T "%~1" https://pixeldrain.com/api/file/ ^| powershell -NoP -C "($input | ConvertFrom-Json).id"') do set "LNK=https://pixeldrain.com/u/%%i"
)

if defined LNK (
    call echo  Link: %ESC%[36m%%LNK%%%ESC%[0m
    :: copy to clipboard if only one link
    if %count% equ 1 (call echo | set /p="%%LNK%%" | clip)
) else (echo  %ESC%[91mError: Failed to upload %%~nxk%ESC%[0m)

:: MD5 hash
for /f "tokens=*" %%i in ('certutil -hashfile "%~1" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do echo   MD5: %%i
echo.
goto :eof


:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\File Hoster.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,130'; $s.Save()"
echo. & echo  Shortcut created in 'SendTo'. & echo. & timeout 3