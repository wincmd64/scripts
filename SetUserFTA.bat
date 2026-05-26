:: Association Manager
:: by github.com/wincmd64

:: Batch registers and maps file extensions to specific target applications 
:: by parsing an accompanying, mandatory '%~n0.ini' configuration list 
:: to dynamically apply paths, extensions, and custom icons.


@echo off
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs & Exit /B)

:: ini
set "INI_FILE=%~n0.ini"
if not exist "%INI_FILE%" (echo. & echo  [ERROR] Configuration file %INI_FILE% not found! & echo. & pause & exit /b)

:: get SetUserFTA.exe
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "FTA=%%a"
if not defined FTA if exist "%temp%SetUserFTA.exe" set "FTA=%temp%SetUserFTA.exe"
if not exist "%FTA%" (
    echo. & echo  SetUserFTA.exe required. Try to download it to TEMP ? & echo. & pause
    curl.exe -fRLO# "https://setuserfta.com/SetUserFTA.zip" --output-dir "%temp%"
    if errorlevel 1 (color C & echo. & echo  [ERROR] download failed. & echo  Try manual: https://setuserfta.com/SetUserFTA.zip & echo. & pause & exit /b)
    tar -xf "%temp%\SetUserFTA.zip" -C "%temp%"
    if errorlevel 1 (echo. & echo  [ERROR] extraction failed. & echo. & pause)
    set "FTA=%temp%\SetUserFTA.exe"
    echo.
)

set "TOTAL_LINES=0"
for /f %%i in ('findstr /v /r "^#" "%INI_FILE%" ^| findstr /r "." ^| find /c /v ""') do set "TOTAL_LINES=%%i"
echo. & echo  Apply %TOTAL_LINES% file associations? & echo. & pause
:: Read .ini line by line ignores lines starting with a #
:: tokens=1-4 delims=; splits line by semicolon
for /f "usebackq eol=# tokens=1-4 delims=;" %%a in ("%INI_FILE%") do (
    call :process "%%a" "%%b" "%%c" "%%d"
)
echo. & echo  DONE. & pause & exit

:process
:: Get EXE filename without extension to use as ProgID base (e.g., mpc-hc64)
for %%i in (%1) do set "APP_NAME=%%~ni"

set "ICON_PATH=%~3"
set "ICON_INDEX=%~4"

:: Handle shifted arguments when ;; syntax leaves %4 empty but puts index into %3
if "[%~4]"=="[]" (
    if not "[%~3]"=="[]" (
        :: Check if %3 is a pure number (icon index) without spaces
        echo %~3| findstr /r "^[0-9][0-9]*$" >nul
        if not errorlevel 1 (
            set "ICON_INDEX=%~3"
            set "ICON_PATH="
        )
    )
)

:: Apply defaults if paths/indices are still empty
if "%ICON_PATH%"=="" set "ICON_PATH=%~1"
if "%ICON_INDEX%"=="" set "ICON_INDEX=0"

:: Register association using the dynamic ProgID
assoc .%~2=%APP_NAME%_%~2
ftype %APP_NAME%_%~2=%1 "%%1"

:: Apply SetUserFTA fix
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%FTA%" .%~2 %APP_NAME%_%~2

:: Set default icon
reg add "HKCU\Software\Classes\%APP_NAME%_%~2\DefaultIcon" /ve /d "%ICON_PATH%,%ICON_INDEX%" /f >nul
goto :eof
