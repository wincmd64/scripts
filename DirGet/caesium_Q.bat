:: Wrapper for Caesium CLI — image compression utility
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir

@echo off
setlocal

:: [SETTINGS]
set "app=caesiumclt.exe"
set "dir=%~dp0"
set "app_path=%dir%%app%"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local ver
if exist "%app%" (for /f "tokens=2" %%i in ('"%app%" -V') do set current_version=%%i)

if not defined current_version (echo. & echo  Download Caesium CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/Lymphatus/caesium-clt/releases/latest'; $a=$r.assets|?{$_.name -like '*windows-msvc.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/Lymphatus/caesium-clt/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo   Latest version: %latest_version%
    echo. & echo  Update? & echo. 
    pause
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
tar -xf "%temp%\%filename%" --strip-components=1 *.exe 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %app%
:: /s arg
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
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,139'; $s.Save()"
echo. & echo  Shortcut 'Image compression.lnk' created. & echo. & timeout 2