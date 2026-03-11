:: Adds hourly voice notification or sound signal to task scheduler
:: by github.com/wincmd64

@echo off
chcp 1251 >nul

set "vbs=%temp%\hourly_play.vbs"
set "status=inactive"

:: Check: if a task is available in the scheduler
schtasks /query /tn "wincmd64beep" >nul 2>&1
if %errorlevel% == 0 (
    set "status=active"
    :: Check: if the .VBS file exists
    if not exist "%vbs%" (set "status=active ^(VBS missing!^)")
)
echo.
echo      Current status: %status%
echo.
echo  [1] Enable voice notification of time every hour  
echo  [2] Turn on the sound signal every hour
echo  [3] Turn off auto-repeat
echo  [0] Exit
echo. 
if "%status%"=="inactive" (
    CHOICE /C 120 /M "Your choice?:" >nul 2>&1
    if errorlevel 3 exit
    if errorlevel 2 goto Option_2
    if errorlevel 1 goto Option_1
) else (
    CHOICE /C 1230 /M "Your choice?:" >nul 2>&1
    if errorlevel 4 exit
    if errorlevel 3 goto Option_3
    if errorlevel 2 goto Option_2
    if errorlevel 1 goto Option_1
)
exit

:Option_1
set /p "custom_text=Enter text before time (optional): "
if "%custom_text%"=="" (set "speak_text=Left^(Time, 5^)") else (set "speak_text="%custom_text%:" ^& Left^(Time, 5^)")
> "%vbs%" (
  echo Dim Voice
  echo On Error Resume Next
  echo Set Voice = CreateObject^("Sapi.spVoice"^)
  echo Voice.Speak %speak_text%
  echo Set Voice = Nothing
)
goto CREATE_TASK

:Option_2
set /p "sound_file=Enter sound file path [C:\Windows\Media\Windows Ding.wav]: "
if "%sound_file%"=="" set "sound_file=C:\Windows\Media\Windows Ding.wav"
> "%vbs%" (
  echo Dim o: Set o = CreateObject^("wmplayer.ocx"^)
  echo o.url = "%sound_file%"
  echo ' wait for playback to complete, but no more than 3 seconds ^(60 * 50ms = 3000ms^)
  echo For i = 1 To 60
  echo   If o.playstate = 1 Then Exit For
  echo   WScript.Sleep 50
  echo Next
  echo o.close: Set o = Nothing
)
goto CREATE_TASK

:Option_3
schtasks /delete /tn "wincmd64beep" /f
if exist "%vbs%" del "%vbs%"
echo. & pause & exit

:CREATE_TASK
schtasks /delete /tn "wincmd64beep" /f >nul 2>&1
schtasks /create /tn "wincmd64beep" /tr "wscript.exe \"%vbs%\"" /sc hourly /st 00:00
echo. & pause & exit
