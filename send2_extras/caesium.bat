:: Wrapper for Caesium CLI — image compression utility
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where caesiumclt.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0caesiumclt.exe" set "app=%~dp0caesiumclt.exe"
if exist "%app%" goto skip_download
echo. & echo  "caesiumclt.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting the latest version...
set "ps_get_url=$r = Invoke-RestMethod -Uri 'https://api.github.com/repos/Lymphatus/caesium-clt/releases/latest'; $a = $r.assets | Where-Object { $_.name -like '*windows*.zip' } | Select-Object -First 1; echo $a.browser_download_url"
set "ps_get_name=$r = Invoke-RestMethod -Uri 'https://api.github.com/repos/Lymphatus/caesium-clt/releases/latest'; $a = $r.assets | Where-Object { $_.name -like '*windows*.zip' } | Select-Object -First 1; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_get_url%"') do set "url=%%a"
for /f "tokens=*" %%a in ('powershell -command "%ps_get_name%"') do set "filename=%%a"
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/Lymphatus/caesium-clt/releases & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -command "Invoke-WebRequest -Uri '%url%' -OutFile '%temp%\%filename%'"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
md "%temp%\caesium"
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" -C "%temp%\caesium" 2>nul) else (echo. & echo  %filename% not found. & echo. & pause)
:: finds .exe
set "found_exe="
for /r "%temp%\caesium" %%F in (*caesium*clt.exe) do (set "found_exe=%%~fF")
:: move it
if defined found_exe (move /y "%found_exe%" "%~dp0" >nul) else (echo. & echo  Error: caesiumclt.exe not found inside the archive.)
rd /s /q "%temp%\caesium"
echo. & echo. & echo  DONE. & echo. & pause & goto start

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