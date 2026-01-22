:: Downloads video from link in clipboard using yt-dlp (+ ffmpeg)
:: by github.com/wincmd64

@echo off
for /f "tokens=* delims=" %%a in ('where yt-dlp.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0yt-dlp.exe" set "app=%~dp0yt-dlp.exe"
if not exist "%app%" (color C & echo. & echo  yt-dlp not found. Try: winget install yt-dlp.yt-dlp & echo. & pause & exit) else (TITLE %app%)
echo. & echo  Loading...

:: get downloads folder path
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v {374DE290-123F-4565-9164-39C4925E467B} 2^>nul') do set "DOWNLOADS=%%B"
:: get URL, priority: parameter > clipboard
if "%~1" neq "" (set "url=%~1") else (for /f "delims=" %%i in ('powershell Get-Clipboard') do set "url=%%i")
:: set default options
set "opt_file=%temp%\yt-dlp-options.log"
if exist "%opt_file%" (set /p num=<"%opt_file%") else (set num=-S "ext")
:: get ver
for /f "delims=" %%A in ('"%app%" --version') do set "lastupdate=%%A"
:main
cls
::: 
:::         _            _ _       
:::   _   _| |_       __| | |_ __  
:::  | | | | __|____ / _` | | '_ \ 
:::  | |_| | ||_____| (_| | | |_) |
:::   \__, |\__|     \__,_|_| .__/ 
:::   |___/                 |_|    
::: 
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%%A

setlocal enabledelayedexpansion
set "display_url=!url!"
:: shorten if a long URL
if "!display_url!"=="" (set "display_url=n\a") else if not "!display_url:~80!"=="" (set "display_url=!url:~0,80!...")
echo   [1] Change URL, current: !display_url!
endlocal
if "%num%"=="" (echo   [2] Change options, current : yt-dlp default) else (echo   [2] Change options, current: %num%)
echo   [3] Change download folder, current: %DOWNLOADS%
echo   [4] Update yt-dlp, current: %lastupdate%
echo   [0] Exit
echo.
echo  Enter = start download
echo.
set userchoice=
set /p userchoice=^> 
if "%userchoice%"=="1" echo. & goto Option_1
if "%userchoice%"=="2" echo. & goto Option_2
if "%userchoice%"=="3" echo. & goto Option_3
if "%userchoice%"=="4" echo. & goto Option_4
if "%userchoice%"=="0" exit /b
if "%userchoice%"==""  echo. & goto start
exit

:Option_1
set "url="
set /p url=Enter new URL: 
if not defined url goto Option_1
echo  Testing...
"%app%" --simulate "%url%"
if ERRORLEVEL 1 (pause & echo. & goto Option_1) else (pause & goto main)

:Option_2
"%app%" -F -S vext "%url%"
if ERRORLEVEL 1 (echo. & echo  Redirecting to Option #1 ... & echo. & goto Option_1)
echo. & echo  Example: -f 18 --write-auto-subs --embed-chapters --mtime
echo  Preset aliases: -t mp3, -t aac, -t mp4, -t mkv & echo.
set "new_num="
set /p new_num=Enter options (type 0 to use default) : 
if "%new_num%"=="0" (
    set "num="
    if exist "%opt_file%" del "%opt_file%"
    goto main
)
if defined new_num (
    set "num=%new_num%"
    (echo %new_num%)>"%opt_file%"
)
goto main

:Option_3
for /f "usebackq delims=" %%A in (`powershell -NoP "(new-object -COM 'Shell.Application').BrowseForFolder(0,'Select download folder',0,0).self.path"`) do set "DOWNLOADS=%%A"
for /f "usebackq" %%B in (`powershell -NoP "Test-Path '%DOWNLOADS%'"`) do if /i "%%B"=="False" (
    echo  Selected folder is not a real filesystem path. & echo.
    for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v {374DE290-123F-4565-9164-39C4925E467B} 2^>nul') do set "DOWNLOADS=%%B"
    pause
)
goto main

:Option_4
"%app%" -U
for /f "delims=" %%A in ('"%app%" --version') do set "lastupdate=%%A"
goto main

:start
echo  Running: "%app%" %num% -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part "%url%" & echo.
"%app%" %num% -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part "%url%"
if ERRORLEVEL 1 (echo. & echo  Redirecting to Option #1 ... & echo. & goto Option_1)
echo. & pause
if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /T /A /R="%DOWNLOADS%") else (explorer "%DOWNLOADS%")
goto main
