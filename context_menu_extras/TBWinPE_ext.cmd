:: Adds "Boot image" entry to the Explorer context menu
::   [area] .wim files
:: by github.com/wincmd64

@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

for /f "tokens=* delims=" %%a in ('where TBWinPE.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0TBWinPE.exe" set "app=%~dp0TBWinPE.exe"
if not exist "%app%" (
    echo. & echo  "TBWinPE.exe" not found. & echo  Try to download it to TEMP ? & echo. & pause
    curl.exe "https://www.terabyteunlimited.com/downloads/wp/tbwinpe.zip" -RLO# -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" --output-dir "%temp%" 
    if exist "%temp%\tbwinpe.zip" (tar -xf "%temp%\tbwinpe.zip" -C "%temp%" 2>nul) else (
        color C & echo  tbwinpe.zip not found.
        echo  Try manual: https://www.terabyteunlimited.com/downloads/wp/tbwinpe.zip & echo.
        pause & exit
    )
    set "app=%temp%\TBWinPE.exe"
) 
TITLE %app%

reg add "HKCU\Software\Classes\SystemFileAssociations\.wim\shell\wincmd64_WIM" /v "MUIVerb" /d "Boot image" /f
reg add "HKCU\Software\Classes\SystemFileAssociations\.wim\shell\wincmd64_WIM" /v "Icon" /d "%app%" /f
reg add "HKCU\Software\Classes\SystemFileAssociations\.wim\shell\wincmd64_WIM" /v "Position" /d "Bottom" /f
reg add "HKCU\Software\Classes\SystemFileAssociations\.wim\shell\wincmd64_WIM\command" /ve /d "\"%app%\" /bootwim \"%%1\"" /f

color A & timeout 2 & exit

:undo
reg delete "HKCU\Software\Classes\SystemFileAssociations\.wim\shell\wincmd64_WIM" /f
color A & timeout 2
