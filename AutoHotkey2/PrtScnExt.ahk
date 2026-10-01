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

    overlay := "ahk_exe SnippingTool.exe ahk_class XamlWindow"
    ; Clipboard "version" - lets us detect a new image without touching the clipboard
    seq := DllCall("GetClipboardSequenceNumber")

    Run "ms-screenclip:"
    if !WinWait(overlay, , 5)
        return                  ; overlay never appeared
    WinWaitClose(overlay)       ; wait as long as the user needs (Esc / X / snip done)

    ; The image may land on the clipboard a moment after the overlay closes
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
    ; WinWaitActive alone can time out
    if WinWait("ahk_exe " exeName, , 3) {
        WinActivate
        WinWaitActive("ahk_exe " exeName, , 2)
        Sleep 150
        Send "^v"
    }
}
