:: Wrapper for ContConv CLI — contact (.vcf) convertor
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder
:: (no arguments) - check/update software in script dir   /!\ REQUIRED: https://github.com/inherelab/eget

@echo off
setlocal

:: [SETTINGS]
set "name=ContConv CLI"
set "app=contconv.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:download
if exist "%app%" (
    eget.exe query DarkHobbit/doublecontact
    echo. & echo  Update? & echo. & pause
    eget.exe dl --file "*.dll,contconv.exe" --tag "0.2.5b3" --strip-components 1 --asset "zip" DarkHobbit/doublecontact
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
) else (
    echo. & echo  Download %app% to "%dir%" ? & echo. & pause
    eget.exe dl --file "*.dll,contconv.exe" --tag "0.2.5b3" --strip-components 1 --asset "zip" DarkHobbit/doublecontact
    if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
)

:skip_download
cls
TITLE %dir%%app%
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
echo. & echo  Shortcut 'VCF converter.lnk' created. & echo. & timeout 2 & exit
