:: Total Commander x64 downloader
:: by github.com/wincmd64

@echo off
echo. & echo  Loading...

:: get downloads folder path
for /f "delims=" %%a in ('powershell -NoP -C "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"
pushd "%DOWNLOADS%"
:: get %commander_path%
if not exist "%commander_path%" set "commander_path=n\a"

:: get stable link
for /f tokens^=1-3^ delims^=^" %%i in ('curl.exe -s "https://www.ghisler.com/download.htm" ^| FINDSTR /IRC:"href=.*tcmd[0-9]*x64\.exe"') do (
    set "file=%%~nxj"
    set "url=%%j"
)
if not defined file (color C & echo. & echo  ERROR: No download link found. & echo. & pause & exit)

:: get beta link
set "TARGET_PAGE="
for /f "usebackq tokens=*" %%a in (`powershell -NoP -C "$html = Invoke-WebRequest -Uri 'https://www.ghisler.com/whatsnew.htm' -UseBasicParsing; $link = $html.Links | Where-Object { $_.href -like '*_beta.htm' } | Select-Object -First 1 -ExpandProperty href; if ($link) { if ($link -notlike 'http*') { 'https://www.ghisler.com/' + $link } else { 'https://www.ghisler.com/' + $link.Split('/')[-1] } }"`) do set "TARGET_PAGE=%%a"
if not defined TARGET_PAGE goto :MenuStart
set "beta_url="
for /f "usebackq tokens=*" %%a in (`powershell -NoP -C "$html = Invoke-WebRequest -Uri '%TARGET_PAGE%' -UseBasicParsing; $link = $html.Links | Where-Object { $_.href -like '*x64*.exe' -and $_.href -notlike '*direct*' } | Select-Object -First 1 -ExpandProperty href; if ($link) { if ($link -notlike 'http*') { 'https://www.ghisler.com/' + $link } else { $link } }"`) do set "beta_url=%%a"
if not defined beta_url goto :MenuStart
for %%F in ("%beta_url%") do set "beta_file=%%~nxF"
cls & echo.
echo  [!] New BETA found: %beta_file%
echo.
choice /C YN /M "  --> Use BETA instead of Stable"
if errorlevel 2 goto :MenuStart
set "file=%beta_file%"
set "url=%beta_url%"

:MenuStart
cls
::: 
:::   _____     _        _    ____                                          _           
:::  |_   _|__ | |_ __ _| |  / ___|___  _ __ ___  _ __ ___   __ _ _ __   __| | ___ _ __ 
:::    | |/ _ \| __/ _` | | | |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |/ _ \ '__|
:::    | | (_) | || (_| | | | |__| (_) | | | | | | | | | | | (_| | | | | (_| |  __/ |   
:::    |_|\___/ \__\__,_|_|  \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|\___|_|   
:::                                                                                     
:::
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A

echo  URL: %url%
echo  Download folder: %DOWNLOADS%
echo.
echo   [1] download %file%
echo   [2] download, unpack and apply portable config
echo   [3] update current instalation: "%commander_path%" (admin rights required)
echo.
if "%commander_path%"=="n\a" (
    CHOICE /C 12 /M "Your choice?:" >nul 2>&1
    if errorlevel 2 goto Option_2
    if errorlevel 1 goto Option_1
) else (
    CHOICE /C 123 /M "Your choice?:" >nul 2>&1
    if errorlevel 3 goto Option_3
    if errorlevel 2 goto Option_2
    if errorlevel 1 goto Option_1
)
exit

:Download
if not exist "%file%" (
    echo  Downloading %file%...
    curl.exe "%url%" -RLO#
    if errorlevel 1 (color C & echo. & echo  ERROR: download failed. & echo. & pause & exit)
) else (echo  "%file%" already exists, skipping download.)
goto :eof

:Option_1
call :Download
echo. & echo  DONE. & timeout 2
if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /A /R="%DOWNLOADS%\%file%") else (explorer /select,"%DOWNLOADS%\%file%")
exit

:Option_2
call :Download
md "totalcmd"
tar -xf "%file%" -C "totalcmd" 2>nul
curl.exe "https://raw.githubusercontent.com/wincmd64/blog/refs/heads/main/wincmd.ini" -#O --output-dir "totalcmd"
if errorlevel 1 (color C & echo. & echo  ERROR: config download failed. & echo. & pause & exit)
echo. & echo  DONE. & timeout 2
if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /A /R="%DOWNLOADS%\totalcmd\TOTALCMD64.EXE") else (explorer /select,"%DOWNLOADS%\totalcmd\TOTALCMD64.EXE")
exit

:Option_3
call :Download
"%file%" /I0".\"RSHG0D0 "%COMMANDER_PATH%"
if errorlevel 1 (color C & echo. & echo  ERROR: update failed. & echo. & pause & exit)
echo. & echo  DONE. & echo. & timeout 2
:: pushd "%COMMANDER_PATH%"
:: del *unin* NO.BAR UNRAR64.DLL WCMICONS.DLL WCMICON2.DLL TcUsbRun.exe CGLPT64.SYS *.MANIFEST KEYBOARD.TXT FILTER64\SoundTouchDLL_License.txt
exit
