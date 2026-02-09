:: 0x0.st batch uploader
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
TITLE Temporary file hoster

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (
    echo. & echo File: %*
    for /f "delims=" %%i in ('curl -# -F "file=@%~1" https://0x0.st') do (
        echo Link: %%i
        echo %%i | clip
    )
    for /f "tokens=*" %%i in ('certutil -hashfile "%~1" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do (echo  MD5: %%i)
    echo. & echo  Link copied to clipboard. & echo. & pause
) else (
    echo. & echo  Upload %count% files? & echo. & pause
    FOR %%k IN (%*) DO (
        echo. & echo FILE: %%k
            for /f "delims=" %%i in ('curl -# -F "file=@%%~k" https://0x0.st') do (echo Link: %%i)
            for /f "tokens=*" %%i in ('certutil -hashfile "%%~k" MD5 ^| find /v "MD5" ^| find /v "CertUtil"') do (echo  MD5: %%i)
    )
    echo. & echo  DONE. & echo. & pause
)
exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Temp hoster.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,130'; $s.Save()"
echo. & echo  Shortcut 'Temp hoster.lnk' created. & echo. & timeout 2