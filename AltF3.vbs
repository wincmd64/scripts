' Use it in wincmd.ini like:
'    [Configuration]
'    Viewer="wscript.exe "%commander_path%\AltF3.vbs" "%1""

Option Explicit

If WScript.Arguments.Count = 0 Then WScript.Quit

Dim filePath, fso, shell, env, ext, rawExt, targetApp, targetArgs, targetUrl
filePath = WScript.Arguments(0)

Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
Set env   = shell.Environment("Process")

' ======================================================================
' USER CONFIGURATION
' Format: Array( Executable/Command, Extensions_List, Download_URL )
'
' Special extension keys:
'   "folder" or "\" -> Rule for directories
'   "*"             -> Fallback rule (must be at the bottom)
' ======================================================================
Dim Config
Config = Array( _
    Array("%COMMANDER_EXE% /S=L:Pvisualspace", "folder \", ""), _
    Array("PowerShell_ISE.exe",               ".ps1", ""), _
    Array("mspaint.exe",                      ".bmp .dib .jpg .jpeg .jpe .jfif .gif .tif .tiff .png .heic .hif .avif .webp .paint", ""), _
    Array("notepad.exe",                      ".txt .md", ""), _
    Array("%COMMANDER_PATH%\Plugins\Total7zip\7-ZipPort\7-ZipPortable.exe", ".vhd .vhdx", ""), _
    Array("powershell.exe -NoP -NoE -Ep Bypass -File ""%COMMANDER_PATH%\Utils\MsiViewer.ps1""", ".msi", ""), _
    Array("mp3DirectCut.exe",                 ".mp3 .cue", "https://mpesch3.de"), _
    Array("gfie.exe",                         ".dll .ico", "https://greenfishsoftware.org"), _
    Array("csvlens.exe",                      ".csv",      "https://github.com/ys-l/csvlens"), _
    Array("wordpad.exe",                      ".rtf",      "https://github.com/wincmd64/blog/wiki/Как-вернуть-WordPad-в-Windows-11"), _
    Array("ISIDE.exe",                        ".iss",      "https://jrsoftware.org/isdl.php"), _
    Array("fmp.exe",                          ".swf",      "https://www.eolsoft.com/freeware/flash_movie_player"), _
    Array("notepad++.exe",                    ".log",      "https://notepad-plus-plus.org"), _
    Array("%COMMANDER_EXE% /S=L",             "*", "") _
)

' ======================================================================
' CORE LOGIC
' ======================================================================

' Determine item type (Folder vs File)
If fso.FolderExists(filePath) Then
    ext = "folder"
Else
    rawExt = fso.GetExtensionName(filePath)
    If rawExt <> "" Then
        ext = "." & LCase(rawExt)
    Else
        ext = ""
    End If
End If

' Iterate through configuration rules
Dim rule, appCmd, extsList, url, resolvedExe
For Each rule In Config
    appCmd   = rule(0)
    extsList = LCase(rule(1))
    url      = rule(2)

    If MatchExtension(ext, extsList) Then
        ' Expand environment variables in command string
        appCmd = shell.ExpandEnvironmentStrings(appCmd)

        ' Split command into executable and extra arguments
        ParseCommand appCmd, targetApp, targetArgs

        ' Resolve application path
        resolvedExe = ResolveAppPath(targetApp)

        If resolvedExe <> "" Then
            ' Launch executable with arguments and current target file
            RunApp resolvedExe, targetArgs, filePath
        Else
            ' Executable missing -> Handle error / download prompt
            HandleMissingApp ext, targetApp, url
        End If
    End If
Next

' ======================================================================
' HELPER FUNCTIONS
' ======================================================================

Function MatchExtension(currentExt, list)
    MatchExtension = False
    If list = "*" Then
        MatchExtension = True
        Exit Function
    End If

    Dim item
    For Each item In Split(list, " ")
        item = Trim(item)
        If item <> "" Then
            If currentExt = "folder" And (item = "folder" Or item = "\") Then
                MatchExtension = True
                Exit Function
            ElseIf currentExt <> "folder" And currentExt = item Then
                MatchExtension = True
                Exit Function
            End If
        End If
    Next
End Function

Sub ParseCommand(cmd, ByRef exe, ByRef args)
    cmd = Trim(cmd)
    
    ' 1. Handled when command starts with explicit quotes
    If Left(cmd, 1) = """" Then
        Dim qEnd
        qEnd = InStr(2, cmd, """")
        If qEnd > 0 Then
            exe  = Mid(cmd, 2, qEnd - 2)
            args = Trim(Mid(cmd, qEnd + 1))
        Else
            exe  = Replace(cmd, """", "")
            args = ""
        End If
    ' 2. Handled when unquoted string matches an existing path directly
    ElseIf fso.FileExists(cmd) Then
        exe  = cmd
        args = ""
    ' 3. Handled when unquoted string contains arguments
    Else
        Dim exePos
        exePos = InStr(LCase(cmd), ".exe")
        If exePos > 0 Then
            exe  = Trim(Left(cmd, exePos + 3))
            args = Trim(Mid(cmd, exePos + 4))
        Else
            Dim spacePos
            spacePos = InStr(cmd, " ")
            If spacePos > 0 Then
                exe  = Left(cmd, spacePos - 1)
                args = Mid(cmd, spacePos + 1)
            Else
                exe  = cmd
                args = ""
            End If
        End If
    End If
End Sub

Function ResolveAppPath(exe)
    ' 1. Absolute / Direct Path
    If fso.FileExists(exe) Then
        ResolveAppPath = exe
        Exit Function
    End If

    ' 2. Search in system PATH
    Dim pathVar, paths, p, fullPath
    pathVar = env("PATH")
    paths   = Split(pathVar, ";")
    For Each p In paths
        p = Trim(p)
        If p <> "" Then
            If Right(p, 1) <> "\" Then p = p & "\"
            fullPath = p & exe
            If fso.FileExists(fullPath) Then
                ResolveAppPath = fullPath
                Exit Function
            End If
        End If
    Next

    ' 3. Windows App Paths Registry Fallback (WordPad, etc.)
    On Error Resume Next
    Dim regPath
    regPath = shell.RegRead("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" & exe & "\")
    On Error GoTo 0

    If regPath <> "" Then
        regPath = shell.ExpandEnvironmentStrings(regPath)
        regPath = Replace(regPath, """", "")
        If fso.FileExists(regPath) Then
            ResolveAppPath = regPath
            Exit Function
        End If
    End If

    ResolveAppPath = ""
End Function

Sub RunApp(exe, extraArgs, targetFile)
    Dim finalCmd
    finalCmd = """" & exe & """"
    If extraArgs <> "" Then finalCmd = finalCmd & " " & extraArgs
    finalCmd = finalCmd & " """ & targetFile & """"

    shell.Run finalCmd, 1, False
    WScript.Quit
End Sub

Sub HandleMissingApp(extName, appName, downloadUrl)
    If downloadUrl <> "" Then
        Dim res
        res = MsgBox("Associated program (" & appName & ") for extension '" & extName & "' was not found." & vbCrLf & _
                     "Open the website to download it?", 36, "Error")
        If res = 6 Then
            shell.Run downloadUrl, 1, False
        End If
    Else
        MsgBox "Associated program (" & appName & ") for extension '" & extName & "' was not found.", 16, "Error"
    End If
    WScript.Quit
End Sub
