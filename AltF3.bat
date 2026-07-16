:: Using in wincmd.ini like:
::   [Configuration]
::   Viewer=""%commander_path%\Utils\nircmd.exe" exec hide "%commander_path%\Utils\AltF3.bat" "%1""

@echo off
setlocal
if "%~1"=="" (echo. & echo  File path is missing. & echo. & pause & exit /b)

:: nircmd.exe required
set "nircmd=%commander_path%\Utils\nircmd.exe"
:: what to look for in 3) PATH
for %%i in (mp3DirectCut.exe gfie.exe csvlens.exe wordpad.exe MailView.exe Compil32.exe fmp.exe notepad++.exe) do (where %%i >nul 2>&1 && set "%%~ni=%%i")

:: wordpad verification (win11)
if defined wordpad goto skip_wordpad
for /f "tokens=3,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wordpad.exe" /ve 2^>nul') do call set "wordpad=%%B"
:skip_wordpad

:: 1) SYSTEM
if /i "%~x1"==".ps1" "%nircmd%" exec show PowerShell_ISE.exe "%~1" & goto :eof
echo "%~x1" | findstr /i ".bmp .dib .jpg .jpeg .jpe .jfif .gif .tif .tiff .png .heic .hif .avif .webp .paint" >nul && ("%nircmd%" exec show mspaint "%~1" & goto :eof)
echo "%~x1" | findstr /i ".txt .md" >nul && ("%nircmd%" exec show notepad "%~1" & goto :eof)
:: 2) %COMMANDER_PATH%
if exist "%~1\" "%nircmd%" exec show "%COMMANDER_EXE%" /S=L:Pvisualspace "%~1" & goto :eof
echo "%~x1" | findstr /i ".vhd .vhdx" >nul && ("%nircmd%" exec show "%commander_path%\Plugins\Total7zip\7-ZipPort\7-ZipPortable.exe" "%~1" & goto :eof)
if /i "%~x1"==".msi" "%nircmd%" exec show powershell.exe -NoP -NoE -Ep Bypass -File "%commander_path%\Utils\MsiViewer.ps1" "%~1" & goto :eof
:: 3) PATH
echo "%~x1" | findstr /i ".mp3 .cue" >nul && (if defined mp3DirectCut ("%nircmd%" exec show %mp3DirectCut% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://mpesch3.de" & exit /b)
echo "%~x1" | findstr /i ".dll .ico" >nul && (if defined gfie ("%nircmd%" exec show %gfie% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://greenfishsoftware.org" & exit /b)
if /i "%~x1"==".csv" if defined csvlens ("%nircmd%" exec show %csvlens% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://github.com/ys-l/csvlens" & exit /b
if /i "%~x1"==".rtf" if defined wordpad ("%nircmd%" exec show %wordpad% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://github.com/wincmd64/blog/wiki/Как-вернуть-WordPad-в-Windows-11" & exit /b
if /i "%~x1"==".eml" if defined MailView ("%nircmd%" exec show %MailView% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://www.mitec.cz/mailview.html" & exit /b
if /i "%~x1"==".iss" if defined Compil32 ("%nircmd%" exec show %Compil32% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://jrsoftware.org/isdl.php" & exit /b
if /i "%~x1"==".swf" if defined fmp ("%nircmd%" exec show %fmp% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://www.eolsoft.com/freeware/flash_movie_player" & exit /b
if /i "%~x1"==".log" if defined notepad++ ("%nircmd%" exec show %notepad++% "%~1" & goto :eof) else "%nircmd%" qboxtop "Associated program for %~x1 not found in PATH.~nOpen the website to download it?" "Error" "%nircmd%" shexec "open" "https://notepad-plus-plus.org/news" & exit /b
:: 4) FALLBACK
"%nircmd%" exec show "%COMMANDER_EXE%" /S=L "%~1" & exit /b
