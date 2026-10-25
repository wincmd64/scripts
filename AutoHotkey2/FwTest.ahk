/*
    Outbound firewall tester
    Every check runs inside THIS process, so a per-program firewall rule applies to all of them.
    Compile with the 64-bit v2 base file, then try block the exe.
*/

#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------------- Test list (edit freely) ----------------
; Only checks that a per-program firewall rule can actually affect.
; type: tcp | udpdns | http   (dns and icmp are still implemented below,
; but they go through system services, so a per-program rule never sees them)
Tests := [
    {type: "tcp",    proto: "TCP",   name: "TCP connect (Cloudflare)", target: "1.1.1.1", port: 443},
    {type: "tcp",    proto: "TCP",   name: "TCP connect (Google)",     target: "8.8.8.8", port: 443},
    {type: "udpdns", proto: "UDP",   name: "UDP DNS query",            target: "1.1.1.1", port: 53},
    {type: "http",   proto: "HTTPS", name: "HTTPS request (WinHTTP)",  target: "https://www.google.com/generate_204"}
]

Theme := "system" ; "system", "dark", or "light" - "system" reads the current
                   ; Windows app theme (light/dark) from the registry

; ---------------- Winsock init ----------------
wsa := Buffer(408, 0)
if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsa, "Int") != 0 {
    MsgBox("WSAStartup failed", "FwTest", 16)
    ExitApp()
}
OnExit((*) => DllCall("ws2_32\WSACleanup"))

; ---------------- Theme colors ----------------
Dark := (GetEffectiveTheme() = "dark")
ClrText  := Dark ? "cE6E6E6" : "cDefault"
ClrGreen := Dark ? "c4CD04C" : "c00A000"
ClrRed   := Dark ? "cFF5555" : "cRed"
OkColor  := Dark ? 0x4CD04C : 0x00A000   ; COLORREF 0x00BBGGRR

; ---------------- GUI ----------------
g := Gui(, "Outbound firewall tester")
g.SetFont("s9 " ClrText, "Segoe UI")
g.Opt("+OwnDialogs")
g.MarginX := 12
g.MarginY := 10
if Dark
    g.BackColor := "1E1E1E"
status := g.Add("Text", "w760 h44 Center +0x200", "")
status.SetFont("s20 bold cGray")
detail := g.Add("Text", "xm w760 Center", "")
; Label is right-aligned and the value left-aligned, so the colon sits in the middle
ruleLbl := g.Add("Text", "xm w380 Right", "Firewall rule for this exe:")
ruleVal := g.Add("Text", "x+4 yp w370", "...")
colTitles := ["#", "Test", "Proto", "Target", "Result", "ms", "Details"]
colWidths := [30, 155, 55, 130, 75, 40, 255]
if Dark {
    ; The native header ignores custom text colors under the dark theme (black on dark),
    ; so the real header is hidden (-Hdr) and a row of Text controls is drawn instead.
    ; Each cell is one pixel narrower than its column, which leaves a thin divider.
    for i, title in colTitles {
        opt := (i = 1 ? "xm" : "x+1 yp") " w" (colWidths[i] - 1) " h22 +0x200 Background2D2D2D cE6E6E6"
        g.Add("Text", opt, " " title)
    }
    g.Add("Text", "x+1 yp w20 h22 Background2D2D2D", "")
}
lv := g.Add("ListView", (Dark ? "xm y+0" : "xm") " w760 r6 -Multi" (Dark ? " -Hdr -E0x200 Background262626 cE6E6E6" : " +Grid"), colTitles)
for i, w in colWidths
    lv.ModifyCol(i, w)
lv.OnNotify(-12, LvCustomDraw)   ; NM_CUSTOMDRAW
lv.OnEvent("DoubleClick", LvDoubleClick)
btnRun := g.Add("Button", "xm w120", "Retest")
btnCopy := g.Add("Button", "x+8 w120", "Copy results")
btnOK := g.Add("Button", "xm+640 yp w120 Default", "OK")

btnRun.OnEvent("Click", (*) => StartRun())
btnCopy.OnEvent("Click", (*) => CopyResults())
btnOK.OnEvent("Click", (*) => ExitApp())
g.OnEvent("Escape", (*) => ExitApp())
g.OnEvent("Close", (*) => ExitApp())
if Dark
    ApplyDarkMode()
g.Show()
btnOK.Focus()
StartRun()
return

; ---------------- Theme helpers ----------------
; "light"/"dark" pass through as-is, "system" reads the current
; Windows apps theme from the registry
GetEffectiveTheme() {
    global Theme
    t := StrLower(Theme)
    if (t = "dark" || t = "light")
        return t
    try {
        lightMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        return (lightMode = 0) ? "dark" : "light"
    } catch {
        return "light" ; fall back if the registry value doesn't exist
    }
}

; Dark title bar and dark-themed native controls (best effort, Windows 10 1903+)
ApplyDarkMode() {
    buf := Buffer(4, 0)
    NumPut("Int", 1, buf)
    ; DWMWA_USE_IMMERSIVE_DARK_MODE is 20 on recent builds, 19 on older Windows 10
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Ptr", buf, "Int", 4) != 0
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 19, "Ptr", buf, "Int", 4)
    ; uxtheme ordinal 135 = SetPreferredAppMode (2 = ForceDark)
    try {
        hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        fn := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        if fn
            DllCall(fn, "Int", 2)
    }
    for ctrl in [lv, btnRun, btnCopy, btnOK]
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

; ---------------- ListView cell coloring ----------------
; Green text for "OK" in the Result column (column index 4, zero-based)
LvCustomDraw(ctrl, lParam) {
    is64 := (A_PtrSize = 8)
    stage := NumGet(lParam, is64 ? 24 : 12, "UInt")
    if (stage = 0x1)                 ; CDDS_PREPAINT
        return 0x20                  ; CDRF_NOTIFYITEMDRAW
    if (stage = 0x10001)             ; CDDS_ITEMPREPAINT
        return 0x20                  ; CDRF_NOTIFYSUBITEMDRAW
    if (stage = 0x30001) {           ; CDDS_ITEMPREPAINT | CDDS_SUBITEM
        if (NumGet(lParam, is64 ? 88 : 56, "Int") = 4) {
            row := NumGet(lParam, is64 ? 56 : 36, "UPtr") + 1
            if (lv.GetText(row, 5) = "OK") {
                NumPut("UInt", OkColor, lParam, is64 ? 80 : 48)
                return 0x2           ; CDRF_NEWFONT
            }
        }
    }
    return 0
}

; ---------------- Row details (double click) ----------------
LvDoubleClick(ctrl, row) {
    if (row < 1 || row > Tests.Length)
        return
    t := Tests[row]
    st := lv.GetText(row, 5)
    txt := "#" row "  " t.name "`n"
    txt .= "Target: " TargetText(t) "`n"
    txt .= "Result: " st "  (" lv.GetText(row, 6) " ms)`n"
    txt .= "Details: " lv.GetText(row, 7) "`n`n"
    txt .= "What was tested:`n" TestInfo(t) "`n`n"
    txt .= "What this result means:`n" ExplainResult(st)
    MsgBox(txt, "FwTest - test details", "Iconi")
}

TestInfo(t) {
    switch t.type {
        case "tcp":
            return "Opens a plain TCP connection to " TargetText(t) " by IP address (so DNS is not involved) and closes it right away; nothing is sent. This is the first step every program makes before talking over HTTPS, so it is the most direct check of a per-program block."
        case "udpdns":
            return "Sends one DNS query packet over UDP to the resolver at " TargetText(t) " and waits up to 2 seconds for a reply. The name being asked about (google.com) is arbitrary and unrelated to the server; any name would do. UDP has no handshake, so sending succeeds locally even if the packet is dropped later. The only proof that traffic passes is a reply datagram with the matching transaction ID."
        case "http":
            return "Sends an HTTP HEAD request (headers only, no page body) to " t.target " using WinHTTP, the Windows library many programs use for web access, and reads the status code. Any HTTP status means the connection itself worked (204 is the normal answer for this URL)."
        case "dns":
            return "Asks the Windows resolver to look up " t.target ". The lookup is done by a system service, not by this program, so a per-program rule usually does not affect it."
        case "icmp":
            return "Sends one ping (ICMP echo) to " t.target " through a Windows system API, so a per-program rule usually does not affect it."
    }
    return ""
}

ExplainResult(st) {
    switch st {
        case "OK":
            return "The connection worked, so nothing blocked this test."
        case "BLOCKED":
            return "Windows refused the connection on this PC (error 10013) before anything left the machine. This is how a firewall block normally looks."
        case "TIMEOUT":
            return "No answer arrived in time. A firewall that silently drops traffic looks like this, but so does a network problem."
        case "REFUSED":
            return "The remote host was reached but the port is closed, so nothing local blocked it."
        case "NO ROUTE":
            return "There is no network route for this test (for example no IPv6)."
        case "ERROR":
            return "The test failed for another reason; see Details for the error text."
    }
    return "The test has not finished yet."
}

; ---------------- Run control ----------------
StartRun() {
    global idx
    idx := 0
    btnRun.Enabled := false
    status.SetFont("cGray")
    status.Text := "Testing..."
    detail.Text := ""
    lv.Delete()
    for t in Tests
        lv.Add("", A_Index, t.name, t.proto, TargetText(t), "...", "", "")
    SetTimer(Step, -20)
}

; One test per timer tick, so the GUI stays alive between blocking calls
Step() {
    global idx
    idx++
    t := Tests[idx]
    r := RunTest(t)
    lv.Modify(idx, "", idx, t.name, t.proto, TargetText(t), r.st, r.ms, r.detail)
    if idx < Tests.Length
        SetTimer(Step, -10)
    else
        Finish()
}

Finish() {
    total := lv.GetCount()
    open := 0
    blocked := 0
    timeouts := 0
    Loop total {
        st := lv.GetText(A_Index, 5)
        if (st = "OK" || st = "REFUSED")
            open++
        else if (st = "BLOCKED")
            blocked++
        else if (st = "TIMEOUT")
            timeouts++
    }
    other := total - open - blocked - timeouts

    ; Breakdown of everything that did not get through
    parts := ""
    if blocked
        parts .= blocked " denied locally (10013)"
    if timeouts
        parts .= (parts ? ", " : "") timeouts " timed out"
    if other
        parts .= (parts ? ", " : "") other " failed"

    if (open = total) {
        verdict := "NOT BLOCKED"
        clr := ClrGreen
        info := "All " total " connection attempts went through"
    } else if (open = 0 && blocked > 0) {
        verdict := "BLOCKED"
        clr := ClrRed
        info := "0 of " total " went through: " parts
    } else if (open = 0) {
        verdict := "NO CONNECTION"
        clr := "cGray"
        info := "0 of " total " went through, none was denied outright (" parts ") - silent drop or no network"
    } else {
        verdict := "PARTIAL: " open " of " total " open"
        clr := "cD08000"
        info := open " of " total " went through: " parts
    }
    status.SetFont(clr)
    status.Text := verdict
    detail.Text := info
    btnRun.Enabled := true
    ruleVal.SetFont(ClrText)
    ruleVal.Text := "checking..."
    SetTimer(CheckRule, -50)
}

TargetText(t) {
    if !t.HasProp("port")
        return t.target
    return InStr(t.target, ":") ? "[" t.target "]:" t.port : t.target ":" t.port
}

CopyResults() {
    s := "Outbound firewall tester (github.com/wincmd64)`n`nTested: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n`n"
    Loop lv.GetCount() {
        row := A_Index
        line := ""
        Loop 7
            line .= (A_Index > 1 ? " | " : "") lv.GetText(row, A_Index)
        s .= line "`n"
    }
    A_Clipboard := s
}

; Looks for firewall rules whose program path equals this exe (read-only query)
CheckRule() {
    found := ""
    try {
        policy := ComObject("HNetCfg.FwPolicy2")
        for rule in policy.Rules {
            if (rule.ApplicationName = A_ScriptFullPath) {
                dir := (rule.Direction = 2) ? "Outbound" : "Inbound"
                act := (rule.Action = 0) ? "Block" : "Allow"
                en := rule.Enabled ? "enabled" : "disabled"
                found .= (found ? "; " : "") dir " / " act " / " en
            }
        }
    } catch {
        ruleVal.SetFont("cGray")
        ruleVal.Text := "check failed"
        return
    }
    if found {
        ruleVal.SetFont(ClrRed)
        ruleVal.Text := found
    } else {
        ruleVal.SetFont(ClrGreen)
        ruleVal.Text := "not found"
    }
}

; ---------------- Test dispatcher ----------------
RunTest(t) {
    t0 := A_TickCount
    switch t.type {
        case "dns":
            r := DnsTest(t.target)
        case "tcp":
            r := TcpTest(t.target, t.port)
        case "udpdns":
            r := UdpDnsTest(t.target, t.port)
        case "icmp":
            r := IcmpTest(t.target)
        case "http":
            r := HttpTest(t.target)
        default:
            r := {st: "ERROR", detail: "Unknown test type"}
    }
    r.ms := A_TickCount - t0
    return r
}

; ---------------- Winsock helpers ----------------
ClassifyWsa(err) {
    switch err {
        case 10013:
            return {st: "BLOCKED", detail: "WSAEACCES (10013): denied locally, typical for a firewall block"}
        case 10060:
            return {st: "TIMEOUT", detail: "WSAETIMEDOUT (10060)"}
        case 10061:
            return {st: "REFUSED", detail: "WSAECONNREFUSED (10061): host reached, port closed"}
        case 10051, 10065, 10047, 10049:
            return {st: "NO ROUTE", detail: "Winsock " err ": no route / address family unavailable"}
        case 10054:
            return {st: "REFUSED", detail: "WSAECONNRESET (10054): ICMP port unreachable from host"}
        default:
            return {st: "ERROR", detail: "Winsock error " err}
    }
}

WsaErr() {
    return DllCall("ws2_32\WSAGetLastError", "Int")
}

; Builds sockaddr_in / sockaddr_in6 from a literal IP and a port
MakeAddr(ip, port) {
    if InStr(ip, ":") {
        sa := Buffer(28, 0)
        NumPut("UShort", 23, sa, 0)
        NumPut("UChar", port >> 8, sa, 2)
        NumPut("UChar", port & 0xFF, sa, 3)
        ok := DllCall("ws2_32\inet_pton", "Int", 23, "AStr", ip, "Ptr", sa.Ptr + 8, "Int")
    } else {
        sa := Buffer(16, 0)
        NumPut("UShort", 2, sa, 0)
        NumPut("UChar", port >> 8, sa, 2)
        NumPut("UChar", port & 0xFF, sa, 3)
        ok := DllCall("ws2_32\inet_pton", "Int", 2, "AStr", ip, "Ptr", sa.Ptr + 4, "Int")
    }
    return (ok = 1) ? sa : ""
}

; fd_set with a single socket (layout depends on pointer size)
FdSet(s) {
    fd := Buffer(A_PtrSize + 64 * A_PtrSize, 0)
    NumPut("UInt", 1, fd, 0)
    NumPut("Ptr", s, fd, A_PtrSize)
    return fd
}

MakeTimeval(ms) {
    tv := Buffer(8, 0)
    NumPut("Int", ms // 1000, tv, 0)
    NumPut("Int", Mod(ms, 1000) * 1000, tv, 4)
    return tv
}

; Returns 0 = timeout, 1 = writable (connected), 2 = failed (except set)
WaitConnect(s, ms) {
    wr := FdSet(s)
    ex := FdSet(s)
    tv := MakeTimeval(ms)
    n := DllCall("ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", wr, "Ptr", ex, "Ptr", tv, "Int")
    if n <= 0
        return 0
    if NumGet(ex, 0, "UInt") > 0
        return 2
    return 1
}

SockError(s) {
    v := Buffer(4, 0)
    len := Buffer(4, 0)
    NumPut("Int", 4, len)
    DllCall("ws2_32\getsockopt", "Ptr", s, "Int", 0xFFFF, "Int", 0x1007, "Ptr", v, "Ptr", len)
    return NumGet(v, 0, "Int")
}

; ---------------- TCP: raw non-blocking connect by IP (no DNS involved) ----------------
TcpTest(ip, port, timeoutMs := 2000) {
    sa := MakeAddr(ip, port)
    if !sa
        return {st: "ERROR", detail: "Bad address"}
    af := InStr(ip, ":") ? 23 : 2
    s := DllCall("ws2_32\socket", "Int", af, "Int", 1, "Int", 6, "Ptr")
    if s = -1
        return ClassifyWsa(WsaErr())
    mode := Buffer(4, 0)
    NumPut("UInt", 1, mode)
    DllCall("ws2_32\ioctlsocket", "Ptr", s, "UInt", 0x8004667E, "Ptr", mode)
    r := DllCall("ws2_32\connect", "Ptr", s, "Ptr", sa, "Int", sa.Size, "Int")
    if r = 0 {
        DllCall("ws2_32\closesocket", "Ptr", s)
        return {st: "OK", detail: "connected"}
    }
    err := WsaErr()
    if err != 10035 {
        DllCall("ws2_32\closesocket", "Ptr", s)
        return ClassifyWsa(err)
    }
    w := WaitConnect(s, timeoutMs)
    err := (w = 0) ? 0 : SockError(s)
    DllCall("ws2_32\closesocket", "Ptr", s)
    if w = 0
        return {st: "TIMEOUT", detail: "no answer in " timeoutMs " ms (silent drop or unreachable)"}
    if err = 0
        return {st: "OK", detail: "connected"}
    return ClassifyWsa(err)
}

; ---------------- UDP: real DNS query, success = a reply arrived ----------------
BuildDnsQuery(host, id) {
    q := Buffer(12 + StrLen(host) + 2 + 4, 0)
    NumPut("UChar", id >> 8, q, 0)
    NumPut("UChar", id & 0xFF, q, 1)
    NumPut("UChar", 1, q, 2)       ; flags: recursion desired
    NumPut("UChar", 1, q, 5)       ; QDCOUNT = 1
    pos := 12
    for label in StrSplit(host, ".") {
        NumPut("UChar", StrLen(label), q, pos)
        pos++
        Loop StrLen(label) {
            NumPut("UChar", Ord(SubStr(label, A_Index, 1)), q, pos)
            pos++
        }
    }
    pos++                          ; root label (already zero)
    NumPut("UChar", 1, q, pos + 1) ; QTYPE = A
    NumPut("UChar", 1, q, pos + 3) ; QCLASS = IN
    return q
}

UdpDnsTest(ip, port, timeoutMs := 2000) {
    sa := MakeAddr(ip, port)
    if !sa
        return {st: "ERROR", detail: "Bad address"}
    af := InStr(ip, ":") ? 23 : 2
    s := DllCall("ws2_32\socket", "Int", af, "Int", 2, "Int", 17, "Ptr")
    if s = -1
        return ClassifyWsa(WsaErr())
    q := BuildDnsQuery("google.com", 0x4657)
    sent := DllCall("ws2_32\sendto", "Ptr", s, "Ptr", q, "Int", q.Size, "Int", 0, "Ptr", sa, "Int", sa.Size, "Int")
    if sent = -1 {
        err := WsaErr()
        DllCall("ws2_32\closesocket", "Ptr", s)
        return ClassifyWsa(err)
    }
    rd := FdSet(s)
    tv := MakeTimeval(timeoutMs)
    n := DllCall("ws2_32\select", "Int", 0, "Ptr", rd, "Ptr", 0, "Ptr", 0, "Ptr", tv, "Int")
    if n <= 0 {
        DllCall("ws2_32\closesocket", "Ptr", s)
        return {st: "TIMEOUT", detail: "no UDP reply in " timeoutMs " ms (dropped or filtered)"}
    }
    buf := Buffer(512, 0)
    got := DllCall("ws2_32\recvfrom", "Ptr", s, "Ptr", buf, "Int", 512, "Int", 0, "Ptr", 0, "Ptr", 0, "Int")
    err := (got = -1) ? WsaErr() : 0
    DllCall("ws2_32\closesocket", "Ptr", s)
    if got = -1
        return ClassifyWsa(err)
    if (NumGet(buf, 0, "UChar") != 0x46 || NumGet(buf, 1, "UChar") != 0x57)
        return {st: "ERROR", detail: "reply with wrong transaction ID"}
    answers := (NumGet(buf, 6, "UChar") << 8) | NumGet(buf, 7, "UChar")
    return {st: "OK", detail: "DNS reply, " got " bytes, answers: " answers}
}

; ---------------- ICMP echo ----------------
IcmpTest(ip, timeoutMs := 2000) {
    h := DllCall("iphlpapi\IcmpCreateFile", "Ptr")
    if (h = 0 || h = -1)
        return {st: "ERROR", detail: "IcmpCreateFile failed"}
    addr := Buffer(4, 0)
    DllCall("ws2_32\inet_pton", "Int", 2, "AStr", ip, "Ptr", addr)
    data := Buffer(32, 0x61)
    reply := Buffer(256, 0)
    n := DllCall("iphlpapi\IcmpSendEcho", "Ptr", h, "UInt", NumGet(addr, 0, "UInt"), "Ptr", data, "UShort", 32
        , "Ptr", 0, "Ptr", reply, "UInt", reply.Size, "UInt", timeoutMs, "UInt")
    err := A_LastError
    DllCall("iphlpapi\IcmpCloseHandle", "Ptr", h)
    if n > 0 {
        status := NumGet(reply, 4, "UInt")
        if status = 0
            return {st: "OK", detail: "echo reply, rtt " NumGet(reply, 8, "UInt") " ms"}
        return {st: "ERROR", detail: "ICMP status " status}
    }
    if err = 11010
        return {st: "TIMEOUT", detail: "IP_REQ_TIMED_OUT (11010)"}
    if (err = 11002 || err = 11003)
        return {st: "NO ROUTE", detail: "ICMP error " err ": network/host unreachable"}
    return {st: "ERROR", detail: "IcmpSendEcho error " err}
}

; ---------------- System resolver (getaddrinfo, resolved via DnsCache service) ----------------
DnsTest(host) {
    res := 0
    rc := DllCall("ws2_32\GetAddrInfoW", "WStr", host, "Ptr", 0, "Ptr", 0, "PtrP", &res, "Int")
    if rc != 0
        return {st: "ERROR", detail: "name not resolved (getaddrinfo " rc ")"}
    ips := ""
    cnt := 0
    p := res
    while (p && cnt < 3) {
        fam := NumGet(p, 4, "Int")
        sa := NumGet(p, 16 + 2 * A_PtrSize, "Ptr")
        off := (fam = 2) ? 4 : (fam = 23 ? 8 : 0)
        if off {
            nb := Buffer(92, 0)
            DllCall("ws2_32\InetNtopW", "Int", fam, "Ptr", sa + off, "Ptr", nb, "UPtr", 46)
            ips .= (ips ? ", " : "") StrGet(nb, "UTF-16")
            cnt++
        }
        p := NumGet(p, 16 + 3 * A_PtrSize, "Ptr")
    }
    DllCall("ws2_32\FreeAddrInfoW", "Ptr", res)
    return {st: "OK", detail: "resolved: " ips}
}

; ---------------- WinHTTP (what a typical app uses) ----------------
HttpTest(url) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(2000, 2000, 2000, 2000)
        req.Open("HEAD", url, false)
        req.Send()
        code := req.Status
    } catch Error as e {
        n := 0
        try n := e.Number & 0xFFFFFFFF
        w := ((n >> 16) = 0x8007) ? (n & 0xFFFF) : 0
        msg := Trim(RegExReplace(e.Message, "\s+", " "))
        return {st: (w = 12002 ? "TIMEOUT" : "ERROR"), detail: (w ? "WinHTTP " w ": " : "") msg}
    }
    return {st: "OK", detail: "HTTP " code}
}
