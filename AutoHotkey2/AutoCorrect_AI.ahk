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

; Dictionary file. Get AS_dict.txt from:
; https://gitea.com/BladeMight/Mahou/releases/download/latest-commit/AS_Dict.zip
global DictPath := ScriptDir "\AS_dict.txt"

; Sound played on a successful replacement. Silently skipped if missing.
global SwitchSoundPath := ScriptDir "\switch.wav"

; Cache file: a faster-to-parse copy of AS_dict.txt (one line per entry
; instead of two, no ->/====>/<==== markers). Rebuilt automatically
; whenever AS_dict.txt is newer than the cache.
global CachePath := ScriptDir "\AS_dict.cache"

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

; Hotkey to show a MsgBox with details of the last replacement
; Set to "" to disable.
global ShowLastReplacementHotkey := "^!+F11" ; Ctrl+Alt+Shift+F11

; ---------------- END SETTINGS ----------------

global Dict := Map()
global WordBuf := ""

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

global LastReplacement := ""  ; filled in by TryReplace() on each match

if (ShowLastReplacementHotkey != "")
    Hotkey(ShowLastReplacementHotkey, ShowLastReplacement)

ShowLastReplacement(*) {
    global LastReplacement
    MsgBox(LastReplacement = "" ? "No replacement has fired yet." : LastReplacement,
        "AutoCorrect - last replacement", "Icon?")
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
    global WordBuf, WordCharsPattern, AutoCorrectEnabled
    if !AutoCorrectEnabled
        return
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
    global WordBuf
    if (vk = 0x08 && WordBuf != "")  ; VK_BACK - our own synthetic presses never reach here
        WordBuf := SubStr(WordBuf, 1, StrLen(WordBuf) - 1)
}

TryReplace(boundaryChar) {
    global WordBuf, Dict, SwitchSoundPath, LastReplacement
    if (WordBuf = "")
        return
    if Dict.Has(WordBuf) {
        replacement := Dict[WordBuf]
        ; Erase the word + the boundary char already on screen, then retype both.
        Send("{BackSpace " (StrLen(WordBuf) + 1) "}")
        SendText(replacement)
        ResendBoundaryChar(boundaryChar)
        SwitchInputLanguage(DetectScript(replacement))
        if FileExist(SwitchSoundPath)
            SoundPlay(SwitchSoundPath)

        LastReplacement := (
            "Trigger: " WordBuf
            "`nReplacement: " replacement
            "`nTime: " FormatTime(, "HH:mm:ss")
            "`nWindow: " WinGetTitle("A")
        )
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
