:: Various ffmpeg commands
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
set "name=FFmpeg"
set "app=ffmpeg.exe"
set "dir=%~dp0"
cd /d "%dir%"

:: no args - download or update, else - proceed
if exist "%app%" if "%~1" NEQ "" (goto skip_download)

:: get local ver
if not exist "%app%" goto update
echo. & echo  Getting current version...
for /f "tokens=3 delims=- " %%a in ('%app% -version ^| findstr /b "ffmpeg"') do (
    set "current_version=%%a"
    goto :update
)

:update
cls
if not defined current_version (echo. & echo  Download %name% to "%dir%" ? & echo. & pause
) else (echo. & echo  Current version: v%current_version% & echo  Checking for updates...)

:: github latest ver
call :github "GyanD/codexffmpeg" "*essentials_build.zip" "https://github.com/GyanD/codexffmpeg/releases"
if not defined url (goto update)
if defined current_version (echo. & echo  Update? & echo. & pause)

:: download and unpack
:download
echo. & echo  Downloading: %filename%
curl.exe -fRL# "%url%" -o "%temp%\%filename%"
if errorlevel 1 (echo. & echo  Download failed. Retrying in 5 seconds... & echo. & timeout 5 & goto download)
tar -xf "%temp%\%filename%" --strip-components=2 *.exe 2>nul
if errorlevel 1 (echo. & echo  Error: extraction failed. & echo. & pause) else (echo. & echo. & echo  DONE. & echo. & pause)

:skip_download
cls
TITLE %dir%%app%
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
:: /s arg
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

:::
:::  _____   _____                                    
::: |  ___| |  ___|  _ __ ___    _ __     ___    __ _ 
::: | |_    | |_    | '_ ` _ \  | '_ \   / _ \  / _` |
::: |  _|   |  _|   | | | | | | | |_) | |  __/ | (_| |
::: |_|     |_|     |_| |_| |_| | .__/   \___|  \__, |
:::                             |_|             |___/ 
:::
for /f "delims=: tokens=*" %%A in ('findstr /b ::: "%~f0"') do @echo(%ESC%[94m%%A%ESC%[0m

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo  No files selected & echo. & pause & exit)
if %count% equ 1 (
    echo  Processing: "%~nx1" & echo.
    if "%~x1"=="" echo  %ESC%[31m [!] NOTICE: first argument is likely a folder or has no extension.%ESC%[0m & echo.
    echo  [1] Remove all audio
    echo  [2] Extract audio stream
    echo  [3] Create GIF
    echo  [4] Cut
    echo  [5] 2x fast
    echo  [6] 0.5x slow
    echo  [7] Convert to 1080p ^(x264^)
    echo  [8] Rotate right
    echo  [9] Rotate left
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
) else (
    goto :MultiFile
)
goto :eof

:Option_1
"%app%" -hide_banner -i %1 -an -vcodec copy "%~dpn1_noaudio%~x1"
echo. & pause & exit

:Option_2
set "tmp=%temp%\ffinfo.txt"
"%app%" -i "%~1" >"%tmp%" 2>&1
findstr /C:"Audio:" /C:"title" "%tmp%" | findstr /V "Subtitle" || (echo  ^(no audio found^))
:: detect multiple audio
findstr /C:"Audio:" "%tmp%" | findstr /N "Audio:" | find "2:" >nul && (set "multi=1") || (set "multi=0")
del "%tmp%"
set track=0
if "%multi%"=="1" (
    echo.
    set /p track="Select track number (0 = default): "
)
echo.
echo  [1] Save original
echo  [2] Save as MP3
echo.
CHOICE /C 12 /M "Your choice?:" >nul 2>&1
if errorlevel 2 goto Option_2_1
if errorlevel 1 goto Option_2_2
exit
:Option_2_1
"%app%" -hide_banner -i %1 -map 0:a:%track% -c:a copy -vn "%~dpn1_audio_%track%%~x1"
echo. & pause & exit
:Option_2_2
"%app%" -hide_banner -i %1 -map 0:a:%track% -c:a libmp3lame -q:a 0 -vn "%~dpn1_audio_%track%.mp3"
echo. & pause & exit

:Option_3
"%app%" -hide_banner -i %1 -vf "fps=15,scale=320:-1:flags=lanczos" "%~dpn1.gif"
echo. & pause & exit

:Option_4
echo. & "%app%" -i %1 2>&1 | find "Duration" & echo.
set /p start=Start time (e.g. 00:00:03): 
if "%start%"=="" set start=00:00:00
set /p end=End time (e.g. 00:00:30): 
if "%end%"=="" ("%app%" -hide_banner -i %1 -ss %start% -c copy "%~dpn1_cut%~x1") else ("%app%" -hide_banner -i %1 -ss %start% -to %end% -c copy "%~dpn1_cut%~x1")
echo. & pause & exit

:Option_5
"%app%" -hide_banner -i %1 -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2.0[a]" -map "[v]" -map "[a]" "%~dpn1_fast%~x1"
echo. & pause & exit

:Option_6
"%app%" -hide_banner -i %1 -filter_complex "[0:v]setpts=2.0*PTS[v];[0:a]atempo=0.5[a]" -map "[v]" -map "[a]" "%~dpn1_slow%~x1"
echo. & pause & exit

:Option_7
"%app%" -hide_banner -i %1 -c:v libx264 -crf 23 -preset fast -c:a copy "%~dpn1_1080p%~x1"
echo. & pause & exit

:Option_8
"%app%" -hide_banner -i %1 -vf "transpose=1" -c:v libx264 -crf 18 -preset veryfast -c:a copy "%~dpn1_R%~x1"
echo. & pause & exit

:Option_9
"%app%" -hide_banner -i %1 -vf "transpose=2" -c:v libx264 -crf 18 -preset veryfast -c:a copy "%~dpn1_L%~x1"
echo. & pause & exit

:MultiFile
if "%~x1"=="" echo  NOTICE: first argument is likely a folder or has no extension. & echo.
chcp 65001 >nul
pushd "%~dp1"
echo  [1] Merge %count% files
echo  [2] Create slideshow with %count% IMG files
echo  [3] Add "%~nx1" as audio track to "%~nx2"
echo.
CHOICE /C 123 /M "Your choice?:" >nul 2>&1
if errorlevel 3 goto Moption_3
if errorlevel 2 goto Moption_2
if errorlevel 1 goto Moption_1
exit
:Moption_1
(for %%i in (%*) do @echo file '%%~fi') > "listfile.txt"
"%app%" -hide_banner -f concat -safe 0 -i "listfile.txt" -c copy -movflags +faststart "MergeOutput_%random%.mp4"
del listfile.txt & echo. & pause & exit
:Moption_2
(for %%i in (%*) do echo file '%%~fi' & echo duration 2) > "listfile.txt"
"%app%" -hide_banner -f concat -safe 0 -i "listfile.txt" -vf "fps=1,scale=1280:-2,format=yuv420p" -r 30 "Slideshow_%random%.mp4"
del listfile.txt & echo. & pause & exit
:Moption_3
"%app%" -hide_banner -i "%~2" -i "%~1" -c:v copy -c:a copy -map 0:v:0 -map 1:a:0 "%~n2_with_audio%~x2"
echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\FFmpeg Tools.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,115'; $s.Save()"
echo. & echo  Shortcut 'FFmpeg Tools.lnk' created. & echo. & timeout 2 & exit

:github
set "repo=%~1"
set "filter=%~2"
set "manual_url=%~3"
set "latest_version="
set "url="
set "filename="
set "server_date="

set "ps_cmd=$ErrorActionPreference='SilentlyContinue'; $r=Invoke-RestMethod 'https://api.github.com/repos/%repo%/releases'; if(!$r){exit}; $rel = $r | Where-Object { !$_.prerelease -and ($_.assets.name -like '%filter%') } | Select-Object -First 1; if(!$rel){exit}; $a=$rel.assets | Where-Object { $_.name -like '%filter%' } | Select-Object -First 1; echo $rel.tag_name; echo $a.browser_download_url; echo $a.name; echo ([datetime]$rel.published_at).ToString('dd.MM.yyyy')"
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