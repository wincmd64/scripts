; TASKBAR CLOCK. Drawn over the taskbar as a click-through layered topmost window
; Settings: an .ini with the same name as this file (created on the first run) and the "Clock" item of the tray menu.

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ===== Settings =====
; The values live in an .ini named like this file, next to it (created with these defaults on the first run).
; Change them from the "Clock" item of the tray menu (live preview) or edit the ini and reload the script.
tcDefs := [
    {name: "Opacity",          type: "int",   def: 80,       min: 1,    max: 100, note: "1..100 (percent)"},
    {name: "ShowSeconds",      type: "bool",  def: 1,        note: "1 = show the second hand, 0 = hide it"},
    {name: "SecondsColor",     type: "color", def: 0xFF0000, note: "color of the second hand, hex RRGGBB"},
    {name: "ShowTicks",        type: "bool",  def: 1,        note: "1 = 12 hour marks on the dial, 0 = plain circle"},
    {name: "Color",            type: "color", def: 0xFFFFFF, note: "color of the dial and the hands, hex RRGGBB (FFFFFF - white, FF0000 - red, 00FF00 - green, 0000FF - blue, FFFF00 - yellow)"},
    {name: "LineWidth",        type: "float", def: 1.6,      min: 0.5,  max: 8,   note: "line thickness in px at 100% scale"},
    {name: "Margin",           type: "int",   def: 0,        min: 0,    max: 200, note: "gap between the clock and the taskbar edges, px at 100% scale (0 = touch the edges)"},
    {name: "MonitorNum",       type: "int",   def: 0,        min: 0,    max: 16,  note: "0 = main taskbar, N = taskbar on monitor N"},
    {name: "CenterOnStart",    type: "bool",  def: 0,        note: "1 = put the clock in the middle of the Start button, 0 = middle of the taskbar"},
    {name: "OffsetX",          type: "int",   def: 0,        min: -500, max: 500, note: "shift from that center point, px at 100% scale"},
    {name: "OffsetY",          type: "int",   def: 0,        min: -500, max: 500, note: "shift from that center point, px at 100% scale"},
    {name: "HideInFullscreen", type: "bool",  def: 1,        note: "1 = hide while a fullscreen app / game is running or the screen is locked"},
    {name: "Debug",            type: "bool",  def: 0,        note: "1 = write a .log named like this file next to it (for troubleshooting)"},
    {name: "HourlyChime",      type: "bool",  def: 0,        note: "1 = play a sound at the start of every hour"},
    {name: "ChimeFromHour",    type: "int",   def: 8,        min: 0,    max: 23,  note: "chime only from this hour (0..23) ..."},
    {name: "ChimeToHour",      type: "int",   def: 21,       min: 0,    max: 23,  note: "... to this hour, inclusive"},
    {name: "ChimeMode",        type: "int",   def: 0,        min: 0,    max: 1,   note: "chime kind: 0 = play a sound file, 1 = say the time aloud"},
    {name: "ChimeFile",        type: "str",   def: "C:\Windows\Media\Windows Ding.wav", note: "sound file for ChimeMode 0"},
    {name: "ChimeText",        type: "str",   def: "точное время:", maxlen: 40, note: "words said before the time for ChimeMode 1 (may be empty, at most 40 characters)"}
]
SplitPath(A_LineFile, , &tcDir, , &tcName)      ; A_ScriptDir would be the main script's folder when this file is #Included
tcIni := tcDir "\" tcName ".ini"           ; the ini is named like the script (also when it is compiled)
tcCfg := Map()                          ; current values by name
tcGui := ""                             ; the settings window while it is open
logFile := ""
TcLoadSettings()
TcSyncGlobals()
; =========================

; Per-monitor DPI awareness, so coordinates are real pixels (no-op if the process is already set)
try DllCall("SetProcessDpiAwarenessContext", "ptr", -4)

; GDI+ startup
si := Buffer(24, 0)
NumPut("UInt", 1, si)
DllCall("gdiplus\GdiplusStartup", "ptr*", &gdipToken := 0, "ptr", si, "ptr", 0)

; Whole-window opacity goes into the blend function (AC_SRC_ALPHA keeps per-pixel alpha too)
blend := Buffer(4, 0)
NumPut("UChar", 0, "UChar", 0, "UChar", Round(Opacity * 255 / 100), "UChar", 1, blend)
ptSrc := Buffer(8, 0)
ptDst := Buffer(8, 0)
szBuf := Buffer(8, 0)

; Drawing surface state
Clk := {hdc: 0, hbm: 0, obm: 0, gfx: 0, pen: 0, penThin: 0, penSec: 0, tb: 0, size: 0, dpi: 0, key: "", shown: true}
clockGui := ""
hwnd := 0
CreateWindow()

OnExit(Cleanup)
TcApply()                               ; first Tick, chime and debug timers according to the settings
A_TrayMenu.Insert("1&", "Clock", TcShowSettings)        ; own item on top of the tray menu
if VerCompare(A_OSVersion, "10.0.22000") >= 0       ; Windows 11 only, other systems get the item without an icon
    try A_TrayMenu.SetIcon("Clock", "shell32.dll", 250)
; Keeping the clock above the taskbar: the taskbar is topmost too and rises above the clock when it is
; clicked or the Start menu opens. Out-of-context WinEvent hooks only notify us (nothing is injected into
; Explorer, Explorer never waits for us), so the clock is raised right after the event.
hookProc := CallbackCreate(WinEventProc, , 7)
hookFg   := DllCall("SetWinEventHook", "uint", 0x0003, "uint", 0x0003, "ptr", 0, "ptr", hookProc
    , "uint", 0, "uint", 0, "uint", 0, "ptr")       ; EVENT_SYSTEM_FOREGROUND, WINEVENT_OUTOFCONTEXT
hookZ    := DllCall("SetWinEventHook", "uint", 0x8004, "uint", 0x8004, "ptr", 0, "ptr", hookProc
    , "uint", 0, "uint", 0, "uint", 0, "ptr")       ; EVENT_OBJECT_REORDER (best effort)
SetTimer(Raise, 100)                    ; safety net for z-order changes that raise no event
SetTimer(Tick, 250)                     ; fast enough to keep the clock above the taskbar and to catch each new second

Tick() {
    if HideInFullscreen && IsFullscreen() {
        SetShown(false)
        return
    }
    tb := FindTaskbar()
    if !tb {                            ; taskbar not there (e.g. Explorer is restarting)
        SetShown(false)
        return
    }
    Clk.tb := tb                        ; remembered for the fast z-order check
    try WinGetPos(&tx, &ty, &tw, &th, tb)
    catch {
        SetShown(false)
        return
    }
    dpi  := GetDpi(tb)
    full := Min(tw, th)                 ; taskbar thickness (works for horizontal and vertical bars)

    ; Auto-hide: when the taskbar slides away, only a thin strip of it stays on the monitor
    GetMonitorRect(tb, &ml, &mt, &mr, &mb)
    visX := Min(tx + tw, mr) - Max(tx, ml)
    visY := Min(ty + th, mb) - Max(ty, mt)
    if Min(visX, visY) < full - 4 * dpi / 96 {
        SetShown(false)
        return
    }

    size := Max(12, Round(full - 2 * Margin * dpi / 96))          ; the clock always fits the taskbar thickness
    if Clk.size != size || Clk.dpi != dpi {
        BuildSurface(size, dpi)
        Clk.key := ""
    }

    ; Center point: the taskbar middle, or the Start button if requested and found
    cx := tx + tw // 2, cy := ty + th // 2
    if CenterOnStart && GetStartCenter(tb, &sx, &sy)
        && sx >= tx && sx < tx + tw && sy >= ty && sy < ty + th
        cx := sx, cy := sy
    x := cx - size // 2 + Round(OffsetX * dpi / 96)
    y := cy - size // 2 + Round(OffsetY * dpi / 96)

    SetShown(true)
    t   := A_Now                        ; YYYYMMDDHH24MISS, read once so all hands agree
    key := SubStr(t, 9, ShowSeconds ? 6 : 4) "|" x "," y
    if key != Clk.key {                   ; redraw only when the time or the position changed
        Clk.key := key
        Render(x, y, t)
    }

    Raise()
}

; Raises the clock above the taskbar if the taskbar is above it in the z-order (without activating it).
; Cheap: it only walks the z-order upwards from the clock window.
; Called from the WinEvent hooks, from a one-shot timer shortly after them and from a slow safety timer.
Raise() {
    tb := Clk.tb
    if !tb || !Clk.shown
        return
    h := hwnd, n := 0
    while (h := DllCall("GetWindow", "ptr", h, "uint", 3, "ptr")) && n++ < 64 {     ; GW_HWNDPREV: window above
        if h = tb {
            DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0
                , "uint", 0x13)         ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE
            return
        }
    }
}

; WinEvent callback: the foreground window changed (taskbar clicked, Start menu opened) or a window was reordered
WinEventProc(hHook, event, hwndEv, idObject, idChild, idThread, evTime) {
    if event = 0x8004 && idObject != 0      ; REORDER of a child object, not of a window
        return
    if event = 0x0003 && HideInFullscreen && IsFullscreen()     ; e.g. the lock screen became the foreground window
        SetShown(false)
    Raise()
    SetTimer(RaiseSoon, -30)            ; the taskbar may finish raising itself just after the event
}

RaiseSoon() {
    Raise()
}

; Draws the clock into the DIB and pushes it to the layered window
Render(x, y, t) {
    size := Clk.size, g := Clk.gfx
    c := size / 2
    w := Max(1, LineWidth * Clk.dpi / 96)
    inset := w / 2 + 0.5
    R := c - inset                      ; radius of the dial circle

    h := Integer(SubStr(t, 9, 2)), m := Integer(SubStr(t, 11, 2)), s := Integer(SubStr(t, 13, 2))

    DllCall("gdiplus\GdipGraphicsClear", "ptr", g, "uint", 0x00000000)
    DllCall("gdiplus\GdipDrawEllipse", "ptr", g, "ptr", Clk.pen
        , "float", inset, "float", inset, "float", size - 2 * inset, "float", size - 2 * inset)

    if ShowTicks {
        Loop 12 {
            a := (A_Index - 1) * 30
            Hand(g, Clk.penThin, c, a, R * (Mod(A_Index - 1, 3) = 0 ? 0.74 : 0.84), R * 0.95)   ; 12/3/6/9 marks are longer
        }
    }

    Hand(g, Clk.pen, c, (Mod(h, 12) + m / 60) * 30, 0, R * 0.50)      ; hour hand
    Hand(g, Clk.pen, c, (m + s / 60) * 6, 0, R * 0.72)                ; minute hand
    if ShowSeconds
        Hand(g, Clk.penSec, c, s * 6, 0, R * 0.85)                   ; second hand

    NumPut("Int", x, "Int", y, ptDst)
    NumPut("Int", size, "Int", size, szBuf)
    DllCall("UpdateLayeredWindow", "ptr", hwnd, "ptr", 0, "ptr", ptDst, "ptr", szBuf
        , "ptr", Clk.hdc, "ptr", ptSrc, "uint", 0, "ptr", blend, "uint", 2)   ; ULW_ALPHA
}

; Line from radius r1 to r2 at the given angle (degrees, 0 = 12 o'clock, clockwise)
Hand(g, pen, c, deg, r1, r2) {
    a := deg * 0.017453292519943295
    sn := Sin(a), cs := Cos(a)
    DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen
        , "float", c + r1 * sn, "float", c - r1 * cs
        , "float", c + r2 * sn, "float", c - r2 * cs)
}

; (Re)creates the DIB section, the GDI+ graphics and the pens for the given size / DPI
BuildSurface(size, dpi) {
    DestroySurface()
    w := Max(1, LineWidth * dpi / 96)

    Clk.hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", size, bi, 4)
    NumPut("Int", -size, bi, 8)         ; negative height = top-down bitmap
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)        ; 32 bpp BGRA
    Clk.hbm := DllCall("CreateDIBSection", "ptr", Clk.hdc, "ptr", bi, "uint", 0, "ptr*", &bits := 0
        , "ptr", 0, "uint", 0, "ptr")
    Clk.obm := DllCall("SelectObject", "ptr", Clk.hdc, "ptr", Clk.hbm, "ptr")

    DllCall("gdiplus\GdipCreateFromHDC", "ptr", Clk.hdc, "ptr*", &g := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", g, "int", 4)     ; anti-aliasing
    Clk.gfx := g

    DllCall("gdiplus\GdipCreatePen1", "uint", argb, "float", w, "int", 2, "ptr*", &p1 := 0)
    DllCall("gdiplus\GdipCreatePen1", "uint", argb, "float", Max(1, w * 0.6), "int", 2, "ptr*", &p2 := 0)
    DllCall("gdiplus\GdipCreatePen1", "uint", argbSec, "float", Max(1, w * 0.6), "int", 2, "ptr*", &p3 := 0)
    for p in [p1, p2, p3] {
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", p, "int", 2)   ; round caps
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", p, "int", 2)
    }
    Clk.pen := p1, Clk.penThin := p2, Clk.penSec := p3
    Clk.size := size, Clk.dpi := dpi
}

DestroySurface() {
    if !Clk.hdc
        return
    DllCall("gdiplus\GdipDeletePen", "ptr", Clk.pen)
    DllCall("gdiplus\GdipDeletePen", "ptr", Clk.penThin)
    DllCall("gdiplus\GdipDeletePen", "ptr", Clk.penSec)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", Clk.gfx)
    DllCall("SelectObject", "ptr", Clk.hdc, "ptr", Clk.obm)
    DllCall("DeleteObject", "ptr", Clk.hbm)
    DllCall("DeleteDC", "ptr", Clk.hdc)
    Clk.hdc := 0, Clk.size := 0, Clk.dpi := 0
}

; Creates the layered, click-through, no-activate topmost window
CreateWindow() {
    global clockGui, hwnd
    clockGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x80000 +E0x20 +E0x08000000")
    clockGui.Show("NA x-32000 y-32000 w1 h1")
    hwnd := clockGui.Hwnd
    Clk.shown := true
    Clk.key := ""
}

SetShown(visible) {
    if Clk.shown = visible
        return
    Clk.shown := visible
    DllCall("ShowWindow", "ptr", hwnd, "int", visible ? 8 : 0)      ; SW_SHOWNA / SW_HIDE
}

; Center of the Start button in screen coordinates; false if it cannot be found.
; Windows 11: UI Automation element with AutomationId "StartButton" (the name is localized, the id is not).
; Windows 10: the "Start" child window of the taskbar.
GetStartCenter(tb, &cx, &cy) {
    static uia := "", el := 0, elTb := 0, lastTry := 0
    rc := Buffer(16, 0)

    if el && elTb != tb {                       ; taskbar window changed (Explorer restart): drop the old element
        ObjRelease(el), el := 0
    }
    if !el && A_TickCount - lastTry > 2000 {    ; search is heavier than a rect query, so at most every 2 s
        lastTry := A_TickCount
        root := 0, cond := 0, found := 0, bstr := 0
        try {
            if !IsObject(uia)
                uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
            ComCall(6, uia, "ptr", tb, "ptr*", &root)                     ; ElementFromHandle
            bstr := DllCall("oleaut32\SysAllocString", "wstr", "StartButton", "ptr")
            v := Buffer(24, 0)                                            ; VARIANT: VT_BSTR + string pointer
            NumPut("ushort", 8, v, 0)
            NumPut("ptr", bstr, v, 8)
            ComCall(23, uia, "int", 30011, "ptr", v, "ptr*", &cond)       ; CreatePropertyCondition(AutomationId)
            ComCall(5, root, "int", 4, "ptr", cond, "ptr*", &found)       ; FindFirst(TreeScope_Descendants)
            if found
                el := found, elTb := tb
        }
        if bstr
            DllCall("oleaut32\SysFreeString", "ptr", bstr)
        if cond
            ObjRelease(cond)
        if root
            ObjRelease(root)
    }

    if el {
        try {
            ComCall(43, el, "ptr", rc)                                    ; CurrentBoundingRectangle
            if RectCenter(rc, &cx, &cy)
                return true
        } catch {
            ObjRelease(el), el := 0                                       ; stale element, search again later
        }
    }

    ; Windows 10 fallback
    hs := DllCall("FindWindowExW", "ptr", tb, "ptr", 0, "wstr", "Start", "ptr", 0, "ptr")
    if hs {
        DllCall("GetWindowRect", "ptr", hs, "ptr", rc)
        return RectCenter(rc, &cx, &cy)
    }
    return false
}

; Center of a RECT buffer; false if the rectangle is empty
RectCenter(rc, &cx, &cy) {
    l := NumGet(rc, 0, "int"), t := NumGet(rc, 4, "int"), r := NumGet(rc, 8, "int"), b := NumGet(rc, 12, "int")
    if r - l <= 0 || b - t <= 0
        return false
    cx := (l + r) // 2, cy := (t + b) // 2
    return true
}

; HWND of the taskbar the clock is drawn over: the main one (Shell_TrayWnd) or a secondary one (Shell_SecondaryTrayWnd)
FindTaskbar() {
    ; FindWindow ignores visibility: while the Start menu is open, WinExist() may not see the taskbar at all
    main := DllCall("FindWindowW", "wstr", "Shell_TrayWnd", "ptr", 0, "ptr")
    if MonitorNum <= 0
        return main
    prevHidden := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    list := WinGetList("ahk_class Shell_TrayWnd")
    for h in WinGetList("ahk_class Shell_SecondaryTrayWnd")
        list.Push(h)
    DetectHiddenWindows(prevHidden)
    for h in list {
        try {
            WinGetPos(&x, &y, &w, &hh, h)
            if MonitorAtPoint(x + w // 2, y + hh // 2) = MonitorNum
                return h
        }
    }
    return main                         ; requested monitor has no taskbar: fall back to the main one
}

MonitorAtPoint(px, py) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if px >= l && px < r && py >= t && py < b
            return A_Index
    }
    return 0
}

; Rectangle of the monitor the window belongs to (nearest one if the window is partly off-screen)
GetMonitorRect(hw, &l, &t, &r, &b) {
    hMon := DllCall("MonitorFromWindow", "ptr", hw, "uint", 2, "ptr")   ; MONITOR_DEFAULTTONEAREST
    mi := Buffer(40, 0)
    NumPut("UInt", 40, mi)
    DllCall("GetMonitorInfoW", "ptr", hMon, "ptr", mi)
    l := NumGet(mi, 4, "int"), t := NumGet(mi, 8, "int"), r := NumGet(mi, 12, "int"), b := NumGet(mi, 16, "int")
}

GetDpi(hw) {
    dpi := 0
    try dpi := DllCall("GetDpiForWindow", "ptr", hw, "uint")   ; Windows 10 1607+
    return dpi ? dpi : A_ScreenDPI
}

; True while the clock should be hidden: a fullscreen app, a D3D game, a presentation, or a locked screen
IsFullscreen() {
    st := 0
    try {
        DllCall("shell32\SHQueryUserNotificationState", "int*", &st)
        if st >= 1 && st <= 4               ; QUNS_NOT_PRESENT (locked / screen saver), QUNS_BUSY, QUNS_RUNNING_D3D_FULL_SCREEN, QUNS_PRESENTATION_MODE
            return true
    }
    ; The lock screen can be on screen while the state above still says "accepts notifications",
    ; e.g. right after resume from sleep (seen on Windows 10), so also look at the foreground window itself
    try {
        fg := DllCall("GetForegroundWindow", "ptr")
        if fg {
            proc := WinGetProcessName(fg)
            if proc = "LockApp.exe" || proc = "LogonUI.exe"
                return true
        }
    }
    return false
}

; Troubleshooting only (Debug := 1): appends a line to the .log file whenever the state changes
DebugLog() {
    static last := ""
    fs := 0
    DllCall("shell32\SHQueryUserNotificationState", "int*", &fs)
    fg := DllCall("GetForegroundWindow", "ptr")
    cls := "", proc := ""
    try cls := WinGetClass(fg)
    try proc := WinGetProcessName(fg)
    st := "shown=" Clk.shown " vis=" DllCall("IsWindowVisible", "ptr", hwnd) " fs=" fs " fg=" cls "|" proc " above=[" AboveList() "]"
    if st != last {
        last := st
        FileAppend(A_Hour ":" A_Min ":" A_Sec "." A_MSec "  " st "`n", logFile)
    }
}

; Plays the chime once at the start of each hour, within the configured hours
; Plays the chime chosen in the settings: a sound file or the time spoken aloud (the ">" buttons of the settings window test either kind)
Chime(mode := -1) {
    static voice := ""                  ; kept alive: asynchronous speech stops if the object is released
    if mode = -1
        mode := tcCfg["ChimeMode"]
    if mode = 1 {
        prefix := SubStr(Trim(tcCfg["ChimeText"]), 1, 40)      ; 40 characters is about 3 s of speech, no long monologues
        text := (prefix = "" ? "" : prefix " ") FormatTime(, "HH:mm")
        if !IsObject(voice)
            voice := ComObject("SAPI.SpVoice")
        voice.Speak(text, 1)            ; SVSFlagsAsync: does not block the script
    } else if tcCfg["ChimeFile"] != "" {
        ; MCI instead of SoundPlay: it can be stopped, so a long file is cut off after 3 seconds
        StopChime()
        DllCall("winmm\mciSendStringW", "str", 'open "' tcCfg["ChimeFile"] '" alias tcchime', "ptr", 0, "uint", 0, "ptr", 0)
        DllCall("winmm\mciSendStringW", "str", "play tcchime", "ptr", 0, "uint", 0, "ptr", 0)   ; asynchronous
        SetTimer(StopChime, -3000)
    }
}

StopChime() {
    DllCall("winmm\mciSendStringW", "str", "close tcchime", "ptr", 0, "uint", 0, "ptr", 0)
}

CheckChime() {
    static lastHour := ""
    hour := Integer(A_Hour)
    stamp := A_YYYY A_MM A_DD A_Hour
    ; A_Sec < 5: do not chime late if the script is started / reloaded in the middle of an hour
    if A_Min = "00" && A_Sec < 5 && stamp != lastHour && hour >= ChimeFromHour && hour <= ChimeToHour {
        lastHour := stamp               ; once per hour, so no Sleep / Wait is needed
        try Chime()
    }
}

Cleanup(*) {
    Critical                            ; nobody interrupts the cleanup, in particular the Tick timer
    SetTimer(CheckChime, 0)
    StopChime()                         ; do not leave the MCI device open
    SetTimer(Raise, 0)
    DllCall("UnhookWinEvent", "ptr", hookFg)
    DllCall("UnhookWinEvent", "ptr", hookZ)
    CallbackFree(hookProc)
    SetTimer(Tick, 0)                   ; Tick must not touch GDI+ objects while / after they are destroyed
    try tcGui.Destroy()                 ; the settings window, if it is open
    DllCall("ShowWindow", "ptr", hwnd, "int", 0)
    DestroySurface()
    ; GdiplusShutdown is intentionally not called: the process is exiting anyway, the OS frees GDI+,
    ; and calling it on Reload / Exit crashed with 0xC0000005
}

; Troubleshooting only: visible windows that are above the clock in the z-order (nearest first, at most 12 checked)
AboveList() {
    out := "", h := hwnd, n := 0
    while (h := DllCall("GetWindow", "ptr", h, "uint", 3, "ptr")) && n++ < 12 {     ; GW_HWNDPREV: window above
        if !DllCall("IsWindowVisible", "ptr", h)
            continue
        cls := "", proc := ""
        try cls := WinGetClass(h)
        try proc := WinGetProcessName(h)
        out .= (out = "" ? "" : ", ") cls "|" proc
    }
    return out
}

; ---------------------------------------------------------------------------------------------
; Settings: ini file, live apply and the settings window
; ---------------------------------------------------------------------------------------------

TcDef(name) {
    for d in tcDefs
        if d.name = name
            return d
}

TcClamp(d, v) {
    if d.HasOwnProp("min")
        v := Min(Max(v, d.min), d.max)
    return v
}

; Text from the ini -> a valid value (the default if the text is empty or broken)
TcParse(d, raw) {
    if raw = "<missing>"
        return d.def
    if d.type = "str"                   ; an empty text is a valid value
        return d.HasOwnProp("maxlen") ? SubStr(Trim(raw), 1, d.maxlen) : Trim(raw)
    raw := Trim(raw)
    if raw = ""
        return d.def
    try {
        switch d.type {
            case "color":
                v := Integer("0x" RegExReplace(raw, "i)^(#|0x)")) & 0xFFFFFF
            case "float":
                v := Round(Float(StrReplace(raw, ",", ".")), 2)
            case "bool":
                v := Integer(raw) ? 1 : 0
            default:
                v := Integer(raw)
        }
    } catch {
        return d.def
    }
    if d.HasOwnProp("min") && (v < d.min || v > d.max)
        return d.def                    ; out of range in the ini: use the default
    return v
}

; 1.6 -> "1.6" (no binary floating point noise like 1.6000000000000001)
TcNum(v) {
    t := Format("{:.2f}", v)
    return RTrim(RTrim(t, "0"), ".")
}

; Value -> text for the ini
TcFormat(d, v) {
    switch d.type {
        case "color":
            return Format("{:06X}", v)
        case "float":
            return TcNum(v)
        default:
            return String(v)
    }
}

TcCreateIni() {
    text := "; Taskbar clock settings. Change them from the tray menu item 'Clock' (or edit this file and reload the script).`n"
    text .= "; Colors are hex RRGGBB.`n`n[Clock]`n"
    for d in tcDefs
        text .= "; " d.note "`n" d.name "=" TcFormat(d, d.def) "`n`n"
    FileAppend(text, tcIni, "UTF-16")
}

TcLoadSettings() {
    if !FileExist(tcIni)
        try TcCreateIni()               ; no write access: just run with the defaults
    TcDef("MonitorNum").max := Max(1, MonitorGetCount())    ; no point in a monitor number that does not exist
    for d in tcDefs
        tcCfg[d.name] := TcParse(d, IniRead(tcIni, "Clock", d.name, "<missing>"))
}

TcSaveIni() {
    for d in tcDefs
        try IniWrite(TcFormat(d, tcCfg[d.name]), tcIni, "Clock", d.name)
}

; The rest of the script reads plain global variables, so copy the values there
TcSyncGlobals() {
    global Opacity, ShowSeconds, SecondsColor, ShowTicks, Color, LineWidth, Margin, MonitorNum
        , CenterOnStart, OffsetX, OffsetY, HideInFullscreen, Debug, HourlyChime, ChimeFromHour, ChimeToHour
        , argb, argbSec
    Opacity          := tcCfg["Opacity"]
    ShowSeconds      := tcCfg["ShowSeconds"]
    SecondsColor     := tcCfg["SecondsColor"]
    ShowTicks        := tcCfg["ShowTicks"]
    Color            := tcCfg["Color"]
    LineWidth        := tcCfg["LineWidth"]
    Margin           := tcCfg["Margin"]
    MonitorNum       := tcCfg["MonitorNum"]
    CenterOnStart    := tcCfg["CenterOnStart"]
    OffsetX          := tcCfg["OffsetX"]
    OffsetY          := tcCfg["OffsetY"]
    HideInFullscreen := tcCfg["HideInFullscreen"]
    Debug            := tcCfg["Debug"]
    HourlyChime      := tcCfg["HourlyChime"]
    ChimeFromHour    := tcCfg["ChimeFromHour"]
    ChimeToHour      := tcCfg["ChimeToHour"]
    argb    := 0xFF000000 | Color
    argbSec := 0xFF000000 | SecondsColor
}

; Applies tcCfg to the running clock (used at start and for the live preview in the settings window)
TcApply() {
    Critical
    TcSyncGlobals()
    NumPut("UChar", Round(Opacity * 255 / 100), blend, 2)       ; SourceConstantAlpha of the BLENDFUNCTION
    Clk.size := 0, Clk.key := ""        ; rebuild the pens and redraw
    SetTimer(CheckChime, HourlyChime ? 1000 : 0)
    TcApplyDebug()
    Tick()
    Critical "Off"
}

TcApplyDebug() {
    global logFile
    static on := false
    if Debug && !on {
        logFile := tcDir "\" tcName ".log"
        try FileDelete(logFile)
        SetTimer(DebugLog, 100)
    } else if !Debug && on {
        SetTimer(DebugLog, 0)
    }
    on := Debug ? true : false
}

; Standard Windows color dialog (comdlg32 ChooseColor); returns RGB or "" if cancelled
TcPickColor(owner, rgb) {
    static custom := Buffer(64, 0)      ; the 16 custom color slots, kept while the script runs
    static ready := false
    if !ready {
        loop 16
            NumPut("UInt", 0xFFFFFF, custom, (A_Index - 1) * 4)
        ready := true
    }
    sz := 9 * A_PtrSize                 ; sizeof(CHOOSECOLORW): 72 bytes on x64, 36 on x86
    cc := Buffer(sz, 0)
    NumPut("UInt", sz, cc, 0)                                   ; lStructSize
    NumPut("Ptr", owner, cc, A_PtrSize)                         ; hwndOwner
    NumPut("UInt", ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF), cc, 3 * A_PtrSize)   ; rgbResult (COLORREF = BGR)
    NumPut("Ptr", custom.Ptr, cc, 4 * A_PtrSize)                ; lpCustColors
    NumPut("UInt", 0x103, cc, 5 * A_PtrSize)                    ; CC_RGBINIT | CC_FULLOPEN | CC_ANYCOLOR
    if !DllCall("comdlg32\ChooseColorW", "ptr", cc, "int")
        return ""
    c := NumGet(cc, 3 * A_PtrSize, "UInt")
    return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
}

; The settings window: every change is applied to the clock at once, OK saves to the ini, Cancel reverts
TcShowSettings(*) {
    global tcGui
    if IsObject(tcGui) {
        tcGui.Show()
        return
    }
    snap := tcCfg.Clone()               ; values at the moment of opening, restored by Cancel
    chimeCtls := []
    g := Gui("-MinimizeBox -MaximizeBox", "Taskbar clock")
    tcGui := g
    ctl := Map()

    ; ---- handlers ----
    OnBool(name, c, *) {
        tcCfg[name] := c.Value ? 1 : 0
        if name = "HourlyChime"
            SetChimeEnabled()
        TcApply()
    }
    OnNum(name, c, *) {
        d := TcDef(name)
        try
            v := (d.type = "float") ? Float(StrReplace(c.Value, ",", ".")) : Integer(c.Value)
        catch
            return                      ; incomplete text while typing, for example "-"
        if d.HasOwnProp("min") && (v < d.min || v > d.max)
            return                      ; out of range: keep the previous value (the field is corrected on losing focus)
        tcCfg[name] := v
        TcApply()
    }
    OnStr(name, c, *) {
        tcCfg[name] := c.Value
    }
    ; When an edit loses focus show the value that is really in use (clamped, tidy number)
    Norm(name, c, *) {
        d := TcDef(name)
        c.Value := (d.type = "float") ? TcNum(tcCfg[name]) : tcCfg[name]
    }
    OnMode(n, *) {
        tcCfg["ChimeMode"] := n
        ctl["ChimeMode0"].Value := (n = 0)
        ctl["ChimeMode1"].Value := (n = 1)
    }
    Browse(*) {
        g.Opt("+OwnDialogs")
        f := FileSelect(1, tcCfg["ChimeFile"], "Choose the chime sound", "Sound (*.wav; *.mp3)")
        if f = ""
            return
        tcCfg["ChimeFile"] := f
        ctl["ChimeFile"].Value := f
        OnMode(0)
    }
    TestChime(mode, *) {
        try Chime(mode)
    }
    ; Everything about the chime is greyed out while "Hourly chime" is off
    SetChimeEnabled() {
        for c in chimeCtls
            c.Enabled := tcCfg["HourlyChime"] ? true : false
    }
    OnSlider(c, *) {
        tcCfg["Opacity"] := c.Value
        ctl["OpacityTxt"].Text := c.Value "%"
        TcApply()
    }
    Pick(name, *) {
        c := TcPickColor(g.Hwnd, tcCfg[name])
        if c = ""
            return
        tcCfg[name] := c
        ctl[name].Opt("Background" Format("{:06X}", c))
        ctl[name].Redraw()
        TcApply()
    }
    Done() {
        global tcGui
        tcGui := ""
        g.Destroy()
    }
    Save(*) {
        TcSaveIni()
        Done()
    }
    Cancel(*) {
        for k, v in snap
            tcCfg[k] := v
        TcApply()
        Done()
    }
    Reset(*) {
        for d in tcDefs
            tcCfg[d.name] := d.def
        for d in tcDefs {
            if d.name = "ChimeMode" {
                ctl["ChimeMode0"].Value := (tcCfg["ChimeMode"] = 0)
                ctl["ChimeMode1"].Value := (tcCfg["ChimeMode"] = 1)
                continue
            }
            c := ctl[d.name]
            if d.type = "color" {
                c.Opt("Background" Format("{:06X}", tcCfg[d.name]))
                c.Redraw()
            } else
                c.Value := (d.type = "float") ? TcNum(tcCfg[d.name]) : tcCfg[d.name]
        }
        ctl["OpacityTxt"].Text := tcCfg["Opacity"] "%"
        SetChimeEnabled()
        TcApply()
    }

    ; ---- row builders ----
    ColorRow(label, name) {
        g.AddText("xm y+6 w170 h24 +0x200", label)
        ctl[name] := g.AddText("x+0 yp+1 w48 h22 +Border Background" Format("{:06X}", tcCfg[name]))
        g.AddButton("x+8 yp-1 w96 h24", "Choose...").OnEvent("Click", Pick.Bind(name))
    }
    Check(opts, label, name) {
        ctl[name] := g.AddCheckbox(opts, label)
        ctl[name].Value := tcCfg[name]
        ctl[name].OnEvent("Click", OnBool.Bind(name))
    }
    NumRow(label, name, lo, hi) {
        g.AddText("xm y+6 w170 h24 +0x200", label)
        ctl[name] := g.AddEdit("x+0 yp w64 r1", tcCfg[name])
        g.AddUpDown("Range" lo "-" hi, tcCfg[name])
        ctl[name].OnEvent("Change", OnNum.Bind(name))
        ctl[name].OnEvent("LoseFocus", Norm.Bind(name))
    }
    HourEdit(opts, name) {
        ctl[name] := g.AddEdit(opts " r1", tcCfg[name])
        chimeCtls.Push(ctl[name], g.AddUpDown("Range0-23", tcCfg[name]))
        ctl[name].OnEvent("Change", OnNum.Bind(name))
        ctl[name].OnEvent("LoseFocus", Norm.Bind(name))
    }

    ; ---- layout ----
    g.SetFont("s9", "Segoe UI")
    g.MarginX := 14, g.MarginY := 12

    g.AddText("xm w340", "Dial").SetFont("bold")
    ColorRow("Dial and hands color", "Color")
    ColorRow("Second hand color", "SecondsColor")
    Check("xm y+8 w160", "Second hand", "ShowSeconds")
    Check("x+10 yp w160", "Hour marks", "ShowTicks")
    g.AddText("xm y+8 w170 h24 +0x200", "Line width, px")
    ctl["LineWidth"] := g.AddEdit("x+0 yp w64 r1", TcNum(tcCfg["LineWidth"]))
    ctl["LineWidth"].OnEvent("Change", OnNum.Bind("LineWidth"))
    ctl["LineWidth"].OnEvent("LoseFocus", Norm.Bind("LineWidth"))
    g.AddText("xm y+6 w170 h24 +0x200", "Opacity")
    ctl["Opacity"] := g.AddSlider("x+0 yp w130 Range1-100 TickInterval10 ToolTip", tcCfg["Opacity"])
    ctl["OpacityTxt"] := g.AddText("x+6 yp w40 h24 +0x200", tcCfg["Opacity"] "%")
    ctl["Opacity"].OnEvent("Change", OnSlider)

    g.AddText("xm y+16 w340", "Position").SetFont("bold")
    NumRow("Margin, px", "Margin", 0, 200)
    NumRow("Offset X, px", "OffsetX", -500, 500)
    NumRow("Offset Y, px", "OffsetY", -500, 500)
    NumRow("Taskbar monitor (0 = main)", "MonitorNum", 0, TcDef("MonitorNum").max)
    Check("xm y+8 w320", "Center on the Start button", "CenterOnStart")

    g.AddText("xm y+16 w340", "Behavior").SetFont("bold")
    Check("xm y+8 w320", "Hide in fullscreen apps and on the lock screen", "HideInFullscreen")
    Check("xm y+8 w110", "Hourly chime", "HourlyChime")
    chimeCtls.Push(g.AddText("x+6 yp w34 h24 +0x200", "from"))
    HourEdit("x+0 yp w52", "ChimeFromHour")
    chimeCtls.Push(g.AddText("x+8 yp w22 h24 +0x200", "to"))
    HourEdit("x+0 yp w52", "ChimeToHour")
    ctl["ChimeMode0"] := g.AddRadio("xm+20 y+8 w300 Group", "Play a sound file (first 3 seconds)")
    ctl["ChimeMode0"].Value := (tcCfg["ChimeMode"] = 0)
    ctl["ChimeMode0"].OnEvent("Click", (*) => OnMode(0))
    bTestF := g.AddButton("xm+20 y+4 w34 h24", ">")
    bTestF.OnEvent("Click", TestChime.Bind(0))
    ctl["ChimeFile"] := g.AddEdit("x+6 yp+1 w185 r1", tcCfg["ChimeFile"])
    ctl["ChimeFile"].OnEvent("Change", OnStr.Bind("ChimeFile"))
    bBrowse := g.AddButton("x+6 yp-1 w70 h24", "Browse...")
    bBrowse.OnEvent("Click", Browse)
    ctl["ChimeMode1"] := g.AddRadio("xm+20 y+8 w300 Group", "Say the time aloud, preceded by:")
    ctl["ChimeMode1"].Value := (tcCfg["ChimeMode"] = 1)
    ctl["ChimeMode1"].OnEvent("Click", (*) => OnMode(1))
    bTestS := g.AddButton("xm+20 y+4 w34 h24", ">")
    bTestS.OnEvent("Click", TestChime.Bind(1))
    ctl["ChimeText"] := g.AddEdit("x+6 yp+1 w261 r1 Limit40", tcCfg["ChimeText"])
    ctl["ChimeText"].OnEvent("Change", OnStr.Bind("ChimeText"))
    chimeCtls.Push(ctl["ChimeMode0"], ctl["ChimeFile"], bBrowse, bTestF, ctl["ChimeMode1"], ctl["ChimeText"], bTestS)
    SetChimeEnabled()
    Check("xm y+8 w320", "Write debug log", "Debug")

    g.AddButton("xm y+18 w90 Default", "OK").OnEvent("Click", Save)
    g.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", Cancel)
    g.AddButton("x+8 yp w90", "Reset").OnEvent("Click", Reset)
    g.OnEvent("Close", Cancel)
    g.OnEvent("Escape", Cancel)
    g.Show()
}
