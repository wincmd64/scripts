:: Office Deployment Tool
:: by github.com/wincmd64

@echo off
chcp 1251 >nul
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs & Exit /B)

:: ver finder https://en.wikipedia.org/wiki/Microsoft_Office#History_of_releases
for /F "tokens=3 delims=." %%O in ('reg query "HKCR\Word.Application\CurVer" 2^>nul') do set officeVer=%%O
if defined officeVer (TITLE Office v%officeVer% detected) else (TITLE Office Deployment Tool)

echo. & echo   This script runs MS Office setup using an XML configuration file. & echo.
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
:: looking XML in current dir
for /f "delims=" %%A in ('powershell -NoP "Add-Type -AssemblyName System.Windows.Forms; $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter='XML files (*.xml)|*.xml'; $dlg.InitialDirectory = '%~dp0'; if($dlg.ShowDialog() -eq 'OK'){ $dlg.FileName }"') do set "XML_SOURCE=%%A"
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
curl.exe https://officecdn.microsoft.com/pr/wsus/setup.exe -RLO# --output-dir "%temp%" & echo.
if exist "%temp%\setup.exe" (echo   RUN: setup.exe /configure "%XML_SOURCE%" ? & echo. & pause) else (color C & echo  setup.exe not found. & pause & exit)
start "" "%temp%\setup.exe" /configure "%XML_SOURCE%"
echo. & echo  Installation started...
color A & timeout 3
