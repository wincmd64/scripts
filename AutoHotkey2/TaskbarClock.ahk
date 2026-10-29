; TASKBAR CLOCK. Drawn on the taskbar as a click-through layered child window

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ===== User settings =====
Opacity          := 80          ; 1..100 (percent)
ShowSeconds      := 1           ; 1 = show the second hand, 0 = hide it
SecondsColor     := 0xFF0000    ; RGB color of the second hand
ShowTicks        := 1           ; 1 = 12 hour marks on the dial, 0 = plain circle
Color            := 0xFFFFFF    ; RGB (0xFFFFFF - white, 0xFF0000 - red, 0x00FF00 - green, 0x0000FF - blue, 0xFFFF00 - yellow)
LineWidth        := 1.6         ; line thickness in px at 100% scale
Margin           := 0           ; gap between the clock and the taskbar edges, px at 100% scale (0 = touch the edges)
MonitorNum       := 0           ; 0 = main taskbar, N = taskbar on monitor N
CenterOnStart    := 0           ; 1 = put the clock in the middle of the Start button, 0 = middle of the taskbar
OffsetX          := 0           ; shift from that center point, px at 100% scale
OffsetY          := 0
HideInFullscreen := 1           ; 1 = hide while a fullscreen app / game is running or the screen is locked
Debug            := 0           ; 1 = write TaskbarClock.log next to this file (for troubleshooting)
HourlyChime      := 0           ; 1 = play a sound at the start of every hour
ChimeFromHour    := 8           ; chime only from this hour (0..23) ...
ChimeToHour      := 21          ; ... to this hour, inclusive
; =========================

Opacity := Min(Max(Integer(Opacity), 1), 100)
argb    := 0xFF000000 | Color
argbSec := 0xFF000000 | SecondsColor

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
Tick()
if HourlyChime
    SetTimer(CheckChime, 1000)
if Debug {
    SplitPath(A_LineFile, , &logDir)    ; A_ScriptDir would be the main script's folder when this file is #Included
    logFile := logDir "\TaskbarClock.log"
    try FileDelete(logFile)
    SetTimer(DebugLog, 100)
}
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
        return st >= 1 && st <= 4           ; QUNS_NOT_PRESENT (locked / screen saver), QUNS_BUSY, QUNS_RUNNING_D3D_FULL_SCREEN, QUNS_PRESENTATION_MODE
    }
    return false
}

; Troubleshooting only (Debug := 1): appends a line to TaskbarClock.log whenever the state changes
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
CheckChime() {
    static lastHour := ""
    hour := Integer(A_Hour)
    stamp := A_YYYY A_MM A_DD A_Hour
    ; A_Sec < 5: do not chime late if the script is started / reloaded in the middle of an hour
    if A_Min = "00" && A_Sec < 5 && stamp != lastHour && hour >= ChimeFromHour && hour <= ChimeToHour {
        lastHour := stamp               ; once per hour, so no Sleep / Wait is needed
        ; ---- What to do on the hour: edit freely, keep one of these or write your own ----
        try SoundPlay("C:\Windows\Media\Windows Ding.wav")        ; asynchronous, does not block the clock
        ; try ComObject("SAPI.SpVoice").Speak("time: " FormatTime(, "HH:mm"))
        ; try SoundBeep(750, 500)
        ; ----------------------------------------------------------------------------------
    }
}

Cleanup(*) {
    Critical                            ; nobody interrupts the cleanup, in particular the Tick timer
    SetTimer(CheckChime, 0)
    SetTimer(Raise, 0)
    DllCall("UnhookWinEvent", "ptr", hookFg)
    DllCall("UnhookWinEvent", "ptr", hookZ)
    CallbackFree(hookProc)
    SetTimer(Tick, 0)                   ; Tick must not touch GDI+ objects while / after they are destroyed
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
