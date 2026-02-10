:: MPC-HC (X64) UPDATER
::   Alternative to installer/winget
:: by github.com/wincmd64

@echo off
cd /d "%~dp0"

:: arguments
if /i "%~1"=="/a" goto associate

if exist "mpc-hc64.exe" (
    echo. & echo  Getting current version...
    for /f "tokens=*" %%v in ('powershell -command "$v = (Get-Item 'mpc-hc64.exe').VersionInfo.ProductVersion; if ($v -match '^\d+\.\d+\.\d+') { $matches[0] } else { $v.Trim() }"') do set "current_version=%%v"
    cls
)

if not defined current_version (echo. & echo  Download MPC-HC to "%~dp0" ? & echo. & pause
) else (echo. & echo  Current version: %current_version% & echo  Checking for updates...)

:: getting URL, filename and latest_ver
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/clsid2/mpc-hc/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.zip'}|select -f 1; echo $r.tag_name; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (
    if not defined latest_version (set "latest_version=%%a") else if not defined url (set "url=%%a") else (set "filename=%%a")
)
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try manual: https://github.com/clsid2/mpc-hc/releases & pause & exit /b)

:: update logic
if defined current_version (
    echo  Latest version:  %latest_version%
    echo. & echo  Update? & echo. 
    pause
    :check_task
    tasklist /fi "imagename eq mpc-hc64.exe" | find /i "mpc-hc64.exe" >nul
    if not errorlevel 1 (echo. & echo  [!] MPC-HC is running. Please close it to continue. & echo. & pause & goto check_task)
)

:: download and unpack
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -command "Invoke-WebRequest -Uri '%url%' -OutFile '%temp%\%filename%'"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
if exist "%temp%\%filename%" (tar -xf "%temp%\%filename%") else (echo. & echo  %filename% not found. & echo. & pause)
if exist "mpc-hc64.ini" goto done
echo. & echo  Creating ini ...
set "temp_ini=%TEMP%\mpc_hc_tmp.ini"
set "final_ini=mpc-hc64.ini"
setlocal DisableDelayedExpansion
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
endlocal
powershell -command "Get-Content '%temp_ini%' | Out-File -FilePath '%final_ini%' -Encoding utf8; Remove-Item '%temp_ini%'"

:done
echo. & echo. & echo  DONE. & echo.
choice /c YN /m "Associate video files with MPC-HC"
if errorlevel 2 goto eof

:associate
(Net session >nul 2>&1)&&(cd /d "%~dp0")||(PowerShell start """%~0""" -verb RunAs -ArgumentList '/a' & Exit /B)
if not exist "mpc-hc64.exe" (echo. & echo  mpc-hc64.exe not found. & echo. & pause & exit)
for /f "tokens=* delims=" %%a in ('where SetUserFTA.exe 2^>nul') do set "fta=%%a"
if not defined fta if exist "%~dp0SetUserFTA.exe" set "fta=%~dp0SetUserFTA.exe"
if not exist "%fta%" (
    echo. & echo  SetUserFTA.exe required. Try to download it to TEMP ? & echo. & pause
    :: check newer version
    curl.exe -RL#z "%temp%\SetUserFTA.zip" "https://setuserfta.com/SetUserFTA.zip" -o "%temp%\SetUserFTA.zip" 2>nul
    if exist "%temp%\SetUserFTA.zip" (tar -xf "%temp%\SetUserFTA.zip" -C "%temp%" 2>nul) else (
        color C & echo. & echo  SetUserFTA.zip not found.
        echo  Try manual: https://setuserfta.com/SetUserFTA.zip & echo.
        pause & exit
    )
    set "fta=%temp%\SetUserFTA.exe"
)
set "icons=%~dp0mpciconlib.dll"

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

echo. & echo Current MPC-HC associations: & "%fta%" get | findstr /i "mpc" & echo. & pause & exit

:process
assoc .%1=mpc_%1
ftype mpc_%1="%~dp0mpc-hc64.exe" "%%1"
reg add "HKCU\Software\Kolbicz IT\SetUserFTA" /v RunCount /t REG_DWORD /d 1 /f >nul
"%fta%" .%1 mpc_%1
reg add "HKCU\Software\Classes\mpc_%1\DefaultIcon" /ve /d "%icons%,%2" /f >nul
exit /b
