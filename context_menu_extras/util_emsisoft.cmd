:: Adds "Emsisoft Scanner" entry to the Explorer context menu
::   [area] all files and dirs
:: by github.com/wincmd64

@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

for /f "tokens=* delims=" %%a in ('where a2cmd.exe 2^>nul') do set "app=%%a"
if not exist "%app%" (color 4 & echo. & echo  a2cmd.exe not found. Try download from: https://dl.emsisoft.com/EmsisoftCommandlineScanner64.exe & echo. & pause & exit)

echo CreateObject("Shell.Application").ShellExecute "cmd.exe", "/c " ^& Chr(34) ^& "%app% " ^& Chr(34) ^& WScript.Arguments.Item(0) ^& Chr(34) ^& " /a /pup /cloud=0 & pause" ^& Chr(34), "", "runas", 1 > "%temp%\elevatea2cmd.vbs"
 
reg add "HKCU\Software\Classes\*\shell\wincmd64_AntiMalware" /v "MUIVerb" /d "Emsisoft Scanner" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_AntiMalware" /v "Icon" /d "%app%" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_AntiMalware\command" /ve /d "WScript.exe \"%temp%\elevatea2cmd.vbs\" \"%%1\"" /f

reg add "HKCU\Software\Classes\Directory\shell\wincmd64_AntiMalware" /v "MUIVerb" /d "Emsisoft Scanner" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_AntiMalware" /v "Icon" /d "%app%" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_AntiMalware\command" /ve /d "WScript.exe \"%temp%\elevatea2cmd.vbs\" \"%%1\"" /f

color 27 & timeout 1 & exit

:undo
reg delete "HKCU\Software\Classes\*\shell\wincmd64_AntiMalware" /f
reg delete "HKCU\Software\Classes\Directory\shell\wincmd64_AntiMalware" /f
del "%temp%\elevatea2cmd.vbs"
color 27 & timeout 1
