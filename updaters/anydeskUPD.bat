:: AnyDesk UPDATER
:: by github.com/wincmd64

:: Look for AnyDesk.exe in the script directory.
:: Always request the latest version from the official server and update if a new one is available.

@echo off
cd /d "%~dp0"

if exist "AnyDesk.exe" (for %%i in ("AnyDesk.exe") do set "old_date=%%~ti") else (set "old_date=none")
:check_task
tasklist /fi "imagename eq AnyDesk.exe" | find /i "AnyDesk.exe" >nul
if not errorlevel 1 (echo. & echo  [!] AnyDesk is running. Please close it to continue. & echo. & pause & goto check_task)
curl -fLR#z "AnyDesk.exe" -O "https://download.anydesk.com/AnyDesk.exe"
if errorlevel 1 (color C & echo. & echo  Error: download failed. Try manual: https://download.anydesk.com/AnyDesk.exe & echo. & pause)
for %%i in ("AnyDesk.exe") do set "new_date=%%~ti"
if "%old_date%"=="%new_date%" (echo. & echo  Up to date.) else (color A & echo. & echo  Updated successfully! & timeout 2)
start "" "AnyDesk.exe"
pause