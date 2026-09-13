#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; Quick Translate — translates the selected text via Google
; =========================================================

; ---------------- SETTINGS ----------------
TargetLang    := "ru"    ; language to translate into: https://docs.cloud.google.com/translate/docs/languages
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
global TranslateEditCtrl := ""
global EditStartY := 0

; intercept clicks on the empty top area / title so the window can be dragged
OnMessage(0x201, On_TitleMouseDown)  ; WM_LBUTTONDOWN

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
    text := GetSelectedText()
    if (text = "") {
        ToolTip("No text selected")
        SetTimer(() => ToolTip(), -1000)
        return
    }

    MouseGetPos(&mx, &my)
    ToolTip("Translating...", mx + 15, my + 15)

    ; defer the actual network call so it never blocks the hotkey/hook thread
    SetTimer(DoTranslate.Bind(text, mx, my), -1)
}

DoTranslate(text, mx, my) {
    global TargetLang, SourceLang, WindowStartWidth, WindowStartHeight, AutoSelectTranslatedText
    try {
        result := TranslateGoogle(text, TargetLang, SourceLang)
    } catch as e {
        ToolTip()
        ToolTip("Translation error: " e.Message)
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ToolTip()
    ShowTranslation(mx, my, text, result.translated, result.detectedLang, TargetLang, WindowStartWidth, WindowStartHeight, AutoSelectTranslatedText)
}

; ---------------------------------------------------------
; 1. Grab the selected text via the clipboard
; ---------------------------------------------------------
GetSelectedText() {
    oldClip := ClipboardAll()
    A_Clipboard := ""
    ; if triggered by a Win-based hotkey, Win may still be physically
    ; held at this point (the hotkey fires on key-down) — release it
    ; explicitly so Ctrl+C doesn't get sent as Win+Ctrl+C
    Send("{LWin up}{RWin up}")
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
ShowTranslation(x, y, original, translated, detectedLang, targetLang, startW, startH, autoSelect) {
    global TranslateGui, TitleCtrlHwnd, WindowOpacity, FocusWatchTimer, TranslateEditCtrl, EditStartY, TitleFontSize, TextFontSize

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
    titleText := "Translate from " StrUpper(detectedLang) " to " StrUpper(targetLang)
    titleCtrl := TranslateGui.Add("Text", "w" (startW - 20) " +E0x20", titleText)
    TitleCtrlHwnd := titleCtrl.Hwnd

    TranslateGui.SetFont("s" TextFontSize " c" textColor " Norm", "Segoe UI")
    editCtrl := TranslateGui.Add("Edit", "w" (startW - 20) " r4 -VScroll ReadOnly -E0x200 Background" bgColor, translated)
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
    posX := x + 15
    posY := y + 15
    if (posX + startW + resizeBorder > wa.R)
        posX := wa.R - startW - resizeBorder
    if (posY + startH + resizeBorder > wa.B)
        posY := wa.B - startH - resizeBorder
    if (posX < wa.L)
        posX := wa.L
    if (posY < wa.T)
        posY := wa.T

    TranslateGui.Show("x" posX " y" posY " w" startW " h" startH)

    ; the Edit control auto-selects all its text when it gets focus
    ; (it's the only tab-stop control here) — clear that selection
    ; unless autoSelect is enabled
    ; EM_SETSEL = 0xB1
    if autoSelect
        PostMessage(0xB1, 0, -1, , "ahk_id " editCtrl.Hwnd)
    else
        PostMessage(0xB1, 0, 0, , "ahk_id " editCtrl.Hwnd)

    opacity255 := Round(255 * (WindowOpacity < 0 ? 0 : WindowOpacity > 100 ? 100 : WindowOpacity) / 100)
    WinSetTransparent(opacity255, TranslateGui)

    FocusWatchTimer := SetTimer(CheckFocus, 150)
}

On_TitleMouseDown(wParam, lParam, msg, hwnd) {
    global TranslateGui
    if (IsObject(TranslateGui) && hwnd = TranslateGui.Hwnd)
        PostMessage(0xA1, 2, , , "ahk_id " TranslateGui.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
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
