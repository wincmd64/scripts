:: Adds "Open in Total Commander" entry to the Explorer context menu
::   [area] files, dirs and desktop
:: by github.com/wincmd64


@echo off
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

:: %COMMANDER_EXE%
if not exist "%COMMANDER_EXE%" (echo. & echo  Start Total Commander and run this file again & echo. & pause & exit)

:: dirs
reg add "HKCU\Software\Classes\Directory\shell\OpenTC" /v "MUIVerb" /d "Open in Total Commander" /f
reg add "HKCU\Software\Classes\Directory\shell\OpenTC" /v "Icon" /d "%COMMANDER_EXE%" /f
reg add "HKCU\Software\Classes\Directory\shell\OpenTC\command" /ve /d "%COMMANDER_EXE% /O /S /T /A /L=\"%%1\"" /f
:: files
reg add "HKCU\Software\Classes\*\shell\OpenTC" /v "MUIVerb" /d "Open in Total Commander" /f
reg add "HKCU\Software\Classes\*\shell\OpenTC" /v "Icon" /d "%COMMANDER_EXE%" /f
reg add "HKCU\Software\Classes\*\shell\OpenTC\command" /ve /d "%COMMANDER_EXE% /O /S /T /A /L=\"%%1\"" /f
:: desktop
reg add "HKCU\Software\Classes\DesktopBackground\shell\OpenTC" /v "MUIVerb" /d "Total Commander" /f
reg add "HKCU\Software\Classes\DesktopBackground\shell\OpenTC" /v "Icon" /d "%COMMANDER_EXE%" /f
reg add "HKCU\Software\Classes\DesktopBackground\shell\OpenTC" /v "Position" /d "Bottom" /f
reg add "HKCU\Software\Classes\DesktopBackground\shell\OpenTC\command" /ve /d "%COMMANDER_EXE% /O 0" /f && (color A & timeout 2 & exit) || (echo. & pause & exit)

:undo
reg delete "HKCU\Software\Classes\Directory\shell\OpenTC" /f
reg delete "HKCU\Software\Classes\*\shell\OpenTC" /f
reg delete "HKCU\Software\Classes\DesktopBackground\shell\OpenTC" /f && (color A & timeout 2) || (echo. & pause)
