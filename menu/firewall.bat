:: Adds "Firewall" menu entry to the Explorer context menu (hold Shift to activate)
::   [area] .exe files
:: by github.com/wincmd64

:: Block   - outbound block rule for this exact program path (rule group: wincmd64)
:: Unblock - removes every outbound Block rule for this path, even ones created by hand
:: The exe path is passed to PowerShell as a separate last argument (never as code), so paths are safe.


@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

:: PowerShell snippets. Rules for them: single quotes only (no double quotes), no ampersand, pipe,
:: angle brackets, caret or percent signs, because cmd sees this text unquoted when reg add runs.
:: HEAD:    takes the path from the last argument, re-launches itself elevated if needed
:: FIND:    collects all outbound Block rules attached to that program path
:: BLOCK:   creates the rule unless an enabled one already exists
:: UNBLOCK: removes the rules found
set "PS_HEAD=$p=[Environment]::GetCommandLineArgs()[-1]; if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(544)){Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList ([Environment]::CommandLine.Substring([Environment]::CommandLine.IndexOf(' ')+1)); exit};"
set "PS_FIND=$r=@(); foreach($f in @(Get-NetFirewallApplicationFilter -Program $p -ErrorAction SilentlyContinue)){$r+=@(Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $f).Where({$_.Direction -eq 'Outbound' -and $_.Action -eq 'Block'})};"
set "PS_BLOCK=if(@($r.Where({$_.Enabled -eq 'True'})).Count -eq 0){New-NetFirewallRule -DisplayName ([IO.Path]::GetFileNameWithoutExtension($p)) -Group wincmd64 -Enabled True -Direction Outbound -Action Block -Program $p};"
set "PS_UNBLOCK=if($r.Count){Remove-NetFirewallRule -InputObject $r};"

reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall" /v "MUIVerb" /d "Firewall" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall" /v "Icon" /d "%%ProgramFiles%%\Windows Defender\EppManifest.dll,4" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall" /v "Extended" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall" /v "SubCommands" /f

reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\01block" /v "MUIVerb" /d "Block" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\01block" /v "Icon" /d "imageres.dll,100" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\01block" /v "HasLUAShield" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\01block\command" /ve /d "powershell -NoProfile -NoLogo -WindowStyle Hidden -Command \"%PS_HEAD% %PS_FIND% %PS_BLOCK% #\" \"%%1\"" /f

reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\02allow" /v "MUIVerb" /d "Unblock" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\02allow" /v "Icon" /d "imageres.dll,101" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\02allow" /v "HasLUAShield" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\02allow\command" /ve /d "powershell -NoProfile -NoLogo -WindowStyle Hidden -Command \"%PS_HEAD% %PS_FIND% %PS_UNBLOCK% #\" \"%%1\"" /f

reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\03rules" /v "MUIVerb" /d "Outbound rules" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\03rules" /v "Icon" /d "FirewallControlPanel.dll" /f
reg add "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall\shell\03rules\command" /ve /d "mmc WF.msc" /f && (color A & timeout 2 & exit) || (echo. & pause & exit)

:undo
reg delete "HKCU\Software\Classes\exefile\shell\wincmd64_Firewall" /f && (color A & timeout 2) || (echo. & pause)
