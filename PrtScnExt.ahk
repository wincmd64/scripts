/*
Enhances PrintScreen functionality
by github.com/wincmd64

    PrtScn:       Launches native Snipping Tool (ignore OS settings)
    Shift+PrtScn: Snips and auto-pastes the image into MS Paint
    Ctrl+PrtScn:  Snips and auto-pastes into a custom user editor (e.g., IrfanView)
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; USER EDITOR PATH:
global UserEditorPath := "D:\soft\IrfanView\i_view64.exe"

PrintScreen::Run "ms-screenclip:"           ; PrintScreen: always open the snip UI
+PrintScreen::SnipAndPaste("mspaint.exe")   ; Shift+PrintScreen: snip -> paste result into Paint
^PrintScreen::SnipAndPaste(UserEditorPath)  ; Ctrl+PrintScreen: snip -> paste result into the user's editor


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
