/*
Enhances PrintScreen functionality
by github.com/wincmd64

    PrtScn:       Always launches native Snipping Tool (ignore OS settings)
    Alt+PrtScn:   Snips and pastes the image into MS Paint
    Ctrl+PrtScn:  Snips and pastes into a custom user editor (e.g., IrfanView)
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; USER EDITOR PATH:
global UserEditorPath := "D:\soft\IrfanView\i_view64.exe"

; Overlays:
GroupAdd "SnipOverlay", "ahk_exe ScreenClippingHost.exe" ; Windows 10
GroupAdd "SnipOverlay", "ahk_exe SnippingTool.exe"       ; Windows 11

$PrintScreen::Run "ms-screenclip:"
!PrintScreen::SnipAndPaste("mspaint.exe")
^PrintScreen::SnipAndPaste(UserEditorPath)


SnipAndPaste(exePath) {
    ; Sanity-check full paths
    if InStr(exePath, "\") && !FileExist(exePath) {
        ToolTip "User editor path not found"
        SetTimer(() => ToolTip(), -2000)
        return
    }

    overlay := "ahk_group SnipOverlay"
    seq := DllCall("GetClipboardSequenceNumber") ; Clipboard "version" - lets us detect a new image without touching the clipboard

    Run "ms-screenclip:"
    if !WinWaitActive(overlay, , 5)
        return                  ; overlay never appeared
    WinWaitNotActive(overlay)   ; wait until user finishes or cancels (Esc)

    Loop 20 {
        if DllCall("GetClipboardSequenceNumber") != seq
            break
        Sleep 50
    }
    if DllCall("GetClipboardSequenceNumber") = seq
        return                  ; cancelled, clipboard untouched

    Run exePath
    exeName := ""
    SplitPath exePath, &exeName

    if WinWait("ahk_exe " exeName, , 3) {
        WinActivate "ahk_exe " exeName
        WinWaitActive("ahk_exe " exeName, , 2)
        Sleep 150
        Send "^v"
    }
}