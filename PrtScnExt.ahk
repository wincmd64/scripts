/*
Enhances PrintScreen functionality
by github.com/wincmd64

    PrtScn:       Launches native Snipping Tool (respects OS registry settings)
    Shift+PrtScn: Snips and auto-pastes the image into MS Paint
    Ctrl+PrtScn:  Snips and auto-pastes into a custom user editor (e.g., IrfanView)
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; User Editor Path
global UserEditorPath := "D:\soft\IrfanView\i_view64.exe"

; PrintScreen: do nothing if Win11 native snipping already handles it
~PrintScreen:: {
    try if RegRead("HKCU\Control Panel\Keyboard", "PrintScreenKeyForSnippingEnabled") = 1
        return
    Run "ms-screenclip:"
}

; Shift+PrintScreen: snip -> paste result into Paint
+PrintScreen::SnipAndPaste("mspaint.exe")

; Ctrl+PrintScreen: snip -> paste result into the user's editor
^PrintScreen::SnipAndPaste(UserEditorPath)



SnipAndPaste(exePath) {
    ; Sanity-check full paths
    if InStr(exePath, "\") && !FileExist(exePath) {
        ToolTip "User editor path not found"
        SetTimer(() => ToolTip(), -2000)
        return
    }

    savedClip := ClipboardAll()
    A_Clipboard := ""  ; clear so ClipWait reacts to the NEW content, not old

    Run "ms-screenclip:"

    if !ClipWait(5, 1) {
        A_Clipboard := savedClip  ; user cancelled (Esc) / timed out - restore
        return
    }

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
