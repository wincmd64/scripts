:: Office Deployment Tool
:: by github.com/wincmd64

@echo off
chcp 1251 >nul
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs & Exit /B)

:: https://en.wikipedia.org/wiki/Microsoft_Office#History_of_releases
for /F "tokens=3 delims=." %%O in ('reg query "HKCR\Word.Application\CurVer" 2^>nul') do set officeVer=%%O
if defined officeVer (echo. & echo    WARNING: Office v%officeVer% already installed & echo.)

echo. & echo       This script runs MS Office setup using an XML configuration file. & echo.
echo   [1] Select XML file
echo       ^(can be generated with 'https://config.office.com/deploymentsettings'^)
echo   [2] Use built-in presets
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
:: Not using Language ID="MatchOS": it installs two languages (OS language + en-us).
:: Instead, take the Windows UI language and pass it as a single explicit language.
for /f "delims=" %%L in ('powershell -NoP "(Get-UICulture).Name.ToLower()"') do set "OFF_LANG=%%L"
if not defined OFF_LANG set "OFF_LANG=en-us"
echo       [1] Office 2024 VL x64 ^(Word, Excel, PowerPoint only^) - %OFF_LANG%
echo       [2] Microsoft 365 Apps x64 ^(Word, Excel, PowerPoint only^) - %OFF_LANG%
echo.
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
set "XML_SOURCE=%temp%\office.xml"
set "OFF_CHANNEL=PerpetualVL2024"
set "OFF_PRODUCT=Standard2024Volume"
if errorlevel 2 (
  set "OFF_CHANNEL=MonthlyEnterprise"
  set "OFF_PRODUCT=O365ProPlusRetail"
)
> "%XML_SOURCE%" (
  echo ^<Configuration^>
  echo   ^<Add OfficeClientEdition="64" Channel="%OFF_CHANNEL%"^>
  echo     ^<Product ID="%OFF_PRODUCT%"^>
  echo       ^<Language ID="%OFF_LANG%" /^>
  echo       ^<ExcludeApp ID="OneDrive" /^>
  echo       ^<ExcludeApp ID="OneNote" /^>
  echo       ^<ExcludeApp ID="Outlook" /^>
  echo       ^<ExcludeApp ID="Publisher" /^>
  echo       ^<ExcludeApp ID="Access" /^>
  echo       ^<ExcludeApp ID="Groove" /^>
  echo       ^<ExcludeApp ID="Lync" /^>
  echo       ^<ExcludeApp ID="OutlookForWindows" /^>
  echo       ^<ExcludeApp ID="Teams" /^>
  echo     ^</Product^>
  echo   ^</Add^>
  echo   ^<Display Level="Full" AcceptEULA="TRUE" /^>
  echo ^</Configuration^>
)

:RUN
echo.
curl.exe https://officecdn.microsoft.com/pr/wsus/setup.exe -fRLO# --output-dir "%temp%"
if errorlevel 1 (echo  Error: download failed. & timeout 5 & goto RUN) else (echo. & echo   RUN: setup.exe /configure "%XML_SOURCE%" ? & echo. & pause)
start "" "%temp%\setup.exe" /configure "%XML_SOURCE%"
echo. & echo  Installation started...
color A & timeout 3
