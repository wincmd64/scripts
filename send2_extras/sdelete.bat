:: Wrapper for SDelete — secure delete utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where sdelete64.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0sdelete64.exe" set "app=%~dp0sdelete64.exe"
if not exist "%app%" (
    echo. & echo  "sdelete64.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
    curl.exe "https://live.sysinternals.com/sdelete64.exe" -RLO# --output-dir "%~dp0."
    if errorlevel 1 (color C & echo. & pause & exit) else (echo. & echo  DONE. & echo. & pause & cls & goto start)
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

:: file counts
setlocal enabledelayedexpansion
set count=0
set shown=0
echo. & echo  Selected for secure deletion:
for %%A in (%*) do set /a count+=1
for %%A in (%*) do (
    set /a shown+=1
    if !shown! LEQ 5 (
        echo    %%~A
    )
)
:: >5
if %count% GTR 5 (
    set /a remaining=%count%-5
    call echo    ... and %%remaining%% more
)
if %count% equ 0 (echo. & echo    ^(no objects selected^) & echo. & pause & exit)

:: confirm
endlocal
echo.
set /p confirm="> WARNING: This will permanently erase the selected object(s). Continue? [Y/N]: "
if /i not "%confirm%"=="Y" (echo. & echo  Operation cancelled. & echo. & pause & exit)
FOR %%k IN (%*) DO (echo. & "%app%" -nobanner -accepteula -s "%%~k")
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Secure Delete.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'imageres.dll,-5320'; $s.Save()"
echo. & echo  Shortcut 'Secure Delete.lnk' created. & echo. & timeout 2
