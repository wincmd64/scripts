/*
Launcher. Shows a popup menu with the contents of one folder for quick launching.

FIRST STEP: set "Folder" in the settings below to your own folder.

Show the menu:
  Win+Z (change with ShowHotkey)  |  left click on the tray icon  |  double-click on empty taskbar space

In the menu:
  Left click / Enter       run the item (folder: new tab in Total Commander's active panel, or Explorer)
  Shift + click / Enter    run as administrator
  Middle click             run as administrator
  Right click              reveal the item (new tab in Total Commander with the cursor on it, or Explorer)
  Esc / click elsewhere    close the menu
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== User settings =====
Folder          := "D:\soft\.lnk"       ; folder with shortcuts
ShowHotkey      := "#z"                 ; hotkey to show the menu (# = Win)
TaskbarDblClick := 1                    ; 1 = double-click on empty taskbar space shows the menu
TrayIcon        := RegExReplace(A_ScriptFullPath, "\.\w+$", ".ico")   ; "" = default AHK icon
MaxItems        := 100                  ; max menu entries, the rest is cut off (0 = no limit)
; =========================

curMenu  := ""
curNames := []
pending  := ""                          ; [index, "R"|"M"] set by the menu hook

hookCb := CallbackCreate(MenuMsgFilter, "F", 3)

if TrayIcon != "" && FileExist(TrayIcon)
    try TraySetIcon(TrayIcon)

; Left click on the tray icon shows the menu
A_TrayMenu.Insert("1&", "Show menu", (*) => ShowMenu())
A_TrayMenu.Default := "Show menu"
A_TrayMenu.ClickCount := 1

try
    Hotkey(ShowHotkey, (*) => ShowMenu())
catch {
    MsgBox("Invalid hotkey: " ShowHotkey)
    ExitApp
}

if TaskbarDblClick
    Hotkey("~LButton", TaskbarClick)

ShowMenu() {
    global curMenu, curNames, pending, Folder, hookCb
    dir := RTrim(Folder, "\")

    ; Re-read the folder on every show: top-level files and folders, no hidden
    dirs := "", files := ""
    Loop Files, dir "\*", "FD" {
        if InStr(A_LoopFileAttrib, "H")
            continue
        if InStr(A_LoopFileAttrib, "D")
            dirs .= A_LoopFileName "`n"
        else
            files .= A_LoopFileName "`n"
    }
    names := []                         ; folders first, then files, each sorted
    for part in [dirs, files] {
        part := RTrim(part, "`n")
        if part = ""
            continue
        for n in StrSplit(Sort(part), "`n")
            names.Push(n)
    }
    total := names.Length
    if MaxItems > 0 && total > MaxItems
        names.RemoveAt(MaxItems + 1, total - MaxItems)
    curNames := names

    m := Menu()
    if curNames.Length = 0 {
        m.Add("(folder is empty)", (*) => 0)
        m.Disable("(folder is empty)")
    } else {
        for name in curNames {
            label := StrReplace(name, "&", "&&")
            m.Add(label, RunItem.Bind(name))
            SetItemIcon(m, label, dir "\" name)
        }
        more := total - curNames.Length
        if more > 0 {
            moreLabel := "(+" more " more not shown)"
            m.Add()
            m.Add(moreLabel, (*) => 0)
            m.Disable(moreLabel)
        }
    }

    curMenu := m
    pending := ""
    hHook := DllCall("SetWindowsHookExW", "int", -1, "ptr", hookCb, "ptr", 0
        , "uint", DllCall("GetCurrentThreadId"), "ptr")    ; WH_MSGFILTER
    m.Show()
    DllCall("UnhookWindowsHookEx", "ptr", hHook)

    if pending {
        path := dir "\" curNames[pending[1] + 1]
        if pending[2] = "R"
            Reveal(path)
        else
            RunPath(path, true)
    }
}

; Catches RMB/MMB inside the popup menu (native menus only report LMB)
MenuMsgFilter(code, wParam, lParam) {
    global pending, curMenu, curNames
    if code = 2 {                       ; MSGF_MENU
        msg := NumGet(lParam, A_PtrSize, "uint")
        if msg = 0x0205 || msg = 0x0208 {   ; WM_RBUTTONUP / WM_MBUTTONUP
            pt  := NumGet(lParam, 4 * A_PtrSize + 4, "int64")
            idx := DllCall("MenuItemFromPoint", "ptr", A_ScriptHwnd, "ptr", curMenu.Handle
                , "int64", pt, "int")
            if idx >= 0 && idx < curNames.Length {
                pending := [idx, msg = 0x0205 ? "R" : "M"]
                DllCall("EndMenu")
                return 1
            }
        }
    }
    return DllCall("CallNextHookEx", "ptr", 0, "int", code, "ptr", wParam, "ptr", lParam, "ptr")
}

; Double-click detection on empty taskbar space
TaskbarClick(*) {
    static last := 0
    if !TaskbarEmptySpot() {
        last := 0
        return
    }
    if last && A_TickCount - last <= DllCall("GetDoubleClickTime") {
        last := 0
        KeyWait("LButton")              ; show on release, otherwise the menu eats the click
        ShowMenu()
    } else
        last := A_TickCount
}

; True if the cursor is over the taskbar and not over a button (Windows 10 layout)
TaskbarEmptySpot() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y, &hwnd, &ctrl)
    if !hwnd
        return false
    cls := WinGetClass(hwnd)
    if cls != "Shell_TrayWnd" && cls != "Shell_SecondaryTrayWnd"
        return false
    if ctrl != "" && !RegExMatch(ctrl, "^(MSTaskListWClass|MSTaskSwWClass|ReBarWindow32)")
        return false                    ; start button, clock, tray area, etc.

    ; Ask accessibility what is under the cursor; taskbar buttons are push buttons
    var := Buffer(24, 0), pacc := 0
    pt := (y << 32) | (x & 0xFFFFFFFF)
    if DllCall("oleacc\AccessibleObjectFromPoint", "int64", pt, "ptr*", &pacc, "ptr", var) < 0 || !pacc
        return false
    acc := ComValue(9, pacc)            ; releases the interface when it goes out of scope
    child := NumGet(var, 8, "int")
    cv := Buffer(24, 0), out := Buffer(24, 0)
    NumPut("ushort", 3, cv, 0)          ; VT_I4
    NumPut("int", child, cv, 8)
    try {
        if A_PtrSize = 8
            ComCall(13, pacc, "ptr", cv, "ptr", out)                  ; IAccessible::get_accRole
        else
            ComCall(13, pacc, "int64", 3, "int64", child, "ptr", out)
    } catch
        return false
    return NumGet(out, 0, "ushort") = 3 && NumGet(out, 8, "uint") != 0x2B   ; 0x2B = ROLE_SYSTEM_PUSHBUTTON
}

; LMB / Enter (Shift held = run as admin)
RunItem(name, *) {
    global Folder
    RunPath(RTrim(Folder, "\") "\" name, GetKeyState("Shift"))
}

RunPath(path, admin := false) {
    if !FileExist(path)
        return
    if DirExist(path) {
        OpenFolder(path)
        return
    }
    try Run((admin ? "*RunAs " : "") '"' path '"')
}

; Path to the running Total Commander exe, or "" if it is not running
TCPath() {
    hwnd := WinExist("ahk_class TTOTAL_CMD")
    if !hwnd
        return ""
    try return WinGetProcessPath(hwnd)
    return EnvGet("COMMANDER_EXE")      ; fallback if the process path is not readable
}

OpenFolder(path) {
    exe := TCPath()
    try {
        if exe != ""
            Run('"' exe '" /O /T /S /L="' path '"')     ; new tab in the active panel
        else
            Run('explorer "' path '"')
    }
}

Reveal(path) {
    exe := TCPath()
    try {
        if exe != ""
            Run('"' exe '" /O /T /S /P "' path '"')     ; new tab in the active panel, cursor on the item
        else
            Run('explorer /select,"' path '"')
    }
}

SetItemIcon(m, label, path) {
    if DirExist(path) {
        try m.SetIcon(label, "shell32.dll", 4)
        return
    }
    iconFile := path, iconNum := 1
    if RegExMatch(path, "i)\.lnk$")
        GetLnkIcon(path, &iconFile, &iconNum)
    try m.SetIcon(label, iconFile, iconNum)
}

; Icon set in the shortcut, otherwise the icon of its target
GetLnkIcon(lnk, &file, &num) {
    file := lnk, num := 1
    try {
        FileGetShortcut(lnk, &target, , , , &ic, &icn)
        if ic != ""
            file := ExpandEnv(ic), num := icn || 1
        else if target != ""
            file := target
    }
}

ExpandEnv(s) {
    n := DllCall("ExpandEnvironmentStringsW", "str", s, "ptr", 0, "uint", 0, "uint")
    buf := Buffer(n * 2)
    DllCall("ExpandEnvironmentStringsW", "str", s, "ptr", buf, "uint", n)
    return StrGet(buf)
}
