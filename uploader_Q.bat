:: Temporary file hoster
::  Change "litterbox" to "0x0" in [SETTINGS] below if you want to use 0x0.st service
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

:: [SETTINGS]
:: Service: litterbox / 0x0
set "service=litterbox"
:: Lifetime for Litterbox: 1h, 12h, 24h, 72h
set "lifetime=72h"
TITLE Temporary file hoster: %service%

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (
    echo. & echo  File: %1
    if /i "%service%"=="litterbox" (
        for /f "delims=" %%i in ('curl -# -F "reqtype=fileupload" -F "time=%lifetime%" -F "fileToUpload=@%~1" https://litterbox.catbox.moe/resources/internals/api.php') do (set "LNK=%%i")
    ) else (
        for /f "delims=" %%i in ('curl -# -F "file=@%~1" https://0x0.st') do (set "LNK=%%i")
    )
    call echo  Link: %ESC%[36m%%LNK%%%ESC%[0m
    call echo | set /p="%%LNK%%" | clip
    for /f "tokens=*" %%i in ('certutil -hashfile "%~1" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do (echo   MD5: %%i)
    echo. & echo  Link copied to clipboard. & echo. & pause
) else (
    echo. & echo  Upload %count% files? & echo. & pause
    FOR %%k IN (%*) DO (
        echo. & echo  FILE: %%k
        if /i "%service%"=="litterbox" (
            for /f "delims=" %%i in ('curl -# -F "reqtype=fileupload" -F "time=%lifetime%" -F "fileToUpload=@%%~k" https://litterbox.catbox.moe/resources/internals/api.php') do (echo  Link: %ESC%[36m%%i%ESC%[0m)
        ) else (
            for /f "delims=" %%i in ('curl -# -F "file=@%%~k" https://0x0.st') do (echo  Link:%ESC%[36m %%i%ESC%[0m)
        )
        for /f "tokens=*" %%i in ('certutil -hashfile "%%~k" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do (echo   MD5: %%i)
    )
    echo. & echo. & echo  %ESC%[7mUPLOADS FINISHED%ESC%[0m & echo. & pause
)
exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\File Hoster.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,130'; $s.Save()"
echo. & echo  Shortcut created in 'SendTo'. & echo. & timeout 3