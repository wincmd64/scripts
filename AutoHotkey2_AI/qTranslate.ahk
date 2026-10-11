#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; Quick Translate — translates the selected text via Google
; =========================================================

; ---------------- SETTINGS ----------------
; Comma-separated list of target languages, e.g. "ru,uk,en". The first one
; is used by default. Right-click the result window's title to switch
; between them — the choice sticks for the rest of the script's run. https://docs.cloud.google.com/translate/docs/languages
TargetLang    := "ru,en,uk"
SourceLang    := "auto"  ; auto-detect the source language
WindowOpacity := 92      ; result window opacity, 0-100 (100 = fully opaque)

; Regular hotkey, normal AHK hotkey syntax (e.g. "#8", "^!t", "#F1", "MButton").
; Set to "" or "none" to disable it.
Hotkey1 := "#SC029" ; Win + ~

; Double-tap trigger: "Shift", "Ctrl", "Alt", or "" / "none" to disable it.
; Both Hotkey1 and DoubleTapKey work independently and can be active at the same time.
DoubleTapKey    := "alt"
DoubleTapWindow := 300   ; max ms between two taps of DoubleTapKey to count as a double-tap

Theme := "system" ; "system", "dark", or "light" — "system" reads the current
                   ; Windows app theme (light/dark) from the registry

TitleFontSize := 9  ; font size of the "Translate from X to Y" header
TextFontSize  := 11 ; font size of the translated text

WindowStartWidth  := 400 ; starting width of the translation window, px
WindowStartHeight := 150 ; starting height of the translation window, px
AutoSelectTranslatedText := false ; select the whole translated text when the window opens
; -------------------------------------------

global TranslateGui := ""
global FocusWatchTimer := ""
global TitleCtrlHwnd := 0
global TranslateTitleCtrl := ""
global TranslateEditCtrl := ""
global EditStartY := 0

; parse the TargetLang setting into a list, first entry is the default
global TargetLangList := []
for lang in StrSplit(TargetLang, ",")
    TargetLangList.Push(Trim(lang))
global CurrentTargetLang := TargetLangList[1]

; remembers the last translated text/position so the right-click
; language menu can re-translate without a fresh text selection
global LastOriginalText := ""
global LastMouseX := 0
global LastMouseY := 0

; intercept clicks on the empty top area / title so the window can be dragged
OnMessage(0x201, On_TitleMouseDown)  ; WM_LBUTTONDOWN
; right-click on the same area opens the target-language menu
OnMessage(0x7B, On_TitleRightClick)  ; WM_CONTEXTMENU

; register whichever triggers are enabled — both can be active together
if !(Hotkey1 = "" || StrLower(Hotkey1) = "none")
    Hotkey(Hotkey1, TranslateHotkeyHandler)

if !(DoubleTapKey = "" || StrLower(DoubleTapKey) = "none") {
    Hotkey("~L" DoubleTapKey " up", DoubleTapHandler)
    Hotkey("~R" DoubleTapKey " up", DoubleTapHandler)
}

; detects two taps of DoubleTapKey within DoubleTapWindow ms and triggers translation
DoubleTapHandler(*) {
    static lastTick := 0
    global DoubleTapWindow
    now := A_TickCount
    if (now - lastTick <= DoubleTapWindow) {
        lastTick := 0 ; reset so a third tap doesn't immediately re-trigger
        TranslateHotkeyHandler()
    } else {
        lastTick := now
    }
}

TranslateHotkeyHandler(*) {
    global WindowStartWidth, WindowStartHeight, LastOriginalText, LastMouseX, LastMouseY

    text := GetSelectedText()
    if (text = "") {
        ToolTip("No text selected")
        SetTimer(() => ToolTip(), -1000)
        return
    }

    MouseGetPos(&mx, &my)
    LastOriginalText := text
    LastMouseX := mx
    LastMouseY := my

    ; show the window right away with a loading placeholder — this is a
    ; brand-new translation, so it opens fresh near the cursor
    ShowTranslationWindow(mx + 15, my + 15, WindowStartWidth, WindowStartHeight, "Translating...", "Loading text...")

    ; defer the actual network call so it never blocks the hotkey/hook thread
    SetTimer(DoTranslate.Bind(text), -1)
}

; picks which language to actually translate into: normally the
; session's current target, but if the text is already in that
; language, steps to the next different one in TargetLangList
; (wrapping around) so we never show a same>same translation
PickEffectiveTargetLang(detectedLang) {
    global TargetLangList, CurrentTargetLang
    d := StrLower(detectedLang)
    c := StrLower(CurrentTargetLang)
    if (d != c)
        return {lang: CurrentTargetLang, isAuto: false}

    n := TargetLangList.Length
    idx := 1
    for i, lang in TargetLangList {
        if (StrLower(lang) = c) {
            idx := i
            break
        }
    }
    loop n {
        idx := Mod(idx, n) + 1
        if (StrLower(TargetLangList[idx]) != d)
            return {lang: TargetLangList[idx], isAuto: true}
    }
    return {lang: CurrentTargetLang, isAuto: false} ; degenerate: list has just this one language
}

DoTranslate(text) {
    global SourceLang, AutoSelectTranslatedText, CurrentTargetLang

    try {
        firstPass := TranslateGoogle(text, CurrentTargetLang, SourceLang)
    } catch as e {
        UpdateTranslationWindow("Error", "Translation error: " e.Message)
        return
    }

    pick := PickEffectiveTargetLang(firstPass.detectedLang)
    if !pick.isAuto {
        result := firstPass
        effectiveLang := CurrentTargetLang
    } else {
        ; source language equals the current target — re-request
        ; against the next different language in the list instead
        try {
            result := TranslateGoogle(text, pick.lang, SourceLang)
        } catch as e {
            UpdateTranslationWindow("Error", "Translation error: " e.Message)
            return
        }
        effectiveLang := pick.lang
    }

    titleText := "Translate from " StrUpper(firstPass.detectedLang) " to " StrUpper(effectiveLang)
    if pick.isAuto
        titleText .= " (auto)"

    UpdateTranslationWindow(titleText, result.translated, AutoSelectTranslatedText)
}

; ---------------------------------------------------------
; 1. Grab the selected text via the clipboard
; ---------------------------------------------------------
GetSelectedText() {
    oldClip := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(0.5) {
        A_Clipboard := oldClip
        return ""
    }
    text := A_Clipboard
    A_Clipboard := oldClip
    return Trim(text)
}

; ---------------------------------------------------------
; 2. Request to the unofficial Google Translate endpoint
; ---------------------------------------------------------
TranslateGoogle(text, targetLang, sourceLang := "auto") {
    url := "https://translate.googleapis.com/translate_a/single"
        . "?client=gtx&sl=" sourceLang "&tl=" targetLang "&dt=t&q=" UrlEncode(text)

    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(5000, 5000, 5000, 8000) ; resolve, connect, send, receive — ms
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "Mozilla/5.0")
    req.Send()

    if (req.Status != 200)
        throw Error("HTTP " req.Status)

    return ParseGoogleResponse(req.ResponseText)
}

; ---------------------------------------------------------
; 3. Parse the response with a real (mini) JSON parser.
;    This way we only ever take each sentence's first field —
;    any extra metadata/hashes Google adds cannot leak in,
;    unlike with a regex-based approach.
; ---------------------------------------------------------
ParseGoogleResponse(body) {
    data := JsonParse(body)

    translated := ""
    sentences := data[1]
    for sentence in sentences {
        if (sentence.Length >= 1 && sentence[1] != "")
            translated .= sentence[1]
    }

    detected := (data.Length >= 3) ? data[3] : ""

    return {translated: translated, detectedLang: detected}
}

; ---- mini JSON parser (only what's needed: arrays, strings, numbers, null/true/false) ----
JsonParse(str) {
    pos := 1
    return JsonParseValue(str, &pos)
}

JsonSkipWs(str, &pos) {
    len := StrLen(str)
    while (pos <= len) {
        c := SubStr(str, pos, 1)
        if (c != " " && c != "`t" && c != "`r" && c != "`n")
            break
        pos += 1
    }
}

JsonParseValue(str, &pos) {
    JsonSkipWs(str, &pos)
    c := SubStr(str, pos, 1)
    if (c = "[")
        return JsonParseArray(str, &pos)
    else if (c = '"')
        return JsonParseString(str, &pos)
    else if (c = "t") {
        pos += 4
        return true
    } else if (c = "f") {
        pos += 5
        return false
    } else if (c = "n") {
        pos += 4
        return ""
    } else {
        return JsonParseNumber(str, &pos)
    }
}

JsonParseArray(str, &pos) {
    arr := []
    pos += 1 ; skip [
    JsonSkipWs(str, &pos)
    if (SubStr(str, pos, 1) = "]") {
        pos += 1
        return arr
    }
    loop {
        val := JsonParseValue(str, &pos)
        arr.Push(val)
        JsonSkipWs(str, &pos)
        c := SubStr(str, pos, 1)
        pos += 1
        if (c = "]")
            break
        ; otherwise c = "," — keep going
    }
    return arr
}

JsonParseString(str, &pos) {
    pos += 1 ; skip opening quote
    out := ""
    len := StrLen(str)
    while (pos <= len) {
        c := SubStr(str, pos, 1)
        if (c = '"') {
            pos += 1
            return out
        } else if (c = "\") {
            esc := SubStr(str, pos + 1, 1)
            if (esc = "u") {
                hex := SubStr(str, pos + 2, 4)
                out .= Chr("0x" hex)
                pos += 6
            } else {
                if (esc = "n")
                    out .= "`n"
                else if (esc = "t")
                    out .= "`t"
                else if (esc = "r")
                    out .= "`r"
                else
                    out .= esc
                pos += 2
            }
        } else {
            out .= c
            pos += 1
        }
    }
    return out
}

JsonParseNumber(str, &pos) {
    start := pos
    len := StrLen(str)
    while (pos <= len) {
        c := SubStr(str, pos, 1)
        if !InStr("-+.0123456789eE", c)
            break
        pos += 1
    }
    numStr := SubStr(str, start, pos - start)
    return numStr + 0
}

; ---------------------------------------------------------
; URL-encoding (with non-ASCII support via UTF-8)
; ---------------------------------------------------------
UrlEncode(s) {
    result := ""
    loop parse s {
        code := Ord(A_LoopField)
        if RegExMatch(A_LoopField, "[A-Za-z0-9\-\._~]")
            result .= A_LoopField
        else if (code < 128)
            result .= Format("%{:02X}", code)
        else {
            for byte in StrToUtf8Bytes(A_LoopField)
                result .= Format("%{:02X}", byte)
        }
    }
    return result
}

StrToUtf8Bytes(char) {
    bytes := []
    utf8 := Buffer(4, 0)
    byteLen := StrPut(char, utf8, "UTF-8") - 1
    loop byteLen
        bytes.Push(NumGet(utf8, A_Index - 1, "UChar"))
    return bytes
}

; ---------------------------------------------------------
; Theme resolution: "light"/"dark" pass through as-is,
; "system" reads the current Windows apps theme from the registry
; ---------------------------------------------------------
GetEffectiveTheme() {
    global Theme
    t := StrLower(Theme)
    if (t = "dark" || t = "light")
        return t
    try {
        lightMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        return (lightMode = 0) ? "dark" : "light"
    } catch {
        return "light" ; fall back if the registry value doesn't exist
    }
}

; ---------------------------------------------------------
; finds the work-area bounds of whichever monitor contains (px, py)
; ---------------------------------------------------------
GetWorkAreaAt(px, py) {
    count := MonitorGetCount()
    loop count {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        if (px >= L && px < R && py >= T && py < B)
            return {L: L, T: T, R: R, B: B}
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
    return {L: L, T: T, R: R, B: B}
}

; ---------------------------------------------------------
; 4. Result GUI
; ---------------------------------------------------------

; creates a brand-new window at (x, y) with the given starting
; content — used only for a fresh hotkey-triggered translation
ShowTranslationWindow(x, y, startW, startH, titleText, bodyText) {
    global TranslateGui, TitleCtrlHwnd, TranslateTitleCtrl, WindowOpacity, FocusWatchTimer, TranslateEditCtrl, EditStartY, TitleFontSize, TextFontSize

    DestroyTranslateGui()

    theme := GetEffectiveTheme()
    bgColor := (theme = "dark") ? "000000" : "F5F5F5"
    textColor := (theme = "dark") ? "FFFFFF" : "000000"

    TranslateGui := Gui("+ToolWindow -Caption +AlwaysOnTop +Resize", "Translate")
    TranslateGui.BackColor := bgColor
    TranslateGui.MarginX := 10
    TranslateGui.MarginY := 8

    TranslateGui.SetFont("s" TitleFontSize " cGray Bold", "Segoe UI")
    ; +E0x20 = WS_EX_TRANSPARENT — clicks on this control fall through
    ; straight to the window itself, otherwise OnMessage never sees them
    titleCtrl := TranslateGui.Add("Text", "w" (startW - 20) " +E0x20", titleText)
    TitleCtrlHwnd := titleCtrl.Hwnd
    TranslateTitleCtrl := titleCtrl

    TranslateGui.SetFont("s" TextFontSize " c" textColor " Norm", "Segoe UI")
    editCtrl := TranslateGui.Add("Edit", "w" (startW - 20) " r4 -VScroll ReadOnly -E0x200 Background" bgColor, bodyText)
    TranslateEditCtrl := editCtrl
    editCtrl.GetPos(&ex, &EditStartY, &ew, &eh)

    TranslateGui.OnEvent("Escape", (*) => DestroyTranslateGui())
    TranslateGui.OnEvent("Size", On_GuiResize)

    ; clamp so the window never opens partially off-screen — a layered
    ; (WinSetTransparent) window doesn't paint its off-screen portion,
    ; leaving a blank patch behind once that part is dragged into view.
    ; a +Resize window has a few extra px of invisible resize border
    ; beyond startW/startH, hence the small safety margin below
    resizeBorder := 12
    wa := GetWorkAreaAt(x, y)
    posX := x
    posY := y
    if (posX + startW + resizeBorder > wa.R)
        posX := wa.R - startW - resizeBorder
    if (posY + startH + resizeBorder > wa.B)
        posY := wa.B - startH - resizeBorder
    if (posX < wa.L)
        posX := wa.L
    if (posY < wa.T)
        posY := wa.T

    TranslateGui.Show("x" posX " y" posY " w" startW " h" startH)

    opacity255 := Round(255 * (WindowOpacity < 0 ? 0 : WindowOpacity > 100 ? 100 : WindowOpacity) / 100)
    WinSetTransparent(opacity255, TranslateGui)

    FocusWatchTimer := SetTimer(CheckFocus, 150)
}

; updates the title/body of the CURRENT window in place — no
; recreation, so its position/size (and any manual resize/drag
; the person already did) stay exactly as they are. Used both
; for the "Translating..." placeholder and the final result.
UpdateTranslationWindow(titleText, bodyText, autoSelect := false) {
    global TranslateGui, TranslateTitleCtrl, TranslateEditCtrl

    if !(IsObject(TranslateGui) && IsObject(TranslateTitleCtrl) && IsObject(TranslateEditCtrl))
        return

    TranslateTitleCtrl.Text := titleText
    TranslateEditCtrl.Text := bodyText
    UpdateScrollbar(TranslateEditCtrl)

    ; the Edit control auto-selects all its text when it gets focus
    ; (it's the only tab-stop control here) — clear that selection
    ; unless autoSelect is enabled
    ; EM_SETSEL = 0xB1
    if autoSelect
        PostMessage(0xB1, 0, -1, , "ahk_id " TranslateEditCtrl.Hwnd)
    else
        PostMessage(0xB1, 0, 0, , "ahk_id " TranslateEditCtrl.Hwnd)
}

On_TitleMouseDown(wParam, lParam, msg, hwnd) {
    global TranslateGui
    if (IsObject(TranslateGui) && hwnd = TranslateGui.Hwnd)
        PostMessage(0xA1, 2, , , "ahk_id " TranslateGui.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
}

On_TitleRightClick(wParam, lParam, msg, hwnd) {
    global TranslateGui
    if (IsObject(TranslateGui) && hwnd = TranslateGui.Hwnd)
        ShowLanguageMenu()
}

; builds and shows the target-language picker, with a check mark on
; whichever language is currently active
ShowLanguageMenu() {
    global TargetLangList, CurrentTargetLang
    langMenu := Menu()
    for lang in TargetLangList {
        label := StrUpper(lang)
        langMenu.Add(label, LangMenuHandler)
        if (lang = CurrentTargetLang)
            langMenu.Check(label)
    }
    langMenu.Show()
}

; switches the active target language and, if we have a previous
; translation on hand, re-translates it right away — keeps the
; window exactly where/how it is, just swaps the content
LangMenuHandler(itemName, itemPos, menuObj) {
    global CurrentTargetLang, LastOriginalText
    CurrentTargetLang := StrLower(itemName)
    if (LastOriginalText = "")
        return

    ; show a loading placeholder right away so the window doesn't
    ; look frozen while translating longer text
    UpdateTranslationWindow("Translating...", "Loading text...")
    SetTimer(DoTranslate.Bind(LastOriginalText), -1)
}

On_GuiResize(guiObj, minMax, w, h) {
    global TranslateEditCtrl, EditStartY
    if (minMax = -1 || !IsObject(TranslateEditCtrl)) ; -1 = window minimized
        return
    newW := w - guiObj.MarginX * 2
    newH := h - EditStartY - guiObj.MarginY
    if (newW < 50)
        newW := 50
    if (newH < 30)
        newH := 30
    TranslateEditCtrl.Move(, , newW, newH)
    UpdateScrollbar(TranslateEditCtrl)
}

; shows the vertical scrollbar only if the translated text doesn't
; fit in the control's current height, hides it otherwise
UpdateScrollbar(editCtrl) {
    global TextFontSize
    lineCount := SendMessage(0xBA, 0, 0, , "ahk_id " editCtrl.Hwnd)  ; EM_GETLINECOUNT
    editCtrl.GetPos(, , , &eh)
    approxLineHeight := Round(TextFontSize * 1.6 * 96 / 72)
    visibleLines := Max(1, eh // approxLineHeight)
    if (lineCount > visibleLines)
        editCtrl.Opt("+VScroll")
    else
        editCtrl.Opt("-VScroll")

    ; Opt() flips the style bit but doesn't always force the
    ; non-client area (where the scrollbar itself is drawn) to
    ; redraw — force it explicitly
    ; SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED = 0x27
    DllCall("SetWindowPos", "Ptr", editCtrl.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x27)
}

CheckFocus() {
    global TranslateGui
    if !IsObject(TranslateGui)
        return
    if !WinActive("ahk_id " TranslateGui.Hwnd)
        DestroyTranslateGui()
}

DestroyTranslateGui() {
    global TranslateGui, FocusWatchTimer, TitleCtrlHwnd
    if (FocusWatchTimer) {
        SetTimer(FocusWatchTimer, 0)
        FocusWatchTimer := ""
    }
    if IsObject(TranslateGui) {
        TranslateGui.Destroy()
        TranslateGui := ""
    }
    TitleCtrlHwnd := 0
}
