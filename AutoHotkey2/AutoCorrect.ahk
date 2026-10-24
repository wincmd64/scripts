#Requires AutoHotkey v2.0
#SingleInstance Force

; ================================================================
;  AutoCorrect (Mahou's "Autoreplace" feature, reimplemented in AHK v2)
;
;  AS_dict.txt format:
;      ->trigger
;      ====>replacement<====
;
;  Flow: InputHook passively watches typed characters. Letters go into a
;  word buffer; at a word boundary (any non-letter char) the buffer is
;  looked up in the dictionary and replaced if found.
;
;  Meant to be #Include-d from a main script, so all paths are resolved
;  relative to THIS file, not A_ScriptDir (which points to the main script).
; ================================================================

; ---------------- SETTINGS ----------------

; Folder this file lives in (works regardless of where it's #Include-d from)
global ScriptDir := ""
SplitPath(A_LineFile, , &ScriptDir)

; Dictionary file. Get AS_dict.txt from: https://gitea.com/BladeMight/Mahou/releases/download/latest-commit/AS_Dict.zip
global DictPath := ScriptDir "\AS_dict.txt"

; Sound played on a successful replacement. Silently skipped if missing. Get switch.wav from: https://pixeldrain.com/u/VURSv53s
global SwitchSoundPath := ScriptDir "\switch.wav"

; Cache file: a faster-to-parse copy of AS_dict.txt (one line per entry
; instead of two, no ->/====>/<==== markers). Rebuilt automatically
; whenever AS_dict.txt is newer than the cache.
global CachePath := ScriptDir "\AS_dict.cache"

; Exceptions: triggers listed here (one per line, "#" starts a comment) are
; never auto-replaced, even if they exist in AS_dict.txt. Lines get added
; via the "Add to exceptions" button in the last-replacement window.
global ExceptionsPath := ScriptDir "\AS_exceptions.txt"

; App exceptions: process names (one per line, e.g. TOTALCMD64.EXE, case-
; insensitive, "#" starts a comment) in which AutoCorrect never replaces
; anything. Lines get added via the "Disable in ..." button in the
; last-replacement window.
global ExceptionsAppsPath := ScriptDir "\AS_exceptions_apps.txt"

; Characters treated as part of a word - same idea as en/second in
; CapsConvert.ahk, but combined (RU+UA) since this only affects which
; letters keep a word buffering, not which layout is active.
global LatinLetters := "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm"
global CyrillicLetters := "ЙЦУКЕНГШЩЗХЪЇФЫІВАПРОЛДЖЭЄЯЧСМИТЬБЮЁҐйцукенгшщзхъїфыівапролджэєячсмитьбюёґ" ; RU+UA combined
global WordCharsPattern := "[" LatinLetters CyrillicLetters "'’\-]"

; Language names (as returned by Windows for LOCALE_SENGLANGUAGE) that use
; the Cyrillic alphabet - used to auto-detect which installed keyboard
; layout to switch to. Extend if you have other Cyrillic layouts installed.
global CyrillicLanguageNames := ["Russian", "Ukrainian"]

; Hotkey to toggle AutoCorrect on/off (shows a tooltip near the cursor for 2 sec)
; Set to "" to disable the hotkey entirely.
global ToggleHotkey := "^!+F12" ; Ctrl+Alt+Shift+F12

; Hotkey to show a window with details of the last replacement
; Set to "" to disable.
global ShowLastReplacementHotkey := "^!+F11" ; Ctrl+Alt+Shift+F11

; Undo window: if Backspace is the very first key pressed within this many
; milliseconds after a replacement, the replacement is reverted to the
; originally typed word (the boundary char is eaten by that Backspace, like
; in Word's autocorrect). Set to 0 to disable.
global UndoWindowMs := 2000

; ---------------- END SETTINGS ----------------

global Dict := Map()
global WordBuf := ""
global BufHwnd := 0  ; window the current WordBuf was typed in

; State of the last replacement, used for undo (UndoTick = 0 -> nothing to undo)
global UndoTick := 0
global UndoOriginal := ""
global UndoReplacement := ""

; ---------------------------------------------------------------
; Keyboard layout discovery - which installed HKL to switch to per script
; (this is about the actual OS layout, not the character set, so it still
; needs to look at what's really installed rather than a static string)
; ---------------------------------------------------------------
global AC_InstalledLayouts := AC_GetInstalledLayoutsWithNames()
global ScriptLayoutIDs := BuildScriptLayoutMap(AC_InstalledLayouts)

; HKL -> LOCALE_SENGLANGUAGE name, for every installed keyboard layout
AC_GetInstalledLayoutsWithNames() {
    layouts := Map()
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    if (count > 0) {
        buf := Buffer(count * A_PtrSize)
        DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", buf, "Int")
        Loop count {
            hkl := NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr")
            langID := hkl & 0xFFFF
            nameBuf := Buffer(256)
            layouts[hkl] := DllCall("GetLocaleInfo", "UInt", langID, "UInt", 0x1001, "Ptr", nameBuf, "Int", 256)
                ? StrGet(nameBuf) : "Unknown"
        }
    }
    return layouts
}

; Picks one installed HKL per alphabet ("latin"/"cyrillic"), based on the
; language name reported for each layout.
BuildScriptLayoutMap(layouts) {
    global CyrillicLanguageNames
    result := Map()
    for hkl, name in layouts {
        isCyrillic := false
        for langName in CyrillicLanguageNames {
            if InStr(name, langName) {
                isCyrillic := true
                break
            }
        }
        key := isCyrillic ? "cyrillic" : "latin"
        if !result.Has(key)
            result[key] := hkl
    }
    return result
}

; ---------------------------------------------------------------
; Dictionary loading
; ---------------------------------------------------------------
LoadDictionary(path) {
    global Dict, CachePath, ScriptDir
    Dict.Clear()

    sourceExists := FileExist(path)
    cacheExists := FileExist(CachePath)

    if !sourceExists && !cacheExists {
        answer := MsgBox(
            "AutoCorrect: no dictionary found next to the script.`n`n"
            "Download and unpack AS_dict.txt now (~6 MB)?`n"
            "Source: https://gitea.com/BladeMight/Mahou/releases/download/latest-commit/AS_Dict.zip",
            "AutoCorrect", "YesNo Icon?")
        if (answer != "Yes")
            return
        if !DownloadAndExtractDict() {
            MsgBox("Could not set up the dictionary automatically. AutoCorrect will run with an empty dictionary.",
                "AutoCorrect", "Icon!")
            return
        }
        sourceExists := FileExist(path)
    }

    ; Cache alone is enough - only need AS_dict.txt to build/refresh it.
    useCache := cacheExists && (!sourceExists || FileGetTime(CachePath, "M") >= FileGetTime(path, "M"))
    if useCache {
        LoadFromCache(CachePath)
        return false
    } else {
        LoadFromSource(path)
        BuildCache(CachePath)
        return true
    }
}

; Downloads AS_Dict.zip and unpacks it next to the script, using the
; Shell.Application COM object (no external processes/PowerShell needed).
DownloadAndExtractDict() {
    global ScriptDir
    url := "https://gitea.com/BladeMight/Mahou/releases/download/latest-commit/AS_Dict.zip"
    zipPath := ScriptDir "\AS_Dict.zip"

    TrayTip("AutoCorrect", "Downloading AS_Dict.zip...", 1)
    try {
        Download(url, zipPath)
    } catch as e {
        MsgBox("Download failed:`n" e.Message, "AutoCorrect", "IconX")
        return false
    }

    try {
        shell := ComObject("Shell.Application")
        zipFolder := shell.Namespace(zipPath)
        destFolder := shell.Namespace(ScriptDir)
        if !zipFolder || !destFolder
            throw Error("Could not open the zip file or destination folder")

        ; FOF_NOCONFIRMATION (16) + FOF_SILENT (4) - overwrite without prompts, no UI
        destFolder.CopyHere(zipFolder.Items, 4 | 16)

        ; CopyHere is asynchronous - wait for AS_dict.txt to actually show up
        Loop 100 {
            if FileExist(ScriptDir "\AS_dict.txt")
                break
            Sleep(100)
        }
    } catch as e {
        MsgBox("Extraction failed:`n" e.Message, "AutoCorrect", "IconX")
        try FileDelete(zipPath)
        return false
    }

    try FileDelete(zipPath)
    return FileExist(ScriptDir "\AS_dict.txt") ? true : false
}

; Slow path: parses the original AS_dict.txt format (two lines per entry).
LoadFromSource(path) {
    global Dict
    text := FileRead(path, "UTF-8")
    trigger := ""
    Loop Parse text, "`n", "`r"
    {
        line := A_LoopField
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue

        if (SubStr(line, 1, 2) = "->") {
            trigger := SubStr(line, 3)
        }
        else if (SubStr(line, 1, 5) = "====>") {
            len := StrLen(line)
            if (len > 10)
                Dict[trigger] := SubStr(line, 6, len - 10)
        }
    }
}

; Fast path: one "trigger<0x01>replacement" line per entry.
LoadFromCache(path) {
    global Dict
    text := FileRead(path, "UTF-8")
    Loop Parse text, "`n", "`r"
    {
        line := A_LoopField
        if (line = "")
            continue
        pos := InStr(line, Chr(1))
        if pos
            Dict[SubStr(line, 1, pos - 1)] := SubStr(line, pos + 1)
    }
}

; Writes the current Dict out to CachePath for faster loading next time.
BuildCache(cachePath) {
    global Dict
    try {
        f := FileOpen(cachePath, "w", "UTF-8")
        if !f
            return
        for k, v in Dict
            f.WriteLine(k Chr(1) v)
        f.Close()
    }
}

; ---------------------------------------------------------------
; Exceptions list
; ---------------------------------------------------------------
global Exceptions := Map()      ; triggers that must never be replaced
global ExceptionApps := Map()   ; lower-cased process names where AutoCorrect is off
global ListStamps := Map()      ; path -> "modified|size" at the time of the last load
RefreshLists()

; Re-reads the exception files if they were created, edited or deleted since
; the last load, so manual edits take effect without restarting the script.
RefreshLists() {
    global Exceptions, ExceptionApps, ExceptionsPath, ExceptionsAppsPath
    ReloadIfChanged(ExceptionsPath, Exceptions, false)
    ReloadIfChanged(ExceptionsAppsPath, ExceptionApps, true)
}

ReloadIfChanged(path, target, lowerCase) {
    global ListStamps
    stamp := ""  ; "" = file does not exist
    if FileExist(path) {
        try stamp := FileGetTime(path, "M") "|" FileGetSize(path)
    }
    if (ListStamps.Has(path) && ListStamps[path] = stamp)
        return
    ListStamps[path] := stamp
    LoadList(path, target, lowerCase)
}

; Reads a one-entry-per-line file ("#" comments, blank lines ignored) into a Map.
LoadList(path, target, lowerCase) {
    target.Clear()
    if !FileExist(path)
        return
    text := FileRead(path, "UTF-8")
    Loop Parse text, "`n", "`r"
    {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        target[lowerCase ? StrLower(line) : line] := true
    }
}

; Appends an entry to a list file and activates it immediately.
AppendToList(path, target, entry, lowerCase) {
    key := lowerCase ? StrLower(entry) : entry
    if (entry = "" || target.Has(key))
        return true
    try {
        prefix := ""
        if FileExist(path) {
            existing := FileRead(path, "UTF-8")
            if (existing != "" && SubStr(existing, -1) != "`n")
                prefix := "`n"  ; file was edited by hand and lacks a trailing newline
        }
        FileAppend(prefix entry "`n", path, "UTF-8-RAW")
    } catch {
        return false
    }
    target[key] := true
    return true
}

startTick := A_TickCount
loadedFromSource := LoadDictionary(DictPath)
loadMs := A_TickCount - startTick

if (loadedFromSource && Dict.Count > 0) {
    ToolTip("AutoCorrect: " Dict.Count " entries, " loadMs " ms")
    SetTimer(() => ToolTip(), -3000)
}

; ---------------------------------------------------------------
; Input interception
; ---------------------------------------------------------------
IH := InputHook("V")     ; visible / non-blocking
IH.KeyOpt("{All}", "N")  ; notify for all keys, block nothing
IH.OnChar := OnCharTyped
IH.OnKeyDown := OnKeyDownRaw
IH.Start()

global AutoCorrectEnabled := true

if (ToggleHotkey != "")
    Hotkey(ToggleHotkey, ToggleAutoCorrect)

; Mouse clicks move the caret / switch windows -> forget the word buffer and undo state
Hotkey("~LButton", ResetOnMouse)
Hotkey("~RButton", ResetOnMouse)
Hotkey("~MButton", ResetOnMouse)

; Details of the last replacement, filled in by TryReplace()
global LastTrigger := ""
global LastReplacementText := ""
global LastTime := ""
global LastWindow := ""
global LastProcess := ""
global LastUndoneFrom := ""   ; original word if the replacement was undone
global LastReplGui := ""

if (ShowLastReplacementHotkey != "")
    Hotkey(ShowLastReplacementHotkey, ShowLastReplacement)

ShowLastReplacement(*) {
    global LastTrigger, LastReplacementText, LastTime, LastWindow, LastProcess, LastUndoneFrom, LastReplGui
    global Exceptions, ExceptionApps
    RefreshLists()

    if IsObject(LastReplGui) {
        try LastReplGui.Destroy()
        LastReplGui := ""
    }

    ; Close button only in the title bar (no minimize / maximize)
    title := "AutoCorrect - last replacement" (LastTime != "" ? " - " LastTime : "")
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", title)

    if (LastTrigger = "") {
        g.SetFont("s10 norm")
        g.AddText("w570", "No replacement has fired yet.")
        btnOk := g.AddButton("xm+470 w100 Default", "OK")
    } else {
        replText := LastReplacementText (LastUndoneFrom != "" ? "  (UNDONE: " LastUndoneFrom ")" : "")
        rows := [["Trigger:", LastTrigger], ["Replacement:", replText], ["Window:", LastWindow]]
        for row in rows {
            g.SetFont("s10 bold")
            g.AddText("xm w100", row[1])
            g.SetFont("s10 norm")
            g.AddText("xm+110 yp w460 0x80", row[2])  ; 0x80: show "&" literally
        }

        triggerListed := Exceptions.Has(LastTrigger)
        btnAdd := g.AddButton("xm w170", triggerListed ? "Already in exceptions" : "Add to exceptions")
        btnAdd.Enabled := !triggerListed
        btnAdd.OnEvent("Click", AddLastToExceptions.Bind(btnAdd))

        appListed := (LastProcess = "") || ExceptionApps.Has(StrLower(LastProcess))
        appCaption := LastProcess = "" ? "Disable in this app"
            : (appListed ? LastProcess " is disabled" : "Disable in " LastProcess)
        btnApp := g.AddButton("x+10 yp w230", appCaption)
        btnApp.Enabled := !appListed
        btnApp.OnEvent("Click", AddLastAppToExceptions.Bind(btnApp))

        btnOk := g.AddButton("xm+470 yp w100 Default", "OK")  ; right edge = right edge of the text column
    }
    btnOk.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())

    LastReplGui := g
    g.Show()
}

AddLastToExceptions(btn, *) {
    global LastTrigger, Exceptions, ExceptionsPath
    if AppendToList(ExceptionsPath, Exceptions, LastTrigger, false) {
        btn.Text := "Added"
        btn.Enabled := false
    } else {
        btn.Text := "Could not write file"
    }
}

AddLastAppToExceptions(btn, *) {
    global LastProcess, ExceptionApps, ExceptionsAppsPath
    if AppendToList(ExceptionsAppsPath, ExceptionApps, LastProcess, true) {
        btn.Text := LastProcess " is disabled"
        btn.Enabled := false
    } else {
        btn.Text := "Could not write file"
    }
}

ToggleAutoCorrect(*) {
    global AutoCorrectEnabled, WordBuf
    AutoCorrectEnabled := !AutoCorrectEnabled
    WordBuf := ""
    MouseGetPos(&mx, &my)
    ToolTip("AutoCorrect: " (AutoCorrectEnabled ? "ON" : "OFF"), mx + 16, my + 16)
    SetTimer(() => ToolTip(), -2000)
}

; ---------------------------------------------------------------
; Keyboard layout switching
; ---------------------------------------------------------------
DetectScript(text) {
    if RegExMatch(text, "[А-Яа-яЁёІіЇїЄє]")
        return "cyrillic"
    return "latin"
}

SwitchInputLanguage(scriptKey) {
    global ScriptLayoutIDs
    if !ScriptLayoutIDs.Has(scriptKey)
        return
    PostMessage(0x0050, 0, ScriptLayoutIDs[scriptKey], , 0xFFFF)  ; WM_INPUTLANGCHANGEREQUEST, broadcast
}

; ---------------------------------------------------------------
; Core matching logic
; ---------------------------------------------------------------
OnCharTyped(ih, char) {
    global WordBuf, WordCharsPattern, AutoCorrectEnabled, UndoTick, BufHwnd
    UndoTick := 0  ; any typed character makes the previous replacement non-undoable
    if !AutoCorrectEnabled
        return

    ; Focus moved to another window since the buffer was filled -> it is stale
    hwnd := WinExist("A")
    if (hwnd != BufHwnd) {
        WordBuf := ""
        BufHwnd := hwnd
    }

    if RegExMatch(char, WordCharsPattern) {
        WordBuf .= char
        return
    }
    ; Boundary char is already on screen (non-blocking hook), so the
    ; caret sits right after it - TryReplace() accounts for that.
    TryReplace(char)
    WordBuf := ""
}

OnKeyDownRaw(ih, vk, sc) {
    global WordBuf, UndoTick, UndoOriginal, UndoReplacement, UndoWindowMs

    ; Shortcuts (Ctrl+V, Ctrl+Backspace, Alt+Tab, Win+...) edit text or switch
    ; windows in ways we can't track -> the word buffer no longer matches the
    ; text before the caret.
    if (!IsModifierVK(vk) && IsShortcutHeld()) {
        WordBuf := ""
        UndoTick := 0
        return
    }

    if (vk = 0x08) {  ; VK_BACK - our own synthetic presses never reach here
        if (UndoTick && A_TickCount - UndoTick <= UndoWindowMs) {
            ; The real Backspace is still on its way to the app (non-blocking
            ; hook), so do the actual work a few ms later, after it landed.
            SetTimer(UndoReplacement_Do.Bind(UndoOriginal, UndoReplacement), -15)
        }
        UndoTick := 0
        if (WordBuf != "")
            WordBuf := SubStr(WordBuf, 1, StrLen(WordBuf) - 1)
        return
    }

    ; Caret movement / non-typing edits: PgUp, PgDn, End, Home, arrows, Insert,
    ; Delete, Esc. After these the caret is no longer right behind the typed
    ; word, so pressing Space must not replace anything.
    if ((vk >= 0x21 && vk <= 0x28) || vk = 0x2D || vk = 0x2E || vk = 0x1B)
        WordBuf := ""

    ; Any non-modifier key moves/changes the text in a way we can't track
    ; -> drop the undo state.
    if !IsModifierVK(vk)
        UndoTick := 0
}

; True while Ctrl / Alt / Win is held. RAlt is skipped on purpose: AltGr
; (reported as Ctrl+RAlt) types letters on some layouts.
IsShortcutHeld() {
    if GetKeyState("RAlt")
        return false
    return GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")
}

IsModifierVK(vk) {
    return vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0x5B || vk = 0x5C
        || (vk >= 0xA0 && vk <= 0xA5)
}

; Reverts the last replacement. At this point the user's Backspace has
; already deleted the boundary char, so only the replacement is left on screen.
UndoReplacement_Do(original, replacement) {
    global WordBuf, LastUndoneFrom, SwitchSoundPath
    WordBuf := ""
    Send("{BackSpace " StrLen(replacement) "}")
    SendText(original)
    SwitchInputLanguage(DetectScript(original))
    LastUndoneFrom := original

    if FileExist(SwitchSoundPath)
        SoundPlay(SwitchSoundPath)
}

; A mouse click moves the caret -> neither the typed word nor the replacement
; is right before it anymore
ResetOnMouse(*) {
    global UndoTick, WordBuf
    UndoTick := 0
    WordBuf := ""
}

TryReplace(boundaryChar) {
    global WordBuf, Dict, SwitchSoundPath
    global UndoTick, UndoOriginal, UndoReplacement, UndoWindowMs
    global Exceptions, ExceptionApps
    global LastTrigger, LastReplacementText, LastTime, LastWindow, LastProcess, LastUndoneFrom
    if (WordBuf = "")
        return
    if Dict.Has(WordBuf) {
        RefreshLists()  ; only on a dictionary hit, so normal typing stays cheap
        if Exceptions.Has(WordBuf)
            return
        proc := ""
        try proc := WinGetProcessName("A")
        if (proc != "" && ExceptionApps.Has(StrLower(proc)))
            return
        replacement := Dict[WordBuf]
        ; Erase the word + the boundary char already on screen, then retype both.
        Send("{BackSpace " (StrLen(WordBuf) + 1) "}")
        SendText(replacement)
        ResendBoundaryChar(boundaryChar)
        SwitchInputLanguage(DetectScript(replacement))

        ; Remember what was typed so Backspace can revert it shortly after
        if (UndoWindowMs > 0) {
            UndoOriginal := WordBuf
            UndoReplacement := replacement
            UndoTick := A_TickCount
        }
        if FileExist(SwitchSoundPath)
            SoundPlay(SwitchSoundPath)

        LastTrigger := WordBuf
        LastReplacementText := replacement
        LastTime := FormatTime(, "HH:mm:ss")
        LastWindow := ""
        try LastWindow := WinGetTitle("A")
        LastProcess := proc
        LastUndoneFrom := ""
    }
}

ResendBoundaryChar(char) {
    switch char {
        case "`n", "`r":
            Send("{Enter}")
        case "`t":
            Send("{Tab}")
        default:
            SendText(char)
    }
}
