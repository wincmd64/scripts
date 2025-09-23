:: Downloads video from link in clipboard using yt-dlp (+ ffmpeg)
:: by github.com/wincmd64

@echo off
for /f "tokens=* delims=" %%a in ('where yt-dlp.exe 2^>nul') do set "app=%%a"
if not exist "%app%" (color C & echo. & echo  yt-dlp not found. Try: winget install yt-dlp.yt-dlp & echo. & pause & exit) else (TITLE %app%)
:: gets downloads folder path
for /f "delims=" %%a in ('powershell -command "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"
:: gets URL, priority: parameter > clipboard
if "%~1" neq "" (set "url=%~1") else (for /f "delims=" %%i in ('powershell Get-Clipboard') do set "url=%%i")
:check
yt-dlp.exe -F -S vext "%url%"
if ERRORLEVEL 1 (
	:: if the url is invalid - enter manually
    echo.
	set /p url=Enter the url: 
	goto check
)
echo.
:: user options, leave empty for default
set num=-S "ext"
echo Enter yt-dlp options (like: -f 18 --write-auto-subs --embed-chapters)
set /p num=or press Enter for defined %num%: 
echo. & echo Running: "%app%" %num% -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part "%url%"
"%app%" %num% -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part "%url%"
if ERRORLEVEL 1 (goto check)
color A & pause
if exist "%COMMANDER_EXE%" ("%COMMANDER_EXE%" /O /S /T /A /R="%DOWNLOADS%") else (explorer "%DOWNLOADS%")
