:: Wrapper for TrID — file identifier utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir

@echo off
setlocal
chcp 1251 >nul

:: [SETTINGS]
set "app=trid.exe"
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

if not defined file_date (echo. & echo  Download TrID CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current file date: %file_date% & echo  Checking for updates...)

:: getting server file date
for /f "tokens=3-5" %%a in ('curl -sI "https://mark0.net/download/trid_win64.zip" ^| findstr /i "Last-Modified"') do (set "server_date=%%a %%b %%c")

:: update logic
if defined file_date (
    echo   Server file date: %server_date%
    echo. & echo  Update? & echo.
    pause
)

:: download and unpack
curl.exe -fRLO# "https://mark0.net/download/trid_win64.zip" --output-dir "%temp%"
if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
tar -xf "%temp%\trid_win64.zip" -C "%temp%"
"%temp%\TrID_setup.exe" /VERYSILENT /DIR="%dir%"
"trid.exe" -u
echo. & echo. & echo  DONE. & echo. & pause

:skip_download
cls
TITLE %app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)

pushd "%~dp1"
(
    for %%i in (%*) do (
        if exist "%%~fi\" (
            rem directory - include only files from the top level
            for %%x in ("%%~fi\*") do @if not exist "%%~fx\" echo %%~fx
        ) else (
            rem file
            @echo %%~fi
        )
    )
) > "%TEMP%\tridlist.txt"
:: add -o "trid.csv" to generate the results in CSV format
"%app_path%" -d "%dir%triddefs.trd" -f "%TEMP%\tridlist.txt"
del "%TEMP%\tridlist.txt"
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\File Identifier.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app_path%'; $s.Save()"
echo. & echo  Shortcut 'File Identifier.lnk' created. & echo. & timeout 2
