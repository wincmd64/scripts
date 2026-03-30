:: Wrapper for ContConv CLI — contact (.vcf) convertor
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
set "app=contconv.exe"
set "dir=%~dp0"
set "app_path=%dir%%app%"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local file date
if exist "%app%" (
    echo. & echo  Getting local file date...
    for /f "tokens=*" %%d in ('powershell -C "(Get-Item '%app%').LastWriteTime.ToString('dd.MM.yyyy')"') do set "file_date=%%d"
    cls
)

if not defined file_date (echo. & echo  Download ContConv CLI to "%dir%" ? & echo. & pause
) else (echo. & echo  Current file date: %file_date% & echo  Checking for updates...)

:: github api
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/DarkHobbit/doublecontact/releases'; $rel=$r[0]; $a=$rel.assets|?{$_.name -like '*portable*'}|select -f 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
for /f "usebackq tokens=*" %%a in (`powershell -command "%ps_cmd%"`) do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else if not defined filename (set "filename=%%a") else (set "server_date=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/DarkHobbit/doublecontact/releases & pause & exit /b)

:: update logic
if defined file_date (
    echo   Latest version: %latest_version% (^%server_date%^)
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
tar -xf "%temp%\%filename%" --strip-components=1 *contconv.exe *.dll 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %app%
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
if %count% equ 1 (echo. & echo  Processing: %* & echo.) else (echo. & echo  Processing %count% objects. & echo.)
if /I not "%~x1"==".vcf" echo  NOTICE: extension is not .VCF & echo.

echo  [1] convert to HTML
echo  [2] convert to CSV
echo. 
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if %errorlevel%==2 (set "fmt=csv" & set "opt=-op generic") else (set "fmt=html" & set "opt=")
for %%k in (%*) do (
    echo. & echo  FILE: %%k
    "%app%" -i "%%~k" -o "%%~dpnk.%fmt%" -f %fmt% %opt% -w
)
echo. & echo. & echo  DONE. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\VCF converter.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,158'; $s.Save()"
echo. & echo  Shortcut 'VCF converter.lnk' created. & echo. & timeout 2