:: 1by1 UPDATER
:: by github.com/wincmd64

:: Look for 1by1.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: [COMMAND LINE ARGUMENTS]
:: /i - add 1by1 to folder context menu
:: /u - remove 1by1 from context menu

@ECHO OFF
setlocal

:: [SETTINGS]
set "name=1by1"
set "app=1by1.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if /i "%~1" EQU "/i" (goto add_menu)
if exist "%app%" if /i "%~1" EQU "/u" (goto del_menu)

:: get local file date
if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "(Get-Item '%app%').VersionInfo.ProductVersion.Trim()"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: get server ver
for /f "tokens=2 delims= " %%v in ('curl -s "https://mpesch3.de/1by1.html" ^| findstr /i /c:"Version "') do (
    set "version=%%v"
    goto :done
)
:done
set "latest_version=%version:</h3>=%"

:: update logic
if defined current_version (
    echo  Latest version:  v%latest_version%
    echo. & echo  Update? & echo.
    pause
)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% is running. Please close it to continue. & echo. & pause & goto check_task)

:download
echo. & echo  Downloading... & echo.
for /f tokens^=2^ delims^=^" %%a in ('curl -s "https://mpesch3.de/1by1.html" ^| findstr /i "1by1.*\.exe" ^| findstr /v "extra"') do if not defined main set "main=https://mpesch3.de/%%a"
if not defined main (echo  Error: Could not find download URL. & echo  Try manual: https://mpesch3.de/1by1.html & pause & exit /b)
:: BASS
for /f tokens^=2^ delims^=^" %%a in ('curl -s "https://www.un4seen.com/bass.html" ^| findstr /irc:"files/bass[0-9]*\.zip"') do set "BASS_URL=https://www.un4seen.com/%%a"
for /f tokens^=2^ delims^=^" %%a in ('curl -s "https://www.un4seen.com/bass.html" ^| findstr /irc:"files/bassflac[0-9]*\.zip"') do set "FLAC_URL=https://www.un4seen.com/%%a"
for /f tokens^=2^ delims^=^" %%a in ('curl -s "https://www.un4seen.com/bass.html" ^| findstr /irc:"files/bassape[0-9]*\.zip"') do set "APE_URL=https://www.un4seen.com/%%a"
for %%A in ("%BASS_URL%") do set "bassfile=%%~nxA"
for %%A in ("%FLAC_URL%") do set "flacfile=%%~nxA"
for %%A in ("%APE_URL%") do set "apefile=%%~nxA"
for %%A in ("%main%") do set "mainfile=%%~nxA"
:: download
curl.exe "%main%" -RLO# --output-dir "%temp%" && (echo  %mainfile%) || (echo. & echo %mainfile% -- DOWNLOAD FAILED.)
curl.exe "%BASS_URL%" -RLO# --output-dir "%temp%" && (echo  %bassfile%) || (echo. & echo %bassfile% -- DOWNLOAD FAILED.)
curl.exe "%FLAC_URL%" -RLO# --output-dir "%temp%" && (echo  %flacfile%) || (echo. & echo %flacfile% -- DOWNLOAD FAILED.)
curl.exe "%APE_URL%" -RLO# --output-dir "%temp%" && (echo  %apefile%) || (echo. & echo %apefile% -- DOWNLOAD FAILED.)
echo. & echo  Extracting ...
if exist "%temp%\%mainfile%" (tar -xf "%temp%\%mainfile%" -C "%~dp0." 1by1.exe lanRU.ini lanUA.ini) else (echo. & echo  %mainfile% not found.)
if exist "%temp%\%bassfile%" (tar -xf "%temp%\%bassfile%" -C "%~dp0." bass.dll) else (echo. & echo  %bassfile% not found.)
if exist "%temp%\%flacfile%" (tar -xf "%temp%\%flacfile%" -C "%~dp0." bassflac.dll) else (echo. & echo  %flacfile% not found.)
if exist "%temp%\%apefile%" (tar -xf "%temp%\%apefile%" -C "%~dp0." bassape.dll) else (echo. & echo  %apefile% not found.)
if not exist "1by1.ini" (
    echo. & echo  Creating ini ...
    (
        echo [1by1]
        echo big_t_time=0
        echo picture=00278,*.jpg
        echo hotkeys=5
        echo list_style=176
    )>"1by1.ini"
)
color A & echo. & echo  DONE. & timeout 3 & exit

:add_menu
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /v "MUIVerb" /d "1by1 player" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /v "Icon" /d "%dir%%app%" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1\command" /ve /d "\"%dir%%app%\" \"%%1\"" /f && (color A & timeout 3 & exit) || (echo. & pause & exit)

:del_menu
reg delete "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /f && (color A & timeout 2) || (echo. & pause)
