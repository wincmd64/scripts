#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"

; Right-click on a window's Minimize button hides the window.
; Win+Alt+Down hides the active window, Win+Alt+Up restores the last hidden one.
; Hidden windows are listed in the "Restore" submenu of the tray menu.
; All hidden windows are restored when the script exits, except on Reload:
; then they stay hidden and the new instance picks them up again.

mtt_hidden := Map()    ; menu item name -> HWND
mtt_stack := []        ; hide order (for the Win+Alt+Up hotkey)
mtt_swallow := false   ; swallow the right button release
mtt_menu := Menu()     ; the "Restore" submenu with the hidden windows
mtt_stateFile := A_Temp "\MinToTray.state"  ; hidden windows carried over a Reload

OnExit(OnScriptExit)
LoadState()
SetTimer(CheckHidden, 250)

#HotIf IsOverMinButton()
RButton::
{
    global mtt_swallow := true
    MouseGetPos(, , &hwnd)
    HideWindow(DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr"))  ; GA_ROOT
}

#HotIf mtt_swallow
RButton Up::
{
    global mtt_swallow := false
}
#HotIf

; Win+Alt+Down: hide the active window
#!Down::
{
    hwnd := WinExist("A")
    if hwnd && !(WinGetClass(hwnd) ~= "^(Shell_TrayWnd|Progman|WorkerW)$")
        HideWindow(hwnd)
}

; Win+Alt+Up: restore the last hidden window
#!Up::
{
    if mtt_stack.Length
        RestoreOne(mtt_stack[mtt_stack.Length])
}

HideWindow(hwnd)
{
    Critical  ; don't let the cleanup timer interrupt us halfway
    name := WinGetTitle(hwnd)
    if name = ""
        name := "ahk_class " WinGetClass(hwnd)
    name := SubStr(name, 1, 100)
    if mtt_hidden.Has(name)
        name .= " " Format("{:X}", hwnd)
    mtt_hidden[name] := hwnd
    mtt_stack.Push(name)
    mtt_menu.Add(name, RestoreOne)
    SyncMenu()
    if WinActive(hwnd)
        Send "!{Esc}"  ; pass focus to the next window
    WinHide(hwnd)
}

IsOverMinButton()
{
    MouseGetPos(&x, &y, &hwnd)
    if !hwnd
        return false
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if !(WinGetStyle(root) & 0x20000)  ; no WS_MINIMIZEBOX
        return false

    ; Caption button area (min+max+close) from DWM; Minimize is the left third
    wr := Buffer(16)
    br := Buffer(16)
    DllCall("GetWindowRect", "Ptr", root, "Ptr", wr)
    if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", root, "UInt", 5, "Ptr", br, "UInt", 16) = 0
        && NumGet(br, 8, "Int") > NumGet(br, 0, "Int")
    {
        left := NumGet(wr, 0, "Int") + NumGet(br, 0, "Int")
        top := NumGet(wr, 4, "Int") + NumGet(br, 4, "Int")
        right := NumGet(wr, 0, "Int") + NumGet(br, 8, "Int")
        bottom := NumGet(wr, 4, "Int") + NumGet(br, 12, "Int")
        return x >= left && x < left + (right - left) / 3 && y >= top && y < bottom
    }

    ; Fallback for windows with a custom title bar: WM_NCHITTEST
    lParam := ((y & 0xFFFF) << 16) | (x & 0xFFFF)
    result := 0
    if !DllCall("SendMessageTimeoutW", "Ptr", root, "UInt", 0x84, "Ptr", 0
        , "Ptr", lParam, "UInt", 2, "UInt", 100, "Ptr*", &result)
        return false
    return result = 8  ; HTMINBUTTON
}

RestoreOne(name, *)
{
    hwnd := mtt_hidden[name]
    Forget(name)
    try WinShow(hwnd)
    try WinActivate(hwnd)
}

; Drop windows that were closed or shown by something else
CheckHidden()
{
    gone := []
    for name, hwnd in mtt_hidden
        if !DllCall("IsWindow", "Ptr", hwnd) || DllCall("IsWindowVisible", "Ptr", hwnd)
            gone.Push(name)
    for name in gone
        Forget(name)
}

Forget(name)
{
    mtt_hidden.Delete(name)
    mtt_menu.Delete(name)
    for i, n in mtt_stack
        if n = name {
            mtt_stack.RemoveAt(i)
            break
        }
    SyncMenu()
}

; Show the "Restore" submenu in the tray menu only while something is hidden
SyncMenu()
{
    static shown := false
    if mtt_hidden.Count && !shown {
        A_TrayMenu.Insert("1&", "Restore", mtt_menu)
        shown := true
    } else if !mtt_hidden.Count && shown {
        try A_TrayMenu.Delete("Restore")
        shown := false
    }
}

OnScriptExit(reason, *)
{
    if reason = "Reload"
        SaveState()
    else
        RestoreAll()
}

SaveState()
{
    if !mtt_stack.Length
        return
    text := ""
    for name in mtt_stack
        text .= mtt_hidden[name] "`t" name "`n"
    try FileDelete(mtt_stateFile)
    FileAppend(text, mtt_stateFile, "UTF-8")
}

LoadState()
{
    if !FileExist(mtt_stateFile)
        return
    text := FileRead(mtt_stateFile, "UTF-8")
    FileDelete(mtt_stateFile)
    Loop Parse text, "`n", "`r" {
        pos := InStr(A_LoopField, "`t")
        if !pos
            continue
        hwnd := Integer(SubStr(A_LoopField, 1, pos - 1))
        name := SubStr(A_LoopField, pos + 1)
        if DllCall("IsWindow", "Ptr", hwnd) && !DllCall("IsWindowVisible", "Ptr", hwnd) {
            mtt_hidden[name] := hwnd
            mtt_stack.Push(name)
            mtt_menu.Add(name, RestoreOne)
        }
    }
    SyncMenu()
}

RestoreAll(*)
{
    for name, hwnd in mtt_hidden
        try WinShow(hwnd)
}
