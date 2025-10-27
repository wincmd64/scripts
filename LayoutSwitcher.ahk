; Keyboard Layout Switcher
; by github.com/wincmd64
;
; Left Ctrl - English
; Right Ctrl - Russian  
; AppsKey - Ukrainian
;
; Ctrl+Alt+Shift+F12 - Show installed layouts (for testing/debugging)

#Requires AutoHotkey v2.0
#SingleInstance Force

; Get installed keyboard layouts once
installedLayouts := GetInstalledLayouts()

~LControl::SwitchLayout(0x4090409) ; EN
~RControl::SwitchLayout(0x4190419) ; RU
AppsKey::SwitchLayout(0x04220422)  ; UA
!^+F12::
{
    allLayoutsStr := ""
    for layoutID in installedLayouts {
        allLayoutsStr .= Format("0x{:08X}", layoutID) . "`n"
    }
    MsgBox(Trim(allLayoutsStr, "`n") . "`n`nTotal: " installedLayouts.Count " layouts")
}

; Function to get all installed keyboard layouts from system
GetInstalledLayouts() {
    layouts := Map()
    
    ; Get the number of installed layouts
    count := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    
    if (count > 0) {
        ; Allocate buffer for layout handles
        layoutListBuf := Buffer(count * A_PtrSize)
        
        ; Retrieve the list of keyboard layout handles
        DllCall("GetKeyboardLayoutList", "Int", count, "Ptr", layoutListBuf, "Int")
        
        ; Store each layout in a Map for fast lookup
        Loop count {
            hkl := NumGet(layoutListBuf, (A_Index - 1) * A_PtrSize, "Ptr")
            layouts[hkl] := true
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
