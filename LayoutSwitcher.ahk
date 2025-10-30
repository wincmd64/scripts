; Keyboard Layout Switcher
; by github.com/wincmd64
;
; Left Ctrl - English
; Right Ctrl - Russian  
; AppsKey - Ukrainian
;
; Ctrl+Alt+Shift+F12 - Show installed layouts (for testing/customization)

#Requires AutoHotkey v2.0
#SingleInstance Force

; Get installed keyboard layouts once at startup
installedLayouts := GetInstalledLayoutsWithNames()

~LControl::SwitchLayout(0x4090409) ; EN
~RControl::SwitchLayout(0x4190419) ; RU
AppsKey::SwitchLayout(0x04220422)  ; UA
!^+F12::
{
    allLayoutsStr := ""
    for layoutID, langName in installedLayouts {
        allLayoutsStr .= Format("0x{:08X}", layoutID) . " - " . langName . "`n"
    }
    MsgBox(Trim(allLayoutsStr, "`n") . "`n`nTotal: " installedLayouts.Count " layouts")
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
