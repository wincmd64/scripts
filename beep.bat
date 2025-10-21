:: Adds hourly voice notification or sound signal to task scheduler
:: by github.com/wincmd64

@echo off
chcp 1251 >nul

schtasks /query /tn "wincmd64beep" >nul 2>&1
if %errorlevel% == 0 (echo. & echo  Current status: active) else (echo. & echo  Current status: inactive)

echo.
echo  [1] Enable voice notification of time every hour  
echo  [2] Turn on the sound signal every hour
echo  [3] Turn off auto-repeat
echo  [0] Exit
echo. 
CHOICE /C 1230 /M "Your choice?:" >nul 2>&1
if errorlevel 4 exit
if errorlevel 3 goto Option_3
if errorlevel 2 goto Option_2
if errorlevel 1 goto Option_1
exit

:Option_1
set /p "custom_text=Enter location text [current time]: "
if "%custom_text%"=="" set "custom_text=current time"

set "vbs=%temp%\hourly_speak.vbs"
> "%vbs%" (
  echo Dim Voice
  echo On Error Resume Next
  echo Set Voice = CreateObject^("Sapi.spVoice"^)
  echo Voice.Speak "%custom_text%:" ^& Left^(Time, 5^)
  echo Set Voice = Nothing
)
schtasks /delete /tn "wincmd64beep" /f >nul 2>&1
schtasks /create /tn "wincmd64beep" /tr "wscript.exe \"%vbs%\"" /sc hourly /st 00:00
echo. & pause & exit

:Option_2
set /p "sound_file=Enter sound file path [C:\Windows\Media\Windows Ding.wav]: "
if "%sound_file%"=="" set "sound_file=C:\Windows\Media\Windows Ding.wav"

set "vbs=%temp%\hourly_beep.vbs"
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
schtasks /delete /tn "wincmd64beep" /f >nul 2>&1
schtasks /create /tn "wincmd64beep" /tr "wscript.exe \"%vbs%\"" /sc hourly /st 00:00
echo. & pause & exit

:Option_3
schtasks /delete /tn "wincmd64beep" /f
echo. & pause & exit
