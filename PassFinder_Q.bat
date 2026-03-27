:: Tries to open an archive using a list of passwords.
::   If no local password list <archive_name>.txt is found, downloads a default list from SecLists on GitHub.
::   NOTICE: filenames containing the character "!" are not supported.
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%S parameter

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal enabledelayedexpansion

:: [SETTINGS]
set "dir=%~dp0"
cd /d "%dir%"

:7z
for /f "tokens=* delims=" %%a in ('where 7z.exe 2^>nul') do set "app=%%a"
if not defined app if exist "C:\Program Files\7-Zip\7z.exe" set "app=C:\Program Files\7-Zip\7z.exe"
if not defined app if exist "%dir%7z.exe" set "app=%dir%7z.exe"
if exist "%app%" goto skip_7z
echo. & echo  "7z.exe" not found. & echo  Try to download it to "%dir%" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ip7z/7zip/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.msi'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try: winget install 7zip.7zip & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    curl.exe -fRL# "%url%" -o "%temp%\%filename%"
    if errorlevel 1 (color C & echo. & echo  Error: download failed. & echo. & pause & exit /b)
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
msiexec /a "%temp%\%filename%" /qn TARGETDIR="%temp%\7z"
:: finds 7z.exe+7z.dll and move it
for /r "%temp%\7z" %%F in (7z.exe 7z.dll) do (if exist "%%~fF" move /y "%%~fF" "%dir%" >nul)
rd /s /q "%temp%\7z"
goto 7z

:skip_7z
cls
TITLE %app%
:: escape colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

set count=0
for %%A in (%*) do set /a count+=1
if %count% equ 0 (echo. & echo  No objects selected & echo. & pause & exit)
echo. & echo  Try to open archive using a password list?
if %count% equ 1 (echo  Target: %* & echo.) else (echo  Target: %count% files & echo.)
if "%~x1"=="" echo  %ESC%[31m NOTICE: first argument is likely a folder or has no extension.%ESC%[0m & echo.
pause

set "total_files=0"
for %%A in (%*) do set /a total_files+=1
echo. & echo  Files in queue: %total_files% & echo. & echo.
set "current_idx=0"
for %%F in (%*) do (
    set /a current_idx+=1
    echo  [^!current_idx^!/%total_files%] Processing: "%%~nxF"
    call :process_file "%%~F"
    echo.
)
echo. & echo  %ESC%[7mAll tasks finished%ESC%[0m & echo. & pause & exit

:process_file
set "target=%~1"
set "pw_list=%~dpn1.txt"

if not exist "!pw_list!" (
    set "pw_list=%temp%\default-passwords.txt"
    if not exist "!pw_list!" (
        echo  Downloading default password list...
        powershell -C "iwr 'https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Passwords/Default-Credentials/default-passwords.txt' -OutFile '!pw_list!'"
    )
)

echo  Using list: "!pw_list!"
set /a dot_count=0

for /F "usebackq delims=" %%P in ("!pw_list!") do (
    if not "%%P"=="" (
        set /a dot_count+=1
        <nul set /p "=." 
        if !dot_count! EQU 50 (echo. & set dot_count=0)
        
        "%app%" t -p"%%P" "!target!" >nul 2>&1
        if !errorlevel! EQU 0 (
            echo. & echo.
            echo   %ESC%[42mPASSWORD FOUND: %%P%ESC%[0m
            echo.
            goto :file_done
        )
    )
)
echo. & echo.
echo   %ESC%[41mPASSWORD NOT FOUND%ESC%[0m
echo.

:file_done
exit /b

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Password Finder.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,47'; $s.Save()"
echo. & echo  Shortcut 'Password Finder.lnk' created. & echo. & timeout 2
