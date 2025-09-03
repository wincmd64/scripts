:: Adds "Add folder to PATH" entry to the Explorer context menu (hold Shift to activate)
::   [area] dirs
:: by github.com/wincmd64

@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

:: https://nhutils.ru/blog/skript-dobavleniya-puti-v-path/
echo var wsh_shell=WScript.CreateObject("WScript.Shell");var path=wsh_shell.ExpandEnvironmentStrings(WScript.Arguments.Unnamed(0));var v="";try{v=wsh_shell.RegRead("HKCU\\Environment\\Path");}catch(e){}if(v!=""){for(var i=new Enumerator(v.split(";"));!i.atEnd();i.moveNext())if(path.toUpperCase()==i.item().toUpperCase()){WScript.Echo("���� ��� ������������ � Path.");WScript.Quit(0);}if(v.charAt(v.length-1)!=";")v+=";";}v+=path;if(wsh_shell.Run("setx Path \""+v+"\"",0,true)!=0)WScript.Echo("������ ��� ���������� ���� (setx).");else WScript.Echo("���� �������� � Path."); > "%temp%\folder2path.js"

reg add "HKCU\Software\Classes\Directory\shell\wincmd64_path" /v "MUIVerb" /d "Add folder to PATH" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_path" /v "Icon" /d "shell32.dll,45" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_path" /v "Extended" /f
reg add "HKCU\Software\Classes\Directory\shell\wincmd64_path\command" /ve /d "wscript \"%temp%\folder2path.js\" ""%%1""" /f

color 27 & timeout 1 & exit

:undo
reg delete "HKCU\Software\Classes\Directory\shell\wincmd64_path" /f
del "%temp%\folder2path.js"
color 27 & timeout 1
