/*
    AutoCorrect: fixes text typed in the wrong keyboard layout (ghbdtn -> привет,
    руддщ -> hello) and common typos, using Mahou's AS_dict.txt dictionary.

    USAGE.
      Just type. When a word is finished (space, Enter, punctuation) and it is in the
      dictionary, it is replaced and the keyboard layout is switched to match.
      Backspace right after a replacement reverts it.
      Ctrl+Alt+Shift+F12   toggle AutoCorrect on/off
      Ctrl+Alt+Shift+F11   details of the last replacement; its buttons add the trigger
                           or the current app to the exceptions so it is left alone
      Hotkeys, undo time and exception files are in SETTINGS below. If the dictionary
      is missing, you are offered to download it.

    HOW IT WORKS.
      An InputHook watches typed characters and collects letters into a word buffer.
      A non-letter ends the word: it is looked up in the dictionary and, unless
      excepted, retyped as its replacement. Caret moves, clicks, shortcuts and window
      changes reset the buffer, so a stale word is never replaced.
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------------- SETTINGS ----------------
; (hotkeys: set to "" to disable)

; Folder this file lives in (works regardless of where it's #Include-d from)
global ScriptDir := ""
SplitPath(A_LineFile, , &ScriptDir)

; Dictionary: https://gitea.com/BladeMight/Mahou/releases/download/latest-commit/AS_Dict.zip
global DictPath := ScriptDir "\AS_dict.txt"

; Played after a replacement (skipped if missing): https://pixeldrain.com/u/VURSv53s
global SwitchSoundPath := ScriptDir "\switch.wav"

; Faster-to-parse copy of the dictionary, rebuilt when AS_dict.txt is newer
global CachePath := ScriptDir "\AS_dict.cache"

; Triggers that are never replaced / processes (e.g. TOTALCMD64.EXE) where nothing is
; replaced. One entry per line, "#" starts a comment. Both get filled by buttons in the
; last-replacement window.
global ExceptionsPath := ScriptDir "\AS_exceptions.txt"
global ExceptionsAppsPath := ScriptDir "\AS_exceptions_apps.txt"

; 1 = also correct English typed in the Ukrainian layout (e.g. "ефіу" -> "test").
; One-way only: the dictionary has no Ukrainian words. 0 = Ukrainian is ignored completely.
global UkrainianLayout := 1

; Toggle AutoCorrect on/off (tooltip near the cursor)
global ToggleHotkey := "^!+F12" ; Ctrl+Alt+Shift+F12

; Window with details of the last replacement
global ShowLastReplacementHotkey := "^!+F11" ; Ctrl+Alt+Shift+F11

; Backspace as the first key within this many ms after a replacement reverts it
; (the Backspace eats the boundary char, like Word's autocorrect). 0 = off.
global UndoWindowMs := 2000

; ---------------- END SETTINGS ----------------

; Characters treated as part of a word (Ukrainian-only letters only if UkrainianLayout)
global LatinLetters := "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm"
global CyrillicLetters := "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁйцукенгшщзхъфывапролджэячсмитьбюё"
if UkrainianLayout
    CyrillicLetters .= "ЇІЄҐїієґ"
global WordCharsPattern := "[" LatinLetters CyrillicLetters "'’\-]"

global Dict := Map()
global WordBuf := ""
global BufHwnd := 0  ; window the current WordBuf was typed in

; State of the last replacement, used for undo (UndoTick = 0 -> nothing to undo)
global UndoTick := 0
global UndoOriginal := ""
global UndoReplacement := ""
global UndoLayout := 0   ; HKL that was active before the replacement

; --- Keyboard layout discovery (which installed HKL to switch to) ---
global AC_InstalledLayouts := AC_GetInstalledLayoutsWithNames()
global ScriptLayoutIDs := BuildScriptLayoutMap(AC_InstalledLayouts)

; HKL -> English language name, for every installed layout
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

; One installed HKL per alphabet ("latin" / "cyrillic")
BuildScriptLayoutMap(layouts) {
    result := Map()
    for hkl, name in layouts {
        ; Ukrainian is never a switch target, nor should it pass for English
        if InStr(name, "Ukrainian")
            continue
        key := InStr(name, "Russian") ? "cyrillic" : "latin"
        if !result.Has(key)
            result[key] := hkl
    }
    return result
}

; --- Dictionary loading ---
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

; Downloads and unpacks AS_Dict.zip via Shell.Application (no external tools)
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

        ; FOF_NOCONFIRMATION (16) + FOF_SILENT (4)
        destFolder.CopyHere(zipFolder.Items, 4 | 16)

        ; CopyHere is asynchronous: wait for the file
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

; --- Exceptions list ---
global Exceptions := Map()      ; triggers that must never be replaced
global ExceptionApps := Map()   ; lower-cased process names where AutoCorrect is off
global ListStamps := Map()      ; path -> "modified|size" at the time of the last load
AC_RefreshLists()

; Reloads the exception files when they changed on disk (edits apply without restart)
AC_RefreshLists() {
    global Exceptions, ExceptionApps, ExceptionsPath, ExceptionsAppsPath
    AC_ReloadIfChanged(ExceptionsPath, Exceptions, false)
    AC_ReloadIfChanged(ExceptionsAppsPath, ExceptionApps, true)
}

AC_ReloadIfChanged(path, target, lowerCase) {
    global ListStamps
    stamp := ""  ; "" = file does not exist
    if FileExist(path) {
        try stamp := FileGetTime(path, "M") "|" FileGetSize(path)
    }
    if (ListStamps.Has(path) && ListStamps[path] = stamp)
        return
    ListStamps[path] := stamp
    AC_LoadList(path, target, lowerCase)
}

AC_LoadList(path, target, lowerCase) {
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

AC_AppendToList(path, target, entry, lowerCase) {
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

; Adds Ukrainian-layout twins of "English typed in a Cyrillic layout" triggers
; (never overwrites existing entries)
AC_AddUkrainianVariants() {
    global Dict
    extra := Map()
    for trigger, repl in Dict {
        if !RegExMatch(trigger, "[ЫЪЭыъэ]")
            continue
        if RegExMatch(repl, "[А-Яа-яЁёІіЇїЄєҐґ]")  ; Cyrillic result = Russian typo fix, not for UA
            continue
        ; UA has і ї є on the keys where RU has ы ъ э (s ] '); ґ is on the backslash
        ; key, so ё is deliberately not mapped
        twin := StrReplace(trigger, "ы", "і", true)
        twin := StrReplace(twin, "Ы", "І", true)
        twin := StrReplace(twin, "ъ", "ї", true)
        twin := StrReplace(twin, "Ъ", "Ї", true)
        twin := StrReplace(twin, "э", "є", true)
        twin := StrReplace(twin, "Э", "Є", true)
        if (twin != trigger && !Dict.Has(twin))
            extra[twin] := repl
    }
    for trigger, repl in extra
        Dict[trigger] := repl
}

startTick := A_TickCount
loadedFromSource := LoadDictionary(DictPath)
if (UkrainianLayout && Dict.Count > 0)
    AC_AddUkrainianVariants()
loadMs := A_TickCount - startTick

if (loadedFromSource && Dict.Count > 0) {
    ToolTip("AutoCorrect: " Dict.Count " entries, " loadMs " ms")
    SetTimer(() => ToolTip(), -3000)
}

; --- Input interception ---
; "L0" is essential: by default an InputHook ends itself after 1023 collected chars
; (EndReason "Max") and AutoCorrect silently stops. OnChar / OnKeyDown still work.
IH := InputHook("V L0")   ; visible / non-blocking, no length limit
IH.KeyOpt("{All}", "N")  ; notify for all keys, block nothing
IH.OnChar := OnCharTyped
IH.OnKeyDown := OnKeyDownRaw
IH.Start()

global AutoCorrectEnabled := true

if (ToggleHotkey != "")
    Hotkey(ToggleHotkey, ToggleAutoCorrect)

; A click moves the caret -> reset the buffer. Polled instead of Hotkey("~LButton"):
; another script's hotkey on the same key (e.g. Launcher.ahk) would replace this one.
global MouseWasDown := false
SetTimer(AC_PollMouseButtons, 50)

AC_PollMouseButtons() {
    global MouseWasDown
    down := GetKeyState("LButton") || GetKeyState("RButton") || GetKeyState("MButton")
    if (down && !MouseWasDown)
        AC_ResetOnMouse()
    MouseWasDown := down
}

AC_KeyDownOS(vk) {
    return DllCall("GetAsyncKeyState", "int", vk, "short") & 0x8000
}

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
    AC_RefreshLists()

    if IsObject(LastReplGui) {
        try LastReplGui.Destroy()
        LastReplGui := ""
    }

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
        btnAdd.OnEvent("Click", AC_AddLastToExceptions.Bind(btnAdd))

        appListed := (LastProcess = "") || ExceptionApps.Has(StrLower(LastProcess))
        appCaption := LastProcess = "" ? "Disable in this app"
            : (appListed ? LastProcess " is disabled" : "Disable in " LastProcess)
        btnApp := g.AddButton("x+10 yp w230", appCaption)
        btnApp.Enabled := !appListed
        btnApp.OnEvent("Click", AC_AddLastAppToExceptions.Bind(btnApp))

        btnOk := g.AddButton("xm+470 yp w100 Default", "OK")  ; right edge = right edge of the text column
    }
    btnOk.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.OnEvent("Close", (*) => g.Destroy())

    LastReplGui := g
    g.Show()
}

AC_AddLastToExceptions(btn, *) {
    global LastTrigger, Exceptions, ExceptionsPath
    if AC_AppendToList(ExceptionsPath, Exceptions, LastTrigger, false) {
        btn.Text := "Added"
        btn.Enabled := false
    } else {
        btn.Text := "Could not write file"
    }
}

AC_AddLastAppToExceptions(btn, *) {
    global LastProcess, ExceptionApps, ExceptionsAppsPath
    if AC_AppendToList(ExceptionsAppsPath, ExceptionApps, LastProcess, true) {
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

; --- Keyboard layout switching ---
DetectScript(text) {
    global CyrillicLetters
    return RegExMatch(text, "[" CyrillicLetters "]") ? "cyrillic" : "latin"
}

AC_CurrentLayout() {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    return DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
}

SwitchInputLanguage(scriptKey) {
    global ScriptLayoutIDs
    if !ScriptLayoutIDs.Has(scriptKey)
        return
    PostMessage(0x0050, 0, ScriptLayoutIDs[scriptKey], , 0xFFFF)  ; WM_INPUTLANGCHANGEREQUEST, broadcast
}

; --- Core matching logic ---
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
    ; The boundary char is already on screen; TryReplace() accounts for it
    TryReplace(char)
    WordBuf := ""
}

OnKeyDownRaw(ih, vk, sc) {
    global WordBuf, UndoTick, UndoOriginal, UndoReplacement, UndoWindowMs

    ; Shortcuts (Ctrl+V, Alt+Tab, Win+...) change text/focus untracked -> drop the buffer
    if (!AC_IsModifierVK(vk) && AC_IsShortcutHeld()) {
        WordBuf := ""
        UndoTick := 0
        return
    }

    if (vk = 0x08) {  ; VK_BACK - our own synthetic presses never reach here
        if (UndoTick && A_TickCount - UndoTick <= UndoWindowMs) {
            ; the real Backspace hasn't reached the app yet: undo a few ms later
            SetTimer(AC_UndoReplacement_Do.Bind(UndoOriginal, UndoReplacement, UndoLayout), -15)
        }
        UndoTick := 0
        if (WordBuf != "")
            WordBuf := SubStr(WordBuf, 1, StrLen(WordBuf) - 1)
        return
    }

    ; PgUp..Down, Insert, Delete, Esc: the caret is no longer right behind the typed word
    if ((vk >= 0x21 && vk <= 0x28) || vk = 0x2D || vk = 0x2E || vk = 0x1B)
        WordBuf := ""

    ; any other key invalidates undo
    if !AC_IsModifierVK(vk)
        UndoTick := 0
}

; Ctrl/Alt/Win held? Uses the OS state: AutoHotkey's own can get stuck (e.g. after
; Win+L) and would silently disable AutoCorrect.
AC_IsShortcutHeld() {
    if AC_KeyDownOS(0xA5)  ; RAlt = AltGr, which types letters on some layouts
        return false
    return AC_KeyDownOS(0x11) || AC_KeyDownOS(0x12) || AC_KeyDownOS(0x5B) || AC_KeyDownOS(0x5C)
}

AC_IsModifierVK(vk) {
    return vk = 0x10 || vk = 0x11 || vk = 0x12 || vk = 0x5B || vk = 0x5C
        || (vk >= 0xA0 && vk <= 0xA5)
}

; The user's Backspace already removed the boundary char; only the replacement is left
AC_UndoReplacement_Do(original, replacement, layout) {
    global WordBuf, LastUndoneFrom, SwitchSoundPath
    WordBuf := ""
    Send("{BackSpace " StrLen(replacement) "}")
    SendText(original)
    if layout  ; back to the layout the user was typing in (RU or UA), not a guess
        PostMessage(0x0050, 0, layout, , 0xFFFF)  ; WM_INPUTLANGCHANGEREQUEST, broadcast
    else
        SwitchInputLanguage(DetectScript(original))
    LastUndoneFrom := original

    if FileExist(SwitchSoundPath)
        SoundPlay(SwitchSoundPath)
}

AC_ResetOnMouse(*) {
    global UndoTick, WordBuf
    UndoTick := 0
    WordBuf := ""
}

TryReplace(boundaryChar) {
    global WordBuf, Dict, SwitchSoundPath
    global UndoTick, UndoOriginal, UndoReplacement, UndoLayout, UndoWindowMs
    global Exceptions, ExceptionApps
    global LastTrigger, LastReplacementText, LastTime, LastWindow, LastProcess, LastUndoneFrom
    if (WordBuf = "")
        return
    if Dict.Has(WordBuf) {
        AC_RefreshLists()  ; only on a dictionary hit, so normal typing stays cheap
        if Exceptions.Has(WordBuf)
            return
        proc := ""
        try proc := WinGetProcessName("A")
        if (proc != "" && ExceptionApps.Has(StrLower(proc)))
            return
        replacement := Dict[WordBuf]
        layoutBefore := AC_CurrentLayout()
        ; Erase the word + the boundary char already on screen, then retype both.
        Send("{BackSpace " (StrLen(WordBuf) + 1) "}")
        SendText(replacement)
        ResendBoundaryChar(boundaryChar)
        SwitchInputLanguage(DetectScript(replacement))

        ; Remember what was typed so Backspace can revert it shortly after
        if (UndoWindowMs > 0) {
            UndoOriginal := WordBuf
            UndoReplacement := replacement
            UndoLayout := layoutBefore
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
