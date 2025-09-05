:: IrfanView converter
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder
:: /a - associate image files with IrfanView (SetUserFTA.exe required)

:: Note: this file must use code page OEM 866

@echo off
setlocal

:: path to i_view64.exe - custom if nedded
set "myapp="
if defined myapp if exist "%myapp%" (set "app=%myapp%") 
:: path to i_view64.exe - from PATH or same folder
if not defined app (for /f "tokens=* delims=" %%a in ('where i_view64.exe 2^>nul') do set "app=%%a")
:: trying to download IrfanView + all plugins + skin + lang + configure .ini
if not exist "%app%" (
    echo. & echo  i_view64.exe not found. Try to download it to "%~dp0IrfanView\" ? & echo. & pause
    cd /d "%~dp0"
    :: checking connection
    ping -n 1 www.irfanview.info >nul 2>&1
    if errorlevel 1 (color C & echo. & echo  Unable to reach www.irfanview.info. Check your internet connection. & echo. & pause & exit)
    :: get latest version
    for /f tokens^=1-3^ delims^=^" %%i in ('curl.exe --ssl-no-revoke -s "https://www.irfanview.com/64bit.htm" ^| FINDSTR /IRC:"href=.*iview[0-9]*_x64\.zip"') do (
        set "mainZip=%%~nxj"
        goto :afterMainZip
    )
    :afterMainZip
    set "pluginsZip=%mainZip:_x64.zip=_plugins_x64.zip%"
     echo. & echo  Trying to download ... & echo.
    if not exist "%mainZip%" curl.exe --ssl-no-revoke -LR#H "Referer: https://www.irfanview.info/" -o "%mainZip%" "https://www.irfanview.info/files/%mainZip%"
    if not exist "%pluginsZip%" curl.exe --ssl-no-revoke -LR#H "Referer: https://www.irfanview.info/" -o "%pluginsZip%" "https://www.irfanview.info/files/%pluginsZip%"
    if not exist "irfanview_skin_iconshock.zip" curl.exe --ssl-no-revoke -LOR# "https://www.irfanview.com/skins/irfanview_skin_iconshock.zip"
    if not exist "irfanview_lang_ukrainian.zip" curl.exe --ssl-no-revoke -LOR# "https://www.irfanview.net/lang/irfanview_lang_ukrainian.zip"
    md "IrfanView"
     echo. & echo  Trying to unpack ...
    if exist "%mainZip%" (tar -xf "%mainZip%" -C "IrfanView" 2>nul) else (echo. & echo  where %mainZip% ? & pause)
    if exist "IrfanView\i_view64.exe" (del "%mainZip%") else (echo. & echo  error unpacking %mainZip% & pause)
    if exist "%pluginsZip%" (tar -xf "%pluginsZip%" -C "IrfanView\Plugins" 2>nul) else (echo. & echo  where %pluginsZip% ? & pause)
    if exist "irfanview_skin_iconshock.zip" (tar -xf "irfanview_skin_iconshock.zip" -C "IrfanView\Toolbars" 2>nul) else (echo. & echo  where irfanview_skin_iconshock.zip ? & pause)
    if exist "irfanview_lang_ukrainian.zip" (tar -xf "irfanview_lang_ukrainian.zip" -C "IrfanView\Languages" 2>nul) else (echo. & echo  where irfanview_lang_ukrainian.zip ? & pause)
    del "%pluginsZip%" "irfanview_skin_iconshock.zip" "irfanview_lang_ukrainian.zip"
     echo. & echo  Creating i_view64.ini ...
    (
    echo [Viewing]
    echo BackColor=8421504
    echo FitWindowOption=3
    echo ShowMultipageDlg=1
    echo [Others]
    echo LoopCurDir=1
    echo BeepOnLoop=0
    echo JumpAfterDelete=1
    echo [WinPosition]
    echo Maximized=1
    echo MultiThumb=2,88,161,910,0;
    echo [Extensions]
    echo CustomExtensions=JPG^|JPEG^|JPE^|PNG^|GIF^|BMP^|TIF^|TIFF^|ICO^|PSD^|TGA^|WMF^|EMF^|WEBP^|HEIC^|AVIF^|PDF^|DJVU^|
    echo [Toolbar]
    echo Skin=IconShock Android_24.png
    echo Size=24
    echo Flag=2097151
    echo [Disabled_PlugIns]
    echo DICOM.DLL=0
    echo DJVU.DLL=0
    echo JPEG2000.DLL=0
    )>temp.txt
    :: to UTF-16
    powershell -command "Get-Content 'temp.txt' | Out-File 'IrfanView\i_view64.ini' -Encoding Unicode; Remove-Item 'temp.txt'"
    echo. & echo. & echo  DONE. & echo  Add the folder "%~dp0IrfanView" to PATH ^(or move this file into that folder^) and run this file. & echo. & pause & exit
) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)
if /i "%~1"=="/a" (if "%~2"=="" goto :associate)

echo.
echo  �ۻ�����ۻ ������ۻ ����ۻ ��ۻ   �ۻ�ۻ   �ۻ�ۻ������ۻ�ۻ    �ۻ
echo  �ۺ������ۻ������ͼ������ۻ���ۻ  �ۺ�ۺ   �ۺ�ۺ������ͼ�ۺ    �ۺ
echo  �ۺ������ɼ����ۻ  ������ۺ����ۻ �ۺ�ۺ   �ۺ�ۺ����ۻ  �ۺ ۻ �ۺ
echo  �ۺ������ۻ����ͼ  ������ۺ�ۺ��ۻ�ۺ��ۻ ��ɼ�ۺ����ͼ  �ۺ��ۻ�ۺ
echo  �ۺ�ۺ  �ۺ�ۺ     �ۺ  �ۺ�ۺ ����ۺ �����ɼ �ۺ������ۻ��������ɼ
echo  �ͼ�ͼ  �ͼ�ͼ     �ͼ  �ͼ�ͼ  ���ͼ  ���ͼ  �ͼ������ͼ ��ͼ��ͼ 
echo.
chcp 1251 >nul
:: checking the number of selected files
set count=0
for %%A in (%*) do set /a count+=1

if %count% equ 0 (
    echo  No files selected & echo.
    echo  1 = create shortcut in Shell:SendTo folder
    echo  2 = associate image files with IrfanView
    echo.
    CHOICE /C 12 /M "Your choice?:" >nul 2>&1
    if errorlevel 2 goto :associate
    if errorlevel 1 goto :shortcut
)

if %count% equ 1 (echo  Processing: %* & echo.) else (echo  Processing: %count% files & echo.)
if "%~x1"=="" echo  NOTICE: first argument is likely a folder or has no extension. & echo.
echo  1 = resize image by 50%%
echo  2 = blur effect
echo  3 = horizontal panorama
echo  4 = vertical panorama
echo  5 = convert to .ext
echo  6 = create multipage PDF or TIF from input files
echo  7 = extract all pages from a multipage file to .ext
echo  8 = jpg lossless rotate
echo  9 = set as wallpaper
echo.
CHOICE /C 123456789 /M "Your choice?:" >nul 2>&1
if errorlevel 9 goto Option_9
if errorlevel 8 goto Option_8
if errorlevel 7 goto Option_7
if errorlevel 6 goto Option_6
if errorlevel 5 goto Option_5
if errorlevel 4 goto Option_4
if errorlevel 3 goto Option_3
if errorlevel 2 goto Option_2
if errorlevel 1 goto Option_1
exit

:Option_1
FOR %%k IN (%*) DO (
    echo  FILE: "%%~k"
    "%app%" "%%~k" /resize=^(50p,50p^) /resample /convert="%%~dpnk_resized%%~xk"
)
color A & timeout 1 & exit
:Option_2
FOR %%k IN (%*) DO (
    echo  FILE: "%%~k"
    "%app%" "%%~k" /effect=^(2,6^) /resample /convert="%%~dpnk_blurred%%~xk"
)
color A & timeout 1 & exit
:Option_3
pushd "%~dp1"
for %%i in (%*) do call set args=%%args%%,"%%~nxi"
start "" "%app%" /panorama=(1%args%) & exit
:Option_4
pushd "%~dp1"
for %%i in (%*) do call set args=%%args%%,"%%~nxi"
start "" "%app%" /panorama=(2%args%) & exit
:Option_5
set /p ext=Enter extention (png jpg bmp gif ico ... all supported: https://irfanview.com/main_formats.htm ): 
if not defined ext (goto Option_5)
FOR %%k IN (%*) DO (
    echo  FILE: "%%~k"
    "%app%" "%%~k" /resample /convert="%%~dpnk.%ext%" /makecopy
)
color A & timeout 1 & exit
:Option_6
pushd "%~dp1"
for %%i in (%*) do call set args=%%args%%,"%%~nxi"
echo  1 = convert as PDF
echo  2 = convert as TIF
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if errorlevel 2 "%app%" /multitif=(%~n1.tif%args%) /tifc=6 /killmesoftly
if errorlevel 1 "%app%" /multipdf=(%~n1.pdf%args%) /killmesoftly
color A & timeout 1 & exit
:Option_7
set /p ext=Enter extention (png jpg bmp gif ico ... all supported: https://irfanview.com/main_formats.htm ): 
if not defined ext (goto Option_7)
FOR %%k IN (%*) DO (
    echo  FILE: "%%~k"
    "%app%" "%%~k" /extract=^(.,%ext%^) /killmesoftly
)
color A & timeout 1 & exit
:Option_8
if /I not "%~x1"==".jpg" echo  NOTICE: first file is not a .JPG & echo.
echo  1 = flip vertically
echo  2 = flip horizontally
echo  3 = rotate 90 degrees (default)
echo  4 = rotate 180 degrees
echo  5 = rotate 270 degrees
echo  6 = auto rotate & echo.
set /p opt=Enter option or press Enter for default (rotate 90 degrees): 
if "%opt%"=="" (SET opt=3)
pushd "%~dp1"
(
    for %%i in (%*) do @echo %%~fi
) > "listfile.txt"
"%app%" /filelist="listfile.txt" /jpg_rotate=^(%opt%,1,0,1^) /killmesoftly
del listfile.txt
color A & timeout 1 & exit
:Option_9
echo Setting wallpaper: "%~1"
start "" "%app%" "%~1" /wall=4 /killmesoftly & exit

:shortcut
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\IrfanView converter.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = '%app%'; $s.Save()"
echo. & echo  Shortcut 'IrfanView converter.lnk' created. & echo. & pause & exit

:associate
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
if not exist "%fta%" (color C & echo. & echo  SetUserFTA.exe not found. Try download from: https://setuserfta.com/SetUserFTA.zip & echo. & pause & exit)
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
echo. & echo  Associate image files with "%app%" ? & echo. & pause
for %%A in ("%app%") do set "app_dir=%%~dpA"
set "icons=%app_dir%Plugins\Icons.dll"

call :process jpg 14
call :process png 21
call :process bmp 0
call :process gif 10
call :process tif 31
call :process djvu 5

echo. & echo Current associations: & SetUserFTA.exe get | findstr /i "irfan" & echo. & pause & exit

:process
assoc .%1=irfan_%1
ftype irfan_%1="%app%" "%%1"
SetUserFTA.exe .%1 irfan_%1
reg add "HKCU\Software\Classes\irfan_%1\DefaultIcon" /ve /d "%icons%,%2" /f
exit /b
