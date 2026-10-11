/*
LAUNCHER. Shows a popup menu with the contents of one folder for quick launching.
Items are listed with their icons: folders first, then files and shortcuts, each sorted alphabetically.
Subfolders become submenus that are loaded only when you open them. The folder is re-read
on every show, so changes appear at once. A shortcut (.lnk) to a folder, including
\\server\share, opens in a new Total Commander tab if it is running, otherwise in Explorer.

Show the menu:
  Win+Z (change with ShowHotkey)  |  double-click on empty taskbar space

In the menu:
  Left click / Enter       run the item
  Shift + click / Enter    run as administrator
  Middle click             reveal the item (new tab in Total Commander with the cursor on it, or Explorer)
  Right click              show the item's Properties
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== User settings =====
Folder          := ExpandEnv("%AppData%\Microsoft\Windows\Start Menu\Programs") ; <------------------------- folder with shortcuts
ShowHotkey      := "#z"                 ; hotkey to show the menu (# = Win)
TaskbarDblClick := 1                    ; 1 = double-click on empty taskbar space shows the menu
DarkMenu        := "auto"               ; "auto" = follow the Windows app theme, 1 = dark, 0 = light
TrayIcon        := RegExReplace(A_ScriptFullPath, "\.\w+$", ".ico")   ; "" = default AHK icon
MaxItems        := 50                  ; max menu entries, the rest is cut off (0 = no limit)
Debug           := 0                    ; 1 = message box with taskbar element info on every taskbar click (also copied to the clipboard)
; =========================

; The folder can also come from the command line; %Vars% are expanded, so "%AppData%\..." works too
if A_Args.Length
    Folder := ExpandEnv(A_Args[1])

menus   := Map()                        ; HMENU -> {menu, dir, names, loaded} for the root menu and its submenus
pending := ""                           ; [info, index, "R"|"M"] set by the menu hook

hookCb := CallbackCreate(MenuMsgFilter, "F", 3)
OnMessage(0x0117, InitPopup)            ; WM_INITMENUPOPUP: a submenu is about to open

; Dark/light popup menus via the undocumented uxtheme API (Windows 10 1903+), ignored if unavailable
dark := DarkMenu
if DarkMenu = "auto" {
    dark := 0
    try dark := !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
}
try {
    ux := DllCall("LoadLibrary", "str", "uxtheme", "ptr")
    DllCall(DllCall("GetProcAddress", "ptr", ux, "ptr", 135, "ptr"), "int", dark ? 2 : 3)   ; SetPreferredAppMode
    DllCall(DllCall("GetProcAddress", "ptr", ux, "ptr", 136, "ptr"))                        ; FlushMenuThemes
}

try
    Hotkey(ShowHotkey, (*) => ShowMenu())
catch {
    MsgBox("Invalid hotkey: " ShowHotkey)
    ExitApp
}

if TaskbarDblClick
    Hotkey("~LButton", TaskbarClick)

ShowMenu() {
    global menus, pending, Folder, hookCb
    menus := Map()
    root := {menu: Menu(), dir: RTrim(Folder, "\"), names: [], loaded: false}
    FillMenu(root)

    pending := ""
    hHook := DllCall("SetWindowsHookExW", "int", -1, "ptr", hookCb, "ptr", 0
        , "uint", DllCall("GetCurrentThreadId"), "ptr")    ; WH_MSGFILTER
    try {
        CoordMode("Menu", "Screen")
        ClampToWorkArea(&x, &y)
        root.menu.Show(x, y)
    } finally
        DllCall("UnhookWindowsHookEx", "ptr", hHook)

    if pending {
        info := pending[1]
        path := info.dir "\" info.names[pending[2] + 1]
        if pending[3] = "R"
            ShowProperties(path)
        else
            Reveal(path)
    }
}

; Reads info.dir and fills info.menu. Real subfolders get a submenu that is filled only when it opens.
FillMenu(info) {
    global menus, MaxItems
    info.loaded := true
    dir := info.dir, m := info.menu

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
    info.names := names

    if names.Length = 0 {
        m.Add("(empty)", (*) => 0)
        m.Disable("(empty)")
    } else {
        for name in names {
            full := dir "\" name
            label := StrReplace(name, "&", "&&")
            if InStr(FileExist(full), "D") {
                sub := Menu()
                sub.Add("...", (*) => 0)        ; placeholder, removed by InitPopup
                menus[sub.Handle] := {menu: sub, dir: full, names: [], loaded: false}
                m.Add(label, sub)
            } else
                m.Add(label, RunItem.Bind(full))
            SetItemIcon(m, label, full)
        }
        more := total - names.Length
        if more > 0 {
            moreLabel := "(+" more " more not shown)"
            m.Add()
            m.Add(moreLabel, (*) => 0)
            m.Disable(moreLabel)
        }
    }
    menus[m.Handle] := info
}

; Fills a submenu right before it is shown
InitPopup(wParam, lParam, msg, hwnd) {
    global menus
    if !menus.Has(wParam)
        return
    info := menus[wParam]
    if info.loaded
        return
    FillMenu(info)
    info.menu.Delete("...")             ; removed last, so the menu is never empty
}

; Cursor position, moved out of the taskbar to the nearest point of the monitor's work area
ClampToWorkArea(&x, &y) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if x >= ml && x < mr && y >= mt && y < mb {
            MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
            x := Min(Max(x, wl), wr - 1)
            y := Min(Max(y, wt), wb - 1)
            return
        }
    }
}

; Catches RMB/MMB inside the popup menu (native menus only report LMB)
MenuMsgFilter(code, wParam, lParam) {
    global pending, menus
    if code = 2 {                       ; MSGF_MENU
        msg := NumGet(lParam, A_PtrSize, "uint")
        if msg = 0x0205 || msg = 0x0208 {   ; WM_RBUTTONUP / WM_MBUTTONUP
            pt := NumGet(lParam, 4 * A_PtrSize + 4, "int64")
            for hMenu, info in menus {      ; the root menu or any opened submenu
                idx := DllCall("MenuItemFromPoint", "ptr", A_ScriptHwnd, "ptr", hMenu, "int64", pt, "int")
                if idx >= 0 && idx < info.names.Length {
                    pending := [info, idx, msg = 0x0205 ? "R" : "M"]
                    DllCall("EndMenu")
                    return 1
                }
            }
        }
    }
    return DllCall("CallNextHookEx", "ptr", 0, "int", code, "ptr", wParam, "ptr", lParam, "ptr")
}

; Double-click detection on empty taskbar space
TaskbarClick(*) {
    static last := 0, lx := 0, ly := 0
    if !TaskbarEmptySpot(&x, &y) {
        last := 0
        return
    }
    ; Same rule as Windows: within the double-click time and the double-click rectangle
    if last && A_TickCount - last <= DllCall("GetDoubleClickTime")
        && Abs(x - lx) <= DllCall("GetSystemMetrics", "int", 36) // 2    ; SM_CXDOUBLECLK
        && Abs(y - ly) <= DllCall("GetSystemMetrics", "int", 37) // 2 {  ; SM_CYDOUBLECLK
        last := 0
        KeyWait("LButton")              ; show on release, otherwise the menu eats the click
        ShowMenu()
    } else {
        last := A_TickCount, lx := x, ly := y
    }
}

; True if the cursor is over empty taskbar space (not over a button)
TaskbarEmptySpot(&x, &y) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y, &hwnd, &ctrl)
    if !hwnd
        return false
    cls := WinGetClass(hwnd)
    if cls != "Shell_TrayWnd" && cls != "Shell_SecondaryTrayWnd"
        return false
    ; Containers of the taskbar content (Windows 10 and 11); start button, clock, tray etc. are rejected
    ctrlOk := ctrl = "" || RegExMatch(ctrl, "^(MSTaskListWClass|MSTaskSwWClass|ReBarWindow32|Windows\.UI\.Composition\.DesktopWindowContentBridge)")
    if !ctrlOk && !Debug
        return false

    ; Ask UI Automation what is under the cursor; empty space is a container, not a button
    static uia := ""
    el := 0, type := 0, info := ""
    try {
        if !IsObject(uia)
            uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        ComCall(7, uia, "int64", (y << 32) | (x & 0xFFFFFFFF), "ptr*", &el)   ; ElementFromPoint
        ComCall(21, el, "int*", &type)                                        ; CurrentControlType
        if Debug
            info := "UIA class: " UIAString(el, 30) "`nUIA id: " UIAString(el, 29) "`nUIA name: " UIAString(el, 23)
        ObjRelease(el)
    } catch as e {
        if Debug
            DebugBox("UIA error: " e.Message)
        return false
    }
    ; ToolBar, Pane, Window, Group
    empty := ctrlOk && (type = 50021 || type = 50033 || type = 50032 || type = 50026)
    if Debug
        DebugBox("Window: " cls "`nControl: " ctrl "`nPos: " x ", " y "`nUIA type: " type "`n" info
            "`nEmpty spot: " (empty ? "yes" : "no"))
    return empty
}

DebugBox(text) {
    A_Clipboard := text
    MsgBox(text "`n`n(copied to clipboard)", "Launcher debug", 0x40000)
}

UIAString(el, idx) {
    p := 0
    ComCall(idx, el, "ptr*", &p)
    str := p ? StrGet(p) : ""
    DllCall("oleaut32\SysFreeString", "ptr", p)
    return str
}

; LMB / Enter (Shift held = run as admin)
RunItem(path, *) {
    RunPath(path, GetKeyState("Shift"))
}

RunPath(path, admin := false) {
    if !FileExist(path)
        return
    if RegExMatch(path, "i)\.lnk$") {       ; shortcut to a folder (also \\server\share): TC tab or Explorer
        target := ""
        try FileGetShortcut(path, &target)
        if target != "" && DirExist(target) {
            OpenFolder(target)
            return
        }
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

ShowProperties(path) {
    try Run('properties "' path '"')
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
    iconFile := path, iconNum := 1
    if RegExMatch(path, "i)\.lnk$")
        GetLnkIcon(path, &iconFile, &iconNum)
    ResolveIcon(&iconFile, &iconNum)
    try m.SetIcon(label, iconFile, iconNum)
}

; Files without an icon of their own: .msc keeps it inside its XML, others use the icon of their file type
ResolveIcon(&file, &num) {
    if DirExist(file) {                                     ; folder, or a shortcut to a folder
        file := "shell32.dll", num := 4
        return
    }
    if RegExMatch(file, "i)\.(exe|dll|ico|icl|cpl|ocx|scr|bmp|png|jpe?g|gif)$")
        return
    if RegExMatch(file, "i)\.msc$") && FileExist(file) {
        if RegExMatch(FileRead(file, "m8192"), '<Icon Index="(\d+)" File="([^"]+)"', &m)
            file := ExpandEnv(m[2]), num := m[1] + 1
        return
    }
    ; Icon registered for the file type, like Explorer does (.vbs, .ps1, .md ...)
    SplitPath(file, , , &ext)
    ids := []
    try ids.Push(RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\." ext "\UserChoice", "ProgId"))
    try ids.Push(RegRead("HKCR\." ext))
    for id in ids {
        def := ""
        try def := RegRead("HKCR\" id "\DefaultIcon")
        if !InStr(def, "%1") && RegExMatch(def, '^\s*"?([^"]+?)"?(?:\s*,\s*(-?\d+))?\s*$', &m) {
            idx := m[2] = "" ? 0 : m[2]
            file := ExpandEnv(m[1]), num := idx >= 0 ? idx + 1 : idx
            return
        }
    }
    file := "shell32.dll", num := 1                         ; generic file icon
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
