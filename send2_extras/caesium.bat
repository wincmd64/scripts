:: Wrapper for Caesium CLI — image compression utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where caesiumclt.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0caesiumclt.exe" set "app=%~dp0caesiumclt.exe"
if exist "%app%" goto skip_download
echo. & echo  "caesiumclt.exe" not found. & echo.
echo   [1] download it to "%~dp0"
echo   [2] winget install SaeraSoft.CaesiumCLT
echo.
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if errorlevel 2 goto download_winget
if errorlevel 1 goto download_manual
exit
:download_manual
:: getting the latest version via the GitHub API
echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/Lymphatus/caesium-clt/releases/latest'; $a=$r.assets|?{$_.name -like '*windows*.zip'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%filename%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/Lymphatus/caesium-clt/releases & echo. & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: "%filename%"
    powershell -C "Start-BitsTransfer -Source '%url%' -Destination '%temp%\%filename%'"
) else (echo. & echo  Downloading: "%filename%" already in TEMP)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" -C "%~dp0." --strip-components=1 *.exe 2>nul) else (echo. & echo  %filename% not found. & echo. & pause)
echo. & echo. & echo  DONE. & echo. & pause & goto start
:download_winget
winget install SaeraSoft.CaesiumCLT
if %errorlevel% neq 0 (echo. & echo  Installation failed with error code: %errorlevel% & echo. & pause & exit)
echo. & echo  DONE. Restart the script. & echo. & pause & exit

:skip_download
cls
TITLE %app%
:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo. & pause) else (echo. & echo  Processing %count% objects. & echo. & pause)

FOR %%k IN (%*) DO (echo. & "%app%" --lossless --exif --keep-dates --same-folder-as-input --overwrite bigger "%%~k")
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Image compression.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,127'; $s.Save()"
echo. & echo  Shortcut 'Image compression.lnk' created. & echo. & timeout 2