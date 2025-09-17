:: Wrapper for Emsisoft CLI Scanner — anti-malware scanning tool
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
for /f "tokens=* delims=" %%a in ('where a2cmd.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0a2cmd.exe" set "app=%~dp0a2cmd.exe"
if not exist "%app%" (echo. & echo  "a2cmd.exe" not found. & echo  Download it from: https://dl.emsisoft.com/EmsisoftCommandlineScanner64.exe & echo. & pause & exit) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

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
>>"%vbs%" echo sh.ShellExecute "cmd.exe", cmdLine, "", "runas", 1
>>"%vbs%" echo WScript.Quit

:: call wscript, first arg = path to this .bat, then all original args
"%windir%\system32\wscript.exe" "%vbs%" "%~f0" %*

del "%vbs%" 2>nul
exit /b

:main
cls
set count=0
for %%A in (%*) do set /a count+=1
echo.
if %count% equ 0 (echo  [1] Scan: ^(nothing selected^)) else if %count% equ 1 (echo  [1] Scan: %*) else (echo  [1] Scan: %count% objects)
echo  [2] Scan memory
echo  [3] Show status
echo  [4] Update signature
echo. 
if %count% equ 0 (
    CHOICE /C 234 /M "Your choice?:" >nul 2>&1
    if errorlevel 3 goto Option_4
    if errorlevel 2 goto Option_3
    if errorlevel 1 goto Option_2
) else (
    CHOICE /C 1234 /M "Your choice?:" >nul 2>&1
    if errorlevel 4 goto Option_4
    if errorlevel 3 goto Option_3
    if errorlevel 2 goto Option_2
    if errorlevel 1 goto Option_1
)
exit

:Option_1
set i=0
set found=0
FOR %%k IN (%*) DO (
    set /a i+=1
    call :processFile %%i%% %count% "%%~fk"
    if errorlevel 1 set found=1
)
if %found%==1 (color C) else (color A)
echo. & echo  [DONE] & echo. & pause >nul & exit
:processFile
echo. & echo  [%1/%2] "%~3"
"%app%" /a /pup /cloud=0 "%~3"
exit /b

:Option_2
"%app%" /m
pause & goto main

:Option_3
"%app%" /status
echo. & pause & goto main

:Option_4
"%app%" /u
echo. & pause & goto main

:shortcut
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Emsisoft scanner.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app%'; $s.Save()"
echo. & echo  Shortcut 'Emsisoft scanner.lnk' created. & echo. & pause & exit
