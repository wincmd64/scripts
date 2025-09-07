:: Downloads video from link in clipboard using yt-dlp (+ ffmpeg)
:: by github.com/wincmd64

@echo off
:: gets downloads folder path
for /f "delims=" %%a in ('powershell -command "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"
:: gets URL, priority: parameter > clipboard
if "%~1" neq "" (set "url=%~1") else (for /f "delims=" %%i in ('powershell Get-Clipboard') do set "url=%%i")
:: gets yt-dlp path
for /f "tokens=* delims=" %%a in ('where yt-dlp.exe 2^>nul') do set "app=%%a"
if not exist "%app%" (color C & echo. & echo  yt-dlp not found. Try: winget install yt-dlp.yt-dlp & echo. & pause & exit) else (TITLE %app%)
:check
yt-dlp.exe -F -S vext "%url%"
if ERRORLEVEL 1 (
	:: if the url is invalid - enter manually
    echo.
	set /p url=Enter the url: 
	goto check
)
echo.
set num=
set /p num=Enter yt-dlp options or press Enter for best quality: 
echo.
if not defined num (
	:: For video, mp4 > mov > webm > flv. For audio, m4a > aac > mp3 ...
	echo Running: yt-dlp.exe -S "ext" "%url%" -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part
	yt-dlp.exe -S "ext" "%url%" -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part
	if ERRORLEVEL 1 (goto check)
) else (
	:: Example: -f 18 --write-auto-subs --embed-chapters
	echo Running: yt-dlp.exe %num% "%url%" -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part
	yt-dlp.exe %num% "%url%" -P "%DOWNLOADS%" -o "%%(title).50s.%%(ext)s" --no-part
	if ERRORLEVEL 1 (goto check)
)
color A & timeout 2 & explorer "%DOWNLOADS%"
