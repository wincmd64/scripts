:: Temporary file hoster
:: by github.com/wincmd64

::  Change service in [SETTINGS] below
::    litterbox.catbox.moe -- 1 GB, 3 days
::    x0.at -- 1 GB, 3 days min
::    transfer.whalebone.io -- 250 MB, 7 days

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
:: Service options: litterbox / x0 / whalebone
set "service=litterbox"

TITLE Temporary file hoster: %service%

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)

if %count% equ 1 (
    echo. & echo  File: %1
    if /i "%service%"=="litterbox" (
        for /f "delims=" %%i in ('curl -# -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@%~1" https://litterbox.catbox.moe/resources/internals/api.php') do (set "LNK=%%i")
    ) else if /i "%service%"=="x0" (
        for /f "delims=" %%i in ('curl -# -F "file=@%~1" https://x0.at') do (set "LNK=%%i")
    ) else if /i "%service%"=="whalebone" (
        for /f "delims=" %%i in ('curl -# --upload-file "%~1" https://transfer.whalebone.io') do (set "LNK=%%i")
    )
    if not defined LNK (echo  Error: Failed to get link. & exit /b)
    call echo  Link: %ESC%[36m%%LNK%%%ESC%[0m
    call echo | set /p="%%LNK%%" | clip
    for /f "tokens=*" %%i in ('certutil -hashfile "%~1" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do (echo   MD5: %%i)
    echo. & echo  Link copied to clipboard. & echo. & pause
) else (
    echo. & echo  Upload %count% files? & echo. & pause
    FOR %%k IN (%*) DO (
        echo. & echo  FILE: %%k
        if /i "%service%"=="litterbox" (
            for /f "delims=" %%i in ('curl -# -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@%%~k" https://litterbox.catbox.moe/resources/internals/api.php') do (echo  Link: %ESC%[36m%%i%ESC%[0m)
        ) else if /i "%service%"=="x0" (
            for /f "delims=" %%i in ('curl -# -F "file=@%%~k" https://x0.at') do (echo  Link: %ESC%[36m%%i%ESC%[0m)
        ) else if /i "%service%"=="whalebone" (
            for /f "delims=" %%i in ('curl -# --upload-file "%%~k" https://transfer.whalebone.io') do (echo  Link: %ESC%[36m%%i%ESC%[0m)
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