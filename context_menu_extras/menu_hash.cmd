:: Adds "Hash" menu entry to the Explorer context menu (hold Shift to activate)
::   [area] all files
:: by github.com/wincmd64

@ECHO OFF
:: Use /u to undo changes
if /i "%1"=="/u" goto undo

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash" /v "MUIVerb" /d "Hash" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash" /v "Icon" /d "gpedit.dll" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash" /v "Extended" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash" /v "SubCommands" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\01_SHA1" /v "MUIVerb" /d "SHA1" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\01_SHA1" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\01_SHA1\command" /ve /d "powershell.exe -NoP -C \"($h = (Get-FileHash -LiteralPath '%%1' -Algorithm SHA1).Hash) ^| Set-Clipboard; Write-Host $h `n`n SHA1 copied!`n ; pause\"" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\02_SHA256" /v "MUIVerb" /d "SHA256" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\02_SHA256" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\02_SHA256\command" /ve /d "powershell.exe -NoP -C \"($h = (Get-FileHash -LiteralPath '%%1' -Algorithm SHA256).Hash) ^| Set-Clipboard; Write-Host $h `n`n SHA256 copied!`n ; pause\"" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\03_SHA384" /v "MUIVerb" /d "SHA384" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\03_SHA384" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\03_SHA384\command" /ve /d "powershell.exe -NoP -C \"($h = (Get-FileHash -LiteralPath '%%1' -Algorithm SHA384).Hash) ^| Set-Clipboard; Write-Host $h `n`n SHA384 copied!`n ; pause\"" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\04_SHA512" /v "MUIVerb" /d "SHA512" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\04_SHA512" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\04_SHA512\command" /ve /d "powershell.exe -NoP -C \"($h = (Get-FileHash -LiteralPath '%%1' -Algorithm SHA512).Hash) ^| Set-Clipboard; Write-Host $h `n`n SHA512 copied!`n ; pause\"" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\05_MD5" /v "MUIVerb" /d "MD5" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\05_MD5" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\05_MD5\command" /ve /d "powershell.exe -NoP -C \"($h = (Get-FileHash -LiteralPath '%%1' -Algorithm MD5).Hash) ^| Set-Clipboard; Write-Host $h `n`n MD5 copied!`n ; pause\"" /f

reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\06_All" /v "MUIVerb" /d "Show all" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\06_All" /v "Icon" /d "powershell.exe" /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\06_All" /v "CommandFlags" /t REG_DWORD /d 32 /f
reg add "HKCU\Software\Classes\*\shell\wincmd64_Hash\shell\06_All\command" /ve /d "powershell -NoP -C \"Get-FileHash -LiteralPath '%%1' -Algorithm SHA1 ^| Format-List; Get-FileHash -LiteralPath '%%1' -Algorithm SHA256 ^| Format-List; Get-FileHash -LiteralPath '%%1' -Algorithm SHA384 ^| Format-List; Get-FileHash -LiteralPath '%%1' -Algorithm SHA512 ^| Format-List; Get-FileHash -LiteralPath '%%1' -Algorithm MD5 ^| Format-List; pause\"" /f

color A & timeout 1 & exit

:undo
reg delete "HKCU\Software\Classes\*\shell\wincmd64_Hash" /f
color A & timeout 1
