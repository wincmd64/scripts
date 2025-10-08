:: Tries to open a archive using a list of passwords.
::   If no local password list <archive_name>.txt is found, downloads a default list from SecLists on GitHub.
:: by github.com/wincmd64

:: Usage:
:: Create a shortcut to this .bat file in the Shell:SendTo folder
:: or button in TotalCmd with the %P%N parameter

:: Command line arguments:
:: /s - create shortcut in Shell:SendTo folder

@echo off
setlocal enabledelayedexpansion

for /f "tokens=* delims=" %%a in ('where 7z.exe 2^>nul') do set "app=%%a"
if not defined app if exist "C:\Program Files\7-Zip\7z.exe" set "app=C:\Program Files\7-Zip\7z.exe"
if not exist "%app%" (echo. & echo  "7z.exe" not found. & echo  Download it from: https://7-zip.org & echo. & pause & exit) else (TITLE %app%)

:: arguments
if /i "%~1"=="/s" (if "%~2"=="" goto :shortcut)

if "%~1"=="" (echo. & echo  No objects selected & echo. & pause & exit)
:: e.g. "secret.zip" > "secret.txt"
set "pw_list=%~dpn1.txt"
if not exist "%pw_list%" (
    echo. & echo  Use default-passwords.txt ^(will be downloaded^) to search password for "%~nx1" ? & echo. & pause
    powershell -C "iwr 'https://raw.githubusercontent.com/danielmiessler/SecLists/refs/heads/master/Passwords/Default-Credentials/default-passwords.txt' -OutFile '%pw_list%'"
    if not exist "%pw_list%" (echo. & echo  Failed to get password list. & pause & exit)
) else (
    echo. & echo  Use "%~n1.txt" to search password for "%~nx1" ? & echo. & pause
)

echo. & echo  Searching passwords from: "%~n1.txt"
set /a count=0
for /F "usebackq delims=" %%P in ("%pw_list%") do (
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
powershell -NoP -NoL -Ep Bypass -c ^
"$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('SendTo') + '\Password Finder.lnk'); ^
$s.TargetPath = '%~f0'; $s.IconLocation = 'shell32.dll,47'; $s.Save()"
echo. & echo  Shortcut 'Password Finder.lnk' created. & echo. & pause & exit
