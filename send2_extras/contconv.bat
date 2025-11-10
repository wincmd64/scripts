:: Wrapper for ContConv CLI — contact (.vcf) convertor
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
for /f "tokens=* delims=" %%a in ('where contconv.exe 2^>nul') do set "app=%%a"
if not defined app if exist "%~dp0contconv.exe" set "app=%~dp0contconv.exe"
if not exist "%app%" (echo. & echo  "contconv.exe" not found. & echo  Download it from: https://github.com/DarkHobbit/doublecontact/releases & echo. & pause & exit) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

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
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\VCF converter.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,126'; $s.Save()"
echo. & echo  Shortcut 'VCF converter.lnk' created. & echo. & timeout 2
