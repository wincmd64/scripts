:: Wrapper for Emsisoft CLI Scanner — anti-malware scanning tool
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal

:: [SETTINGS]
set "name=Emsisoft CLI Scanner"
set "app=a2cmd.exe"
set "dir=%~dp0"
cd /d "%dir%"
set "prm=/a /pup /cloud=0"

:download
if exist "%app%" goto skip_download
echo. & echo  Download %name% ^(~300mb^) to "%dir%" ? & echo. & pause
curl.exe -fRLO# "https://dl.emsisoft.com/EmsisoftCommandlineScanner64.exe"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo  Extracting...
EmsisoftCommandlineScanner64.exe -s -o+ -d"%dir%."
del EmsisoftCommandlineScanner64.exe

:skip_download
cls
TITLE %dir%%app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

:: UAC
(Net session >nul 2>&1) && goto :main

set "vbs=%temp%\elevate_%random%.vbs"
> "%vbs%" echo Set sh = CreateObject("Shell.Application")
>>"%vbs%" echo scriptPath = WScript.Arguments.Item(0)
>>"%vbs%" echo args = ""
>>"%vbs%" echo For i = 1 To WScript.Arguments.Count - 1
>>"%vbs%" echo   args = args ^& " " ^& Chr(34) ^& WScript.Arguments.Item(i) ^& Chr(34)
>>"%vbs%" echo Next
>>"%vbs%" echo ' Build the cmd line as: /c "<"scriptPath" arg1 arg2...>"
>>"%vbs%" echo cmdLine = "/c " ^& Chr(34) ^& Chr(34) ^& scriptPath ^& Chr(34) ^& args ^& Chr(34)
>>"%vbs%" echo sh.ShellExecute "cmd.exe", cmdLine, "", "runas", 3
>>"%vbs%" echo WScript.Quit

:: call wscript, first arg = path to this .bat, then all original args
"%windir%\system32\wscript.exe" "%vbs%" "%~f0" %*

del "%vbs%" 2>nul
exit /b

:main
color 07 & cls
set count=0
for %%A in (%*) do set /a count+=1
echo.
if %count% equ 0 (echo  [1] Scan files) else if %count% equ 1 (echo  [1] Scan: %*) else (echo  [1] Scan: %count% objects)
if "%prm%"=="" (echo  [2] Change parameters, current: n\a) else (echo  [2] Change parameters, current: %prm%)
echo  [3] Quick Scan: memory, traces
for /f "delims=" %%A in ('a2cmd.exe /status %1 2^>^&1 ^| findstr /C:"Last Update:"') do set "lastupdate=%%A"
echo  [4] Update signature  --  %lastupdate%
echo  [0] Exit
echo. 
CHOICE /C 12340 /M "Your choice?:" >nul 2>&1
if errorlevel 5 goto exit
if errorlevel 4 goto Option_4
if errorlevel 3 goto Option_3
if errorlevel 2 goto Option_2
if errorlevel 1 goto Option_1
exit

:Option_1
if %count% equ 0 goto SelectFiles
set i=0
set found=0
FOR %%k IN (%*) DO (
    set /a i+=1
    call :processFile %%i%% %count% "%%~fk"
    if errorlevel 1 set found=1
)
if %found%==1 (color C) else (color A)
echo. & echo  [DONE] & echo. & pause & "%~f0"
:processFile
echo. & echo  [%1/%2] a2cmd.exe "%~3" %prm%
"%app%" "%~3" %prm%
exit /b

:SelectFiles
set found=0
set "selected_any="
echo  Opening file selection...
for /f "delims=" %%A in ('powershell -NoP "Add-Type -AssemblyName System.Windows.Forms; $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Title='Select files for Emsisoft Scan'; if($dlg.ShowDialog() -eq 'OK'){ $dlg.FileNames }"') do (
    set "selected_any=1"
    echo. & echo  Scanning: "%%A"
    "%app%" "%%A" %prm%
    if errorlevel 1 set "found=1"
)
if not defined selected_any (goto main)
if %found%==1 (color C) else (color A)
echo. & echo  [DONE] & echo. & pause & goto main

:Option_2
echo  "%app%" %prm%
echo.
set "prm="
set /p prm=Enter new parameters (for example /log=filepath): 
:: findstr /C:"&" but with all "dangerous" symbols
echo("%prm%" | findstr /R "[&|<>%%!^]" >nul
if not errorlevel 1 (
    echo  Forbidden symbols detected!
    set "prm="
    pause
)
if not defined prm (set "prm=")
goto main

:Option_3
echo. & echo  "%app%" /quick %prm%
"%app%" /quick %prm%
pause & goto main

:Option_4
"%app%" /u
echo. & pause & goto main

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\%name%.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%dir%%app%'; $s.Save()"
echo. & echo  Shortcut '%name%.lnk' created. & echo. & timeout 2
