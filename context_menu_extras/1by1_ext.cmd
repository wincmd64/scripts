:: Adds "1by1 dir player" entry to the Explorer context menu
::   [area] dirs
:: by github.com/wincmd64

@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

for /f "tokens=* delims=" %%a in ('where 1by1.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp01by1.exe" set "app=%~dp01by1.exe"
if exist "%app%" goto skip_download
echo. & echo  "1by1.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
for /f tokens^=2^ delims^=^" %%a in ('curl -s "https://mpesch3.de/1by1.html" ^| findstr /i "1by1.*\.exe" ^| findstr /v "extra"') do if not defined main set "main=https://mpesch3.de/%%a"
if not defined main (echo  Error: Could not find download URL. & echo  Try manual: https://mpesch3.de/1by1.html & pause & exit /b)
echo. & echo  Downloading... & echo.
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
if exist "%temp%\%mainfile%" (tar -xf "%temp%\%mainfile%" -C "%~dp0." 1by1.exe) else (echo. & echo  %mainfile% not found.)
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
set "app=%~dp01by1.exe"
echo. & echo. & echo  DONE. & echo. & pause

:skip_download
TITLE %app%
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /v "MUIVerb" /d "1by1 dir player" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /v "Icon" /d "%app%" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_1by1\command" /ve /d "\"%app%\" \"%%1\"" /f
color A & timeout 2 & exit

:undo
reg delete "HKCU\Software\Classes\Directory\shell\wincmd64_1by1" /f && (color A & timeout 2) || (echo. & pause)
