:: Wrapper for ContConv CLI — contact (.vcf) convertor
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
:start
for /f "tokens=* delims=" %%a in ('where contconv.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0contconv.exe" set "app=%~dp0contconv.exe"
if exist "%app%" goto skip_download
echo. & echo  "contconv.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/DarkHobbit/doublecontact/releases'; $a=$r.assets|?{$_.name -like '*portable*'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/DarkHobbit/doublecontact/releases & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -command "Invoke-WebRequest -Uri '%url%' -OutFile '%temp%\%filename%'"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%" --strip-components=1 *contconv.exe *.dll) else (echo. & echo  %filename% not found. & echo. & pause)
echo. & echo. & echo  DONE. & echo. & pause & goto start

:skip_download
cls
TITLE %app%
:: arguments
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
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,159'; $s.Save()"
echo. & echo  Shortcut 'VCF converter.lnk' created. & echo. & timeout 2
