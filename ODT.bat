:: Office Deployment Tool
:: by github.com/wincmd64

@echo off
set "startdir=%~dp0"
chcp 1251 >nul
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs & Exit /B)
for /F "tokens=3 delims=." %%O in ('reg query "HKCR\Word.Application\CurVer" 2^>nul') do set officeVer=%%O
if defined officeVer (TITLE Office v%officeVer% detected) else (TITLE Office Deployment Tool)

:: get downloads folder path
for /f "delims=" %%a in ('powershell -NoP -C "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"') do set "DOWNLOADS=%%a"

echo. & echo  This script runs MS Office setup 
echo  using an XML configuration file.
echo.
echo   [1] select XML file
echo       ^(can be generated with 'https://config.office.com/deploymentsettings'^)
echo   [2] use built-in preset: Office 2021 VL x64
echo       ^(Word, Excel, PowerPoint only^)
echo.
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if errorlevel 2 goto Option_2
if errorlevel 1 goto Option_1
exit

:Option_1
for /f "delims=" %%A in ('powershell -NoP "Add-Type -AssemblyName System.Windows.Forms; $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter='XML files (*.xml)|*.xml'; $dlg.InitialDirectory = '%STARTDIR%'; if($dlg.ShowDialog() -eq 'OK'){ $dlg.FileName }"') do set "XML_SOURCE=%%A"
if not defined XML_SOURCE echo  Cancelled. & echo. & pause & exit
echo  Selected: %XML_SOURCE% & echo.
goto :run

:Option_2
set "XML_SOURCE=%temp%\office2021.xml"
> "%XML_SOURCE%" (
  echo ^<Configuration^>
  echo   ^<Add OfficeClientEdition="64" Channel="PerpetualVL2021"^>
  echo     ^<Product ID="Standard2021Volume"^>
  echo       ^<Language ID="MatchOS" /^>
  echo       ^<ExcludeApp ID="OneDrive" /^>
  echo       ^<ExcludeApp ID="OneNote" /^>
  echo       ^<ExcludeApp ID="Outlook" /^>
  echo       ^<ExcludeApp ID="Publisher" /^>
  echo     ^</Product^>
  echo   ^</Add^>
  echo   ^<Display Level="Full" AcceptEULA="TRUE" /^>
  echo ^</Configuration^>
)

:RUN
pushd "%DOWNLOADS%"
if not exist "setup.exe" (
    echo  Download "setup.exe" to "%DOWNLOADS%" ? & echo. & pause
    curl.exe --ssl-no-revoke https://officecdn.microsoft.com/pr/wsus/setup.exe -OR#
    if errorlevel 1 (color C & echo. & echo  ERROR: setup.exe download failed. & echo. & pause & exit)
)
echo. & echo  run: setup.exe /configure "%XML_SOURCE%" ? & echo. & pause
start "" "%DOWNLOADS%\setup.exe" /configure "%XML_SOURCE%"
echo. & echo  Installation started...
timeout 3
