:: Tries to open an archive using a list of passwords.
::   If no local password list <archive_name>.txt is found, downloads a default list from SecLists on GitHub.
:: by github.com/wincmd64

:: [USAGE]
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%N parameter

:: [NOTICE]
:: Filenames containing the character "!" are not supported.

:: [COMMAND LINE ARGUMENTS]
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal enabledelayedexpansion

:start
for /f "tokens=* delims=" %%a in ('where 7z.exe 2^>nul') do set "app=%%a"
if not defined app if exist "C:\Program Files\7-Zip\7z.exe" set "app=C:\Program Files\7-Zip\7z.exe"
if not defined app if exist "%~dp07z.exe" set "app=%~dp07z.exe"
if exist "%app%" goto skip_download
echo. & echo  "7z.exe" not found. & echo  Try to download it to "%~dp0" ? & echo. & pause
:: getting the latest version via the GitHub API
echo. & echo  Getting the latest version...
set "ps_cmd=$r=Invoke-RestMethod 'https://api.github.com/repos/ip7z/7zip/releases/latest'; $a=$r.assets|?{$_.name -like '*x64.msi'}|select -f 1; echo $a.browser_download_url; echo $a.name"
for /f "tokens=*" %%a in ('powershell -command "%ps_cmd%"') do (if not defined url (set "url=%%a") else (set "filename=%%a"))
if "%url%"=="" (echo  Error: Could not find download URL. & echo  Try: winget install 7zip.7zip & pause & exit /b)
if not exist "%temp%\%filename%" (
    echo. & echo  Downloading: %filename%
    powershell -command "Invoke-WebRequest -Uri '%url%' -OutFile '%temp%\%filename%'"
) else (
    echo. & echo  Downloading: %filename% ^(already in TEMP^)
)
echo. & echo  Extracting ...
md "%temp%\7z"
if exist "%temp%\%filename%" (msiexec /a "%temp%\%filename%" /qn TARGETDIR="%temp%\7z") else (echo. & echo  %filename% not found. & echo. & pause)
:: finds 7z.exe+7z.dll and move it
for /r "%temp%\7z" %%F in (7z.exe 7z.dll) do (if exist "%%~fF" move /y "%%~fF" "%~dp0" >nul)
rd /s /q "%temp%\7z"
echo. & echo. & echo  DONE. & echo. & pause & goto start

:skip_download
cls
TITLE %app%
:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto shortcut)

if "%~1"=="" (echo. & echo  No objects selected & echo. & pause & exit)
:: e.g. "secret.zip" > "secret.txt"
set "pw_list=%~dpn1.txt"
if "%~x1"=="" echo. & echo     NOTICE: first argument is likely a folder or has no extension.
if not exist "!pw_list!" (
    echo. & echo  Use default-passwords.txt ^(will be downloaded^) to search password for "%~nx1" ? & echo. & pause
    set "pw_list=%temp%\default-passwords.txt"
    powershell -C "iwr 'https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Passwords/Default-Credentials/default-passwords.txt' -OutFile '!pw_list!'"
    if not exist "!pw_list!" (echo. & echo  Failed to get password list. & pause & exit)
) else (
    echo. & echo  Use "%~n1.txt" to search password for "%~nx1" ? & echo. & pause
)

echo. & echo  Searching passwords from: "!pw_list!"
set /a count=0
for /F "usebackq delims=" %%P in ("!pw_list!") do (
    if not "%%P"=="" (
        set /a count+=1
        set /p "=." <nul
        if !count! EQU 80 (
            echo.
            set count=0
        )
        
        "%app%" t -p"%%P" "%~1" >nul 2>&1
        if !errorlevel! EQU 0 (
            echo. & echo.
            echo  ==============================
            echo   PASSWORD FOUND: %%P
            echo  ==============================
            echo.
            pause
            goto :eof
        )
    )
)
echo. & echo. & echo  Finished. No matching password found. & echo. & pause & exit

:shortcut
powershell -NoP -C ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Password Finder.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,47'; $s.Save()"
echo. & echo  Shortcut 'Password Finder.lnk' created. & echo. & timeout 2
