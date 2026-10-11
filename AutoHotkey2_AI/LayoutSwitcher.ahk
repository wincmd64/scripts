/*
Keyboard Layout Switcher

    Left Ctrl tap - English (+ beep)
    Right Ctrl tap - Russian (+ beep)
    AltGr - Ukrainian

Run LayoutSwitcher.ahk with -layouts to show all installed layouts (for testing/customization)
*/


#Requires AutoHotkey v2.0
#SingleInstance Force

; Get installed keyboard layouts once at startup
installedLayouts := GetInstalledLayoutsWithNames()

; -layouts
if (A_Args.Length && A_Args[1] = "-layouts") {
    allLayoutsStr := ""
    for layoutID, langName in installedLayouts {
        allLayoutsStr .= Format("0x{:08X}", layoutID) . " - " . langName . "`n"
    }
    MsgBox(Trim(allLayoutsStr, "`n"), "Installed layouts")
    ExitApp
}

~LControl Up:: {
    if (A_PriorKey = "LControl") {
        SwitchLayout(0x04090409)
        SoundBeep(600, 90)   ; up: low -> high
        SoundBeep(800, 90)
    }
}

~RControl Up:: {
    if (A_PriorKey = "RControl") {
        SwitchLayout(0x04190419)
        SoundBeep(800, 90)   ; down: high -> low
        SoundBeep(600, 90)
    }
}

~RAlt::
RAlt & RCtrl::{ ; AltGr - Ukrainian   TIP: use RWin or AppsKey instead
    SwitchLayout(0x04220422)
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
    if (installedLayouts.Has(layoutID)) {
        ; Send WM_INPUTLANGCHANGEREQUEST message to change layout
        PostMessage(0x50, 0, layoutID, , 0xFFFF)
    } else {
        ; Play error sound if layout is not installed
        SoundBeep(750, 500)
    }
}
