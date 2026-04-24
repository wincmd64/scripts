:: MPC-HC x64 UPDATER
:: by github.com/wincmd64

:: Look for mpc-hc64.exe in the script directory.
:: If present, check for updates; otherwise offer to download the latest version.

:: Use /a to associate with video files

@echo off
setlocal

:: [SETTINGS]
set "name=MPC-HC"
set "app=mpc-hc64.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: arguments
if exist "%app%" if /i "%~1"=="/a" goto associate

if exist "%app%" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item '%app%').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

:update
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: github latest ver
call :github "clsid2/mpc-hc" "*x64.zip" "https://github.com/clsid2/mpc-hc/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:check_task
tasklist /fi "imagename eq %app%" | find /i "%app%" >nul
if not errorlevel 1 (echo. & echo  [!] %name% running. Please close it to continue. & echo. & pause & goto check_task)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
echo. & echo  Extracting ...
tar -xf "%temp%\%filename%" 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
if exist "mpc-hc64.ini" goto done
echo. & echo  Creating ini ...
set "temp_ini=%TEMP%\mpc_hc_tmp.ini"
set "final_ini=mpc-hc64.ini"
(
  echo [Commands2]
  echo ;- Esc instead of Alt+X
  echo ;- Enter instead of Alt+Enter
  echo ;- Alt 1..3 è 1..3 vice versa
  echo CommandMod0=816 1 1b "" 5 0 0 0 0 0
  echo CommandMod1=827 11 31 "" 5 0 0 0 0 0
  echo CommandMod2=828 11 32 "" 5 0 0 0 0 0
  echo CommandMod3=829 11 33 "" 5 0 0 0 0 0
  echo CommandMod4=830 1 d "" 5 3 0 3 0 0
  echo CommandMod5=832 1 31 "" 5 0 0 0 0 0
  echo CommandMod6=833 1 32 "" 5 0 0 0 0 0
  echo CommandMod7=834 1 33 "" 5 0 0 0 0 0
  echo [Settings]
  echo UpdaterAutoCheck=0
  echo AllowMultipleInstances=1
  echo AfterPlayback=1
  echo UseSeekPreview=1
  echo AudioRendererType=MPC Audio Renderer
  echo SpeedStep=25
  echo ; black theme
  echo ModernThemeMode=0
  echo ; files
  echo RememberFilePos=1
  echo RememberPosForLongerThan=2
  echo RecentFilesNumber=5
  echo ;Statusbar
  echo ShowFPSInStatusbar=1
  echo [Toolbars\PlayerToolBar]
  echo ButtonSequence=HHDAAAAAIHDAAAAAKHDAAAAAJJDAAAAAOHDAAAAAPHDAAAAAKJDAAAAALHDAAAAACNDAAAAADNDAAAAABLDAAAAANIDAAAAA
  echo ButtonSequenceSize=48
) > "%temp_ini%"
powershell -command "Get-Content '%temp_ini%' | Out-File -FilePath '%final_ini%' -Encoding utf8; Remove-Item '%temp_ini%'"

:done
color A & echo. & echo. & echo  DOWNLOADED. Now launching... & echo.
start "" %app%
timeout 3 & exit

:associate
(Net session >nul 2>&1)&&(cd /d "%dir%")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
if not defined fta if exist "%dir%SetUserFTA.exe" set "fta=%dir%SetUserFTA.exe"
:: get SetUserFTA.exe
if not exist "%fta%" (
    echo. & echo  SetUserFTA.exe required. Try to download it to TEMP ? & echo. & pause
    curl.exe -fRLO# "https://setuserfta.com/SetUserFTA.zip" --output-dir "%temp%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo  Try manual: https://setuserfta.com/SetUserFTA.zip & echo. & pause & exit /b)
    tar -xf "%temp%\SetUserFTA.zip" -C "%temp%"
    if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause)
    set "fta=%temp%\SetUserFTA.exe"
    echo.
)

:: AVI
call :process avi 8
:: MPEG
call :process mpg 26
call :process mpeg 26
call :process mpe 26
call :process m1v 26
call :process m2v 26
call :process mpv2 26
call :process mp2v 26
call :process pva 26
call :process evo 26
call :process m2p 26
:: MPEG-TS
call :process ts 36
call :process tp 36
call :process trp 36
call :process m2t 36
call :process m2ts 36
call :process mts 36
call :process rec 36
call :process ssif 36
:: DVD-Video
call :process vob 38
call :process ifo 16
:: Matroska
call :process mkv 20
call :process mk3d 20
:: WebM
call :process webm 40
:: MP4
call :process mp4 23
call :process m4v 23
call :process mp4v 23
call :process mpv4 23
call :process hdmov 23
:: Quick Time
call :process mov 21
:: 3GP
call :process 3gp 0
call :process 3gpp 0
call :process 3g2 0
call :process 3gp2 0
:: Flash Video
call :process flv 15
call :process f4v 15
:: Ogg Media
call :process ogm 29
call :process ogv 29
:: Real Media
call :process rm 32
call :process rmvb 32
call :process ram 32
:: Windows Media Video
call :process wmv 42
call :process wmp 42
call :process wm 42
call :process asf 42
:: Smacker/Bink Video
call :process smk 34
call :process bik 34
:: FLIC Animation
call :process fli 14
call :process flc 14
call :process flic 14
:: DirectShow Media
call :process dsm 11
call :process dsv 11
call :process dsa 11
call :process dss 11
:: Indeo Video Format
call :process ivf 17
:: Other
call :process divx 0
call :process amv 0
call :process mxf 0
call :process dv 0
call :process dav 0
:: Blu-ray playlist
call :process mpls 30
call :process bdmv 30
:: Custom
call :process mod 0
call :process 264 0
call :process hevc 0

echo. & echo Current associations: & "%fta%" get | findstr /i "mpc" & echo. & pause & exit

:process
assoc .%1=mpc_%1
ftype mpc_%1="%dir%%app%" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%fta%" .%1 mpc_%1
reg add "HKCU\Software\Classes\mpc_%1\DefaultIcon" /ve /d "%dir%mpciconlib.dll,%2" /f >nul
exit /b

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference = 'SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; if($r -is [array]){$rel=$r[0]}else{$rel=$r}; $a=$rel.assets|?{$_.name -like '%filter%'}|select -f 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
for /f "usebackq tokens=*" %%a in (`powershell -command "%ps_cmd%" 2^>nul`) do (
    if not defined latest_version (
        set "latest_version=%%a"
    ) else if not defined url (
        set "url=%%a"
    ) else if not defined filename (
        set "filename=%%a"
    ) else (
        set "server_date=%%a"
    )
)

:: if PS failed, latest_version will contain error text or be empty
if "%url:~0,4%" NEQ "http" (
    set "url="
    set "latest_version="
    echo.
    echo  Error: Repository "%repo%" not found or API limit reached.
    echo  Try manual: %manual_url%  & echo. & pause
    exit /b
)

echo. & echo  Repo: %repo%
echo   Ver: %latest_version% (%server_date%)
echo  File: %filename%
echo  Link: %url%
echo.
goto :eof