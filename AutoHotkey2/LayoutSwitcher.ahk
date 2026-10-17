/*
Keyboard Layout Switcher

First, run LayoutSwitcher.ahk with -layouts and note the codes of your layouts.
Then, put them into SwitchLayout() below.
Optional, add label with the language code: Flash(textColor, bgColor, ms)

Default:
    Left Ctrl tap - English
    Right Ctrl tap - Russian
    AltGr - Ukrainian
    CapsLock - convert selected text (or the line up to the caret) typed in the
               wrong layout, and switch the layout (see CapsConvert below)
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===================================================

CapsConvert := 1            ; 1 = CapsLock converts text typed in the wrong layout, 0 = normal CapsLock
CapsBase    := 0x04090409   ; base layout for CapsConvert (English): text is converted to/from it

~LControl Up:: {
    if (A_PriorKey = "LControl") {
        SwitchLayout(0x04090409)
        Flash("White", "2E9E4F")
        ;SoundBeep(600, 90), SoundBeep(800, 90)
    }
}

~RControl Up:: {
    if (A_PriorKey = "RControl") {
        SwitchLayout(0x04190419)
        Flash("White", "D03A3A")
        ;SoundBeep(800, 90), SoundBeep(600, 90)
    }
}

A_MenuMaskKey := "vkE8"    ; unassigned key for masking Alt/Win release (default is Ctrl)
~RAlt:: Send("{Blind}{vkE8}")    ; lone Alt release must not open the app's menu bar
~RAlt Up:: {
    if (A_PriorKey = "RAlt") {
        SwitchLayout(0x04220422)
        Flash("Yellow", "Blue")
    }
}

; ===================================================

#HotIf CapsConvert
CapsLock:: ConvertText()
#HotIf

; Get installed keyboard layouts once at startup
installedLayouts := GetInstalledLayoutsWithNames()
lastLayout := 0     ; layout requested by the last SwitchLayout() call (used by Flash)
foreign := 0        ; last non-base layout requested (used by CapsConvert)

; -layouts
if (A_Args.Length && A_Args[1] = "-layouts") {
    allLayoutsStr := ""
    for layoutID, langName in installedLayouts {
        allLayoutsStr .= Format("0x{:08X}", layoutID) . " - " . langName . "`n"
    }
    MsgBox(Trim(allLayoutsStr, "`n"), "Installed layouts")
    ExitApp
}

; Flash a small colored label near the text caret (or the mouse), then remove it.
; The label is the ISO 639 language code of the layout just switched to (EN, RU, UK...).
Flash(textColor := "", bgColor := "", ms := 700) {
    static g := 0, hide := 0, seen := Map()
    if !installedLayouts.Has(lastLayout)
        return                          ; layout is not installed - nothing to show
    ; Colors passed by a hotkey are remembered per language, so a bare Flash() (CapsConvert)
    ; reuses them. Gray until that language has been switched to by its own hotkey.
    lang := lastLayout & 0xFFFF
    if (textColor != "" && bgColor != "")
        seen[lang] := [textColor, bgColor]
    else {
        colors := seen.Get(lang, ["White", "444444"])
        textColor := colors[1]
        bgColor := colors[2]
    }
    buf := Buffer(16)
    if DllCall("GetLocaleInfo", "UInt", lastLayout & 0xFFFF, "UInt", 0x59, "Ptr", buf, "Int", 8)  ; LOCALE_SISO639LANGNAME
        text := StrUpper(StrGet(buf))
    else
        text := "?"
    if hide
        SetTimer(hide, 0)               ; cancel the previous label's timer
    if g
        try g.Destroy()
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")  ; click-through, never takes focus
    g.BackColor := bgColor
    g.MarginX := 12
    g.MarginY := 4
    g.SetFont("s14 bold c" textColor, "Segoe UI")
    g.Add("Text", , text)
    CoordMode("Caret", "Screen")
    CoordMode("Mouse", "Screen")
    if CaretGetPos(&x, &y) {
        x += 6
        y += 26
    } else {
        MouseGetPos(&x, &y)
        x += 20
        y += 24
    }
    g.Show("NoActivate AutoSize x" x " y" y)
    hide := () => g.Destroy()
    SetTimer(hide, -ms)
}

; Get all installed layouts with their names
GetInstalledLayoutsWithNames() {
    layouts := Map()
    
    ; Get the number of installed layouts
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    
    if (count > 0) {
        ; Allocate buffer for layout handles
        layoutListBuf := Buffer(count * A_PtrSize)
        
        ; Retrieve the list of keyboard layout handles
        DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", layoutListBuf, "Int")
        
        ; Get name for each layout and store in Map
        Loop count {
            hkl := NumGet(layoutListBuf, (A_Index - 1) * A_PtrSize, "Ptr")
            
            ; Extract language ID and get name directly
            langID := hkl & 0xFFFF
            buf := Buffer(256)
            if DllCall("GetLocaleInfo", "UInt", langID, "UInt", 0x2, "Ptr", buf, "Int", 256) {
                langName := StrGet(buf)
            } else {
                langName := "Unknown"
            }
            
            layouts[hkl] := langName
        }
    }
    
    return layouts
}

; Function to switch keyboard layout with validation
SwitchLayout(layoutID) {
    global lastLayout, foreign
    lastLayout := layoutID
    if (installedLayouts.Has(layoutID)) {
        if !IsBase(layoutID)
            foreign := layoutID         ; remembered for CapsConvert
        ; Send WM_INPUTLANGCHANGEREQUEST message to change layout
        PostMessage(0x50, 0, layoutID, , 0xFFFF)
    } else {
        ; Play error sound if layout is not installed
        SoundBeep(750, 500)
    }
}

; ===================================================
; CapsConvert: character tables are built from the installed layouts, nothing is hardcoded.
; ===================================================

; Is this layout the base one (compared by language, not by full handle)?
IsBase(hkl) => (hkl & 0xFFFF) = (CapsBase & 0xFFFF)

; Keyboard layout of the active window
CurrentLayout() {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
    return DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
}

; Non-base layout to convert to when the current layout is the base one
ForeignLayout() {
    if foreign
        return foreign
    for hkl in installedLayouts
        if !IsBase(hkl)
            return hkl
    return 0
}

; Character that a physical key (scan code) produces in layout hkl ("" for none / dead key / control char)
KeyChar(sc, shifted, hkl) {
    vk := DllCall("MapVirtualKeyExW", "UInt", sc, "UInt", 3, "Ptr", hkl, "UInt")   ; MAPVK_VSC_TO_VK_EX
    if !vk
        return ""
    ks := Buffer(256, 0)
    if shifted
        NumPut("UChar", 0x80, ks, 0x10)                                            ; VK_SHIFT down
    buf := Buffer(16, 0)
    n := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", ks, "Ptr", buf, "Int", 8, "UInt", 4, "Ptr", hkl, "Int")  ; 4 = don't touch key state
    if (n != 1)
        return ""
    ch := StrGet(buf, 1, "UTF-16")
    return Ord(ch) > 32 ? ch : ""
}

; Map(char typed in layout src -> char the same key gives in layout dst)
BuildMap(src, dst) {
    m := Map()
    scs := [0x56]                       ; extra key on ISO keyboards
    Loop 52
        scs.Push(A_Index + 1)           ; 0x02..0x35: main block of keys
    for sc in scs
        for shifted in [0, 1] {
            a := KeyChar(sc, shifted, src)
            b := KeyChar(sc, shifted, dst)
            if (a != "" && b != "" && a != b)
                m[a] := b
        }
    return m
}

; Convert the selection (or the line up to the caret) between the base and a foreign layout,
; paste it back and switch the layout.
ConvertText() {
    global foreign
    static cache := Map()

    cur := CurrentLayout()
    toBase := !IsBase(cur)              ; typed in a foreign layout -> to base; typed in base -> to the foreign one
    other := toBase ? cur : ForeignLayout()
    if !other
        return
    if toBase
        foreign := other                ; remember the layout we are leaving
    SwitchLayout(toBase ? CapsBase : other)
    Flash()

    ; consoles: Ctrl+C would interrupt the running command, so only the layout is switched
    if WinActive("ahk_class ConsoleWindowClass") || WinActive("ahk_exe WindowsTerminal.exe")
        return

    if !cache.Has(other)
        cache[other] := [BuildMap(CapsBase, other), BuildMap(other, CapsBase)]
    en2second := cache[other][1]
    second2en := cache[other][2]

    backup := ClipboardAll()
    try {
        A_Clipboard := ""
        Send "^c"
        ClipWait 0.15
        if A_Clipboard = "" {
            A_Clipboard := ""
            Send "+{Home}^c"
            ClipWait 0.5
        }

        if A_Clipboard != "" {
            result := ""
            mode := "en"
            Loop Parse A_Clipboard {
                c2nd := en2second.Get(A_LoopField, "")
                cEN  := second2en.Get(A_LoopField, "")
                if cEN && c2nd {
                    result .= mode = "en" ? cEN : c2nd
                } else if cEN {
                    result .= cEN
                    mode := "en"
                } else if c2nd {
                    result .= c2nd
                    mode := "second"
                } else {
                    result .= A_LoopField
                }
            }
            A_Clipboard := result
            Send "^v"
            Sleep 100
        }
    } finally {
        A_Clipboard := backup           ; restored even if something above throws
    }
}
