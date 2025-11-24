:: Total Commander x64 downloader
:: by github.com/wincmd64

@echo off
echo. & echo  Loading...

:: get url
for /f tokens^=1-3^ delims^=^" %%i in ('curl.exe --ssl-no-revoke -s "https://www.ghisler.com/download.htm" ^| FINDSTR /IRC:"href=.*tcmd[0-9]*x64\.exe"') do (
    set "file=%%~nxj"
    set "url=%%j"
)
if not defined file (color C & echo. & echo  ERROR: No download link found. & echo. & pause & exit)

:: get downloads folder path
for /f "delims=" %%a in ('powershell -NoP -C "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"
pushd "%DOWNLOADS%"
:: get %commander_path%
if not exist "%commander_path%" set "commander_path=n\a"

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

:Option_1
if not exist "%file%" (
    curl.exe --ssl-no-revoke "%url%" -OR#
    if errorlevel 1 (color C & echo. & echo  ERROR: download failed. & echo. & pause & exit)
    if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /T /A /R="%DOWNLOADS%\%file%") else (explorer /select,"%DOWNLOADS%\%file%")
) else (echo  "%DOWNLOADS%\%file%" already exists.)
echo. & echo  DONE. & timeout 2 & exit

:Option_2
if not exist "%file%" (
    curl.exe --ssl-no-revoke "%url%" -OR#
    if errorlevel 1 (color C & echo. & echo  ERROR: download failed. & echo. & pause & exit)
)
md "totalcmd"
tar -xf "%file%" -C "totalcmd" 2>nul
curl.exe --ssl-no-revoke "https://raw.githubusercontent.com/wincmd64/blog/refs/heads/main/wincmd.ini" -#O --output-dir "totalcmd"
if errorlevel 1 (color C & echo. & echo  ERROR: config download failed. & echo. & pause & exit)
if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /T /A /R="%DOWNLOADS%\totalcmd\TOTALCMD64.EXE") else (explorer /select,"%DOWNLOADS%\totalcmd\TOTALCMD64.EXE")
echo. & echo  DONE. & timeout 2 & exit

:Option_3
if not exist "%file%" (
    curl.exe --ssl-no-revoke "%url%" -OR#
    if errorlevel 1 (color C & echo. & echo  ERROR: download failed. & echo. & pause & exit)
)
"%file%" /I0".\"RSHG0D0 "%COMMANDER_PATH%"
if errorlevel 1 (color C & echo. & echo  ERROR: update failed. & echo. & pause & exit)
echo. & echo  DONE. & echo. & timeout 2
:: pushd "%COMMANDER_PATH%"
:: del *unin* NO.BAR UNRAR64.DLL WCMICONS.DLL WCMICON2.DLL TcUsbRun.exe CGLPT64.SYS *.MANIFEST KEYBOARD.TXT FILTER64\SoundTouchDLL_License.txt
exit
