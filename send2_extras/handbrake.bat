:: Wrapper for HandBrake CLI — convert video using presets
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where HandBrakeCLI.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0HandBrakeCLI.exe" set "app=%~dp0HandBrakeCLI.exe"
if exist "%app%" goto skip_download
echo. & echo  "HandBrakeCLI.exe" not found. & echo.
echo   [1] download it to "%~dp0"
echo   [2] winget install HandBrake.HandBrake.CLI
echo.
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if errorlevel 2 goto download_winget
if errorlevel 1 goto download_manual
exit
:download_manual
:: getting the latest version via the GitHub API
echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/HandBrake/HandBrake/releases/latest'; $a=$r.assets|?{$_.name -like '*CLI*x86_64.zip'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%filename%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/HandBrake/HandBrake/releases & echo. & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: "%filename%"
    curl.exe -RL# "%url%" -o "%temp%\%filename%"
) else (echo. & echo  Downloading: "%filename%" already in TEMP)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" -C "%~dp0." *.exe 2>nul) else (echo. & echo  %filename% not found. & echo. & pause)
echo. & echo. & echo  DONE. & echo. & pause & goto start
:download_winget
winget install HandBrake.HandBrake.CLI
if %errorlevel% neq 0 (echo. & echo  Installation failed with error code: %errorlevel% & echo. & pause & exit)
echo. & echo  DONE. Restart the script. & echo. & pause & exit

:skip_download
cls
TITLE %app%
:: arguments
if "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% objects. & echo.)
if "%~x1"=="" echo  NOTICE: first argument is likely a folder or has no extension. & echo.

echo   Full list of presets: https://handbrake.fr/docs/en/latest/technical/official-presets.html
echo   Some examples: "Very Fast 1080p30", "Super HQ 1080p30 Surround", "Fast 1080p30" (default) & echo.

SET /p preset= Enter HandBrake preset name or press Enter for default: 
if "%preset%"=="" (SET preset=Fast 1080p30)
TITLE %preset%

FOR %%k IN (%*) DO (
    echo. & echo FILE: %%k
    "%app%" -v0 -Z "%preset%" -E copy -i "%%~k" -o "%%~dpnk_%preset%.mp4"
    FOR /f "tokens=1-5 delims=.-/: " %%m IN ("%%~tk") DO (
        powershell "Get-ChildItem '%%~dpnk_%preset%.mp4' | ForEach-Object{$_.CreationTime = $_.LastWriteTime = $_.LastAccessTime = New-Object DateTime %%o,%%n,%%m,%%p,%%q,00}"
    )
)
color A & timeout 2 & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\HandBrake.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,129'; $s.Save()"
echo. & echo  Shortcut 'HandBrake.lnk' created. & echo. & timeout 2