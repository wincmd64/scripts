/*
  Weather window powered by wttr.in
    Middle-click on the script's tray icon - shows / hides the window
*/

#Requires AutoHotkey v2.0

; ---------------- SETTINGS ----------------
WeatherCity  := ""        ; "" = detect by IP, or a place name ("Kyiv", "London"...)
WeatherLang  := ""        ; language of descriptions and labels: "" = the Windows language (ru, uk or en; any other falls back to en)
WeatherTheme := "system"  ; "system", "dark", or "light"
WeatherEdgeCm := 1        ; distance from the screen edges (work area), in cm; calculated from the screen DPI
WeatherAutoClose := 1     ; close the window when it loses focus
WeatherCacheMin := 10     ; reuse downloaded data for this many minutes before asking wttr.in again
WeatherRefreshKey := "F5" ; key that refreshes the data while the window is active
; -------------------------------------------

; ---------- state of the window ----------
class WxState {
    static gui := ""          ; the open window, or "" when closed
    static timer := ""        ; focus watcher callback
    static shownTick := 0     ; when the window was shown
    static closedTick := 0    ; when the window was last closed by the focus watcher
    static cache := ""        ; last downloaded data
    static sel := 1           ; selected day (1 = today), kept until the script restarts
    static pos := ""          ; window position at the last close, kept until the script restarts
}

; ---------- HTTP (UTF-8) ----------
WxHttp(url) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(3000, 3000, 5000, 8000)            ; resolve, connect, send, receive - ms
    req.Open("GET", url, false)
    req.SetRequestHeader("User-Agent", "curl/8.0")
    req.Send()
    if req.Status != 200
        throw Error("HTTP " req.Status)
    ; decode the body as UTF-8 manually so Cyrillic and symbols are not garbled
    stm := ComObject("ADODB.Stream")
    stm.Type := 1, stm.Open(), stm.Write(req.ResponseBody)
    stm.Position := 0, stm.Type := 2, stm.Charset := "utf-8"
    return stm.ReadText()
}

; ---------- minimal JSON parser: objects -> Map, arrays -> Array ----------
class WxJson {
    static Parse(s) => WxJson(s).Value()

    __New(s) {
        this.s := s
        this.p := 1
    }

    Ws() {
        while this.p <= StrLen(this.s) && InStr(" `t`r`n", SubStr(this.s, this.p, 1))
            this.p++
    }

    Value() {
        this.Ws()
        c := SubStr(this.s, this.p, 1)
        if c = "{" {
            this.p++
            m := Map()
            this.Ws()
            if SubStr(this.s, this.p, 1) = "}" {
                this.p++
                return m
            }
            loop {
                this.Ws()
                k := this.Str()
                this.Ws()
                this.p++                       ; skip the colon
                m[k] := this.Value()
                this.Ws()
                if SubStr(this.s, this.p++, 1) = "}"
                    return m
            }
        }
        if c = "[" {
            this.p++
            a := []
            this.Ws()
            if SubStr(this.s, this.p, 1) = "]" {
                this.p++
                return a
            }
            loop {
                a.Push(this.Value())
                this.Ws()
                if SubStr(this.s, this.p++, 1) = "]"
                    return a
            }
        }
        if c = '"'
            return this.Str()
        ; number or literal (true / false / null)
        if RegExMatch(this.s, "\G[^,\]\}\s]+", &mt, this.p) {
            this.p += mt.Len
            return mt[0]
        }
        throw Error("JSON: parse error at position " this.p)
    }

    Str() {
        this.p++                               ; skip the opening quote
        out := ""
        loop {
            c := SubStr(this.s, this.p++, 1)
            if c = '"'
                return out
            if c = ""
                throw Error("JSON: unterminated string")
            if c != "\" {
                out .= c
                continue
            }
            n := SubStr(this.s, this.p++, 1)
            switch n {
                case "n": out .= "`n"
                case "t": out .= "`t"
                case "r": out .= "`r"
                case "u": out .= Chr("0x" SubStr(this.s, this.p, 4)), this.p += 4
                default:  out .= n
            }
        }
    }
}

; ---------- hand cursor over clickable text controls ----------
class WxHandCursor {
    static hwnds := Map()
    static registered := false

    ; show the hand cursor over the given control (like over a link)
    static Add(ctrl) {
        if !this.registered {
            this.registered := true
            OnMessage(0x20, (wParam, lParam, msg, hwnd) => WxHandCursor.OnSetCursor(wParam))   ; WM_SETCURSOR
        }
        this.hwnds[ctrl.Hwnd] := true
    }

    static OnSetCursor(wParam) {
        if this.hwnds.Has(wParam) {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"))   ; IDC_HAND
            return 1
        }
    }
}

; ---------- hover tooltips for text controls ----------
class WxTip {
    static tips := Map()       ; control hwnd -> tooltip text
    static registered := false
    static prev := 0           ; control under the mouse at the last mouse move
    static text := ""
    static showFn := ""
    static hideFn := ""

    ; show "text" when the mouse rests over the control (it needs the SS_NOTIFY style, 0x100)
    static Add(ctrl, text) {
        if !this.registered {
            this.registered := true
            this.showFn := ObjBindMethod(this, "Show")
            this.hideFn := ObjBindMethod(this, "Hide")
            OnMessage(0x200, (wParam, lParam, msg, hwnd) => WxTip.OnMouseMove(hwnd))   ; WM_MOUSEMOVE
        }
        this.tips[ctrl.Hwnd] := text
    }

    static OnMouseMove(hwnd) {
        if (hwnd = this.prev)
            return
        this.prev := hwnd
        this.Hide()
        if this.tips.Has(hwnd) {
            this.text := this.tips[hwnd]
            SetTimer(this.showFn, -500)                 ; short delay, like a regular tooltip
        }
    }

    static Show() {
        ToolTip(this.text, , , 17)                      ; tooltip slot 17: unlikely to clash with other scripts
        SetTimer(this.hideFn, -6000)
    }

    static Hide() {
        SetTimer(this.showFn, 0)
        SetTimer(this.hideFn, 0)
        ToolTip(, , , 17)
    }

    ; forget all tooltips (the window is being closed)
    static Reset() {
        if this.registered
            this.Hide()
        this.tips.Clear()
        this.prev := 0
    }
}

; ---------- language ----------
; WeatherLang when it is set, otherwise the Windows language:
; Russian -> ru, Ukrainian -> uk, anything else -> en
WxLang() {
    if (WeatherLang != "")
        return StrLower(WeatherLang)
    primary := Integer("0x" A_Language) & 0x3FF         ; primary language id of the Windows language
    if (primary = 0x19)
        return "ru"
    if (primary = 0x22)
        return "uk"
    return "en"
}

; ---------- theme ----------
; "light"/"dark" pass through as-is, "system" reads the current Windows apps theme from the registry
WxTheme() {
    t := StrLower(WeatherTheme)
    if (t = "dark" || t = "light")
        return t
    try {
        lightMode := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
        return (lightMode = 0) ? "dark" : "light"
    } catch {
        return "light"                                 ; fall back if the registry value doesn't exist
    }
}

; colors of the window; background and text match qTranslate.ahk
WxPalette() {
    if (WxTheme() = "dark")
        return {dark: true, bg: "000000", text: "FFFFFF", dim: "A0A0A0", line: "3A3A3A", accent: "4DB2FF", link: "4DB2FF", windMid: "F2DC8C", windHigh: "F2A0A0"}
    return {dark: false, bg: "F5F5F5", text: "000000", dim: "606060", line: "C8C8C8", accent: "0078D4", link: "0066CC", windMid: "A87400", windHigh: "C24A4A"}
}

; dark / light title bar (DWMWA_USE_IMMERSIVE_DARK_MODE)
WxDarkTitleBar(hwnd, on) {
    v := Buffer(4, 0)
    NumPut("Int", on ? 1 : 0, v)
    ; attribute 20 on current Windows 10/11, 19 on early Windows 10 builds
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 20, "Ptr", v, "Int", 4) != 0
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 19, "Ptr", v, "Int", 4)
}

; ---------- fonts ----------
; Font options are cumulative: a bold weight set once would stick to every control
; created afterwards. So every call starts from "norm" and states everything it needs.
WxFont(g, opts, name := "Segoe UI") => g.SetFont("norm " opts, name)

; ---------- wttr.in weather code -> [glyph, color] ----------
WxIcon(code) {
    c := " " code " "
    if InStr(" 113 ", c)
        return ["☀", "F5A000"]
    if InStr(" 116 ", c)
        return ["⛅", "E0A030"]
    if InStr(" 119 122 ", c)
        return ["☁", "8A96A3"]
    if InStr(" 143 248 260 ", c)
        return [Chr(0x1F32B), "9AA5B1"]                 ; fog
    if InStr(" 200 386 389 392 395 ", c)
        return ["⛈", "6F82AA"]                          ; thunderstorm
    if InStr(" 179 227 230 323 326 329 332 335 338 368 371 ", c)
        return ["❄", "4DA3E0"]                          ; snow
    if InStr(" 182 185 281 284 311 314 317 320 350 362 365 374 377 ", c)
        return [Chr(0x1F328), "4D8FCC"]                 ; sleet
    return [Chr(0x1F327), "2F7FD0"]                     ; rain
}

; ---------- UI labels per language (unknown language -> English) ----------
; "wd" = weekday names, Sunday first
WxLabels(lang) {
    static t := Map(
        "ru", Map("feels", "ощущается", "hum", "Влажность", "wind", "Ветер", "ms", "м/с", "rain", "Осадки", "mm", "мм"
            , "morning", "Утро", "day", "День", "evening", "Вечер", "night", "Ночь"
            , "tipFeels", "Ощущается как", "tipWind", "Ветер", "tipGust", "порывы до"
            , "tipChance", "Вероятность осадков", "tipAmount", "Количество осадков"
            , "tipMin", "Минимум за сутки", "tipMax", "Максимум за сутки"
            , "tipSlot", "Данные на"
            , "tipCoords", "Искать координаты в поиске Google"
            , "tipPress", "Давление", "tipUV", "УФ-индекс", "tipVis", "Видимость", "hpa", "гПа", "mmhg", "мм рт. ст.", "km", "км"
            , "moon", "Луна", "moonNames", "Новолуние|Растущий серп|Первая четверть|Растущая луна|Полнолуние|Убывающая луна|Последняя четверть|Убывающий серп"
            , "wd", "Вс|Пн|Вт|Ср|Чт|Пт|Сб"),
        "uk", Map("feels", "відчувається", "hum", "Вологість", "wind", "Вітер", "ms", "м/с", "rain", "Опади", "mm", "мм"
            , "morning", "Ранок", "day", "День", "evening", "Вечір", "night", "Ніч"
            , "tipFeels", "Відчувається як", "tipWind", "Вітер", "tipGust", "пориви до"
            , "tipChance", "Імовірність опадів", "tipAmount", "Кількість опадів"
            , "tipMin", "Мінімум за добу", "tipMax", "Максимум за добу"
            , "tipSlot", "Дані на"
            , "tipCoords", "Шукати координати в пошуку Google"
            , "tipPress", "Тиск", "tipUV", "УФ-індекс", "tipVis", "Видимість", "hpa", "гПа", "mmhg", "мм рт. ст.", "km", "км"
            , "moon", "Місяць", "moonNames", "Новий місяць|Зростаючий серп|Перша чверть|Зростаючий місяць|Повня|Спадаючий місяць|Остання чверть|Спадаючий серп"
            , "wd", "Нд|Пн|Вт|Ср|Чт|Пт|Сб"),
        "en", Map("feels", "feels like", "hum", "Humidity", "wind", "Wind", "ms", "m/s", "rain", "Precipitation", "mm", "mm"
            , "morning", "Morning", "day", "Day", "evening", "Evening", "night", "Night"
            , "tipFeels", "Feels like", "tipWind", "Wind", "tipGust", "gusts up to"
            , "tipChance", "Chance of precipitation", "tipAmount", "Precipitation amount"
            , "tipMin", "Daily minimum", "tipMax", "Daily maximum"
            , "tipSlot", "Data for"
            , "tipCoords", "Search the coordinates on Google"
            , "tipPress", "Pressure", "tipUV", "UV index", "tipVis", "Visibility", "hpa", "hPa", "mmhg", "mmHg", "km", "km"
            , "moon", "Moon", "moonNames", "New moon|Waxing crescent|First quarter|Waxing gibbous|Full moon|Waning gibbous|Last quarter|Waning crescent"
            , "wd", "Sun|Mon|Tue|Wed|Thu|Fri|Sat")
    )
    return t.Has(lang) ? t[lang] : t["en"]
}

; ---------- own weather descriptions by code ----------
; wttr.in leaves some descriptions untranslated (e.g. "Patchy rain nearby"),
; this table is used only for those cases. Format: "code=text|code=text|..."
WxDescTable(lang) {
    static cache := Map()
    static src := Map(
        "ru", "113=Ясно|116=Переменная облачность|119=Облачно|122=Пасмурно|143=Дымка"
            . "|176=Местами дождь|179=Местами снег|182=Местами дождь со снегом|185=Местами ледяная морось|200=Местами грозы"
            . "|227=Низовая метель|230=Метель|248=Туман|260=Ледяной туман|263=Местами лёгкая морось|266=Лёгкая морось"
            . "|281=Ледяная морось|284=Сильная ледяная морось|293=Местами небольшой дождь|296=Небольшой дождь"
            . "|299=Временами умеренный дождь|302=Умеренный дождь|305=Временами сильный дождь|308=Сильный дождь"
            . "|311=Слабый ледяной дождь|314=Ледяной дождь|317=Слабый дождь со снегом|320=Дождь со снегом"
            . "|323=Местами небольшой снег|326=Небольшой снег|329=Местами умеренный снег|332=Умеренный снег"
            . "|335=Местами сильный снег|338=Сильный снег|350=Ледяная крупа|353=Небольшой ливень|356=Ливень|359=Сильный ливень"
            . "|362=Небольшой дождь со снегом|365=Дождь со снегом|368=Небольшой снегопад|371=Снегопад"
            . "|374=Небольшая ледяная крупа|377=Ледяная крупа|386=Небольшой дождь с грозой|389=Дождь с грозой"
            . "|392=Небольшой снег с грозой|395=Снег с грозой",
        "uk", "113=Ясно|116=Мінлива хмарність|119=Хмарно|122=Похмуро|143=Серпанок"
            . "|176=Місцями дощ|179=Місцями сніг|182=Місцями дощ зі снігом|185=Місцями крижана мряка|200=Місцями грози"
            . "|227=Низова завірюха|230=Завірюха|248=Туман|260=Крижаний туман|263=Місцями легка мряка|266=Легка мряка"
            . "|281=Крижана мряка|284=Сильна крижана мряка|293=Місцями невеликий дощ|296=Невеликий дощ"
            . "|299=Часом помірний дощ|302=Помірний дощ|305=Часом сильний дощ|308=Сильний дощ"
            . "|311=Слабкий крижаний дощ|314=Крижаний дощ|317=Слабкий дощ зі снігом|320=Дощ зі снігом"
            . "|323=Місцями невеликий сніг|326=Невеликий сніг|329=Місцями помірний сніг|332=Помірний сніг"
            . "|335=Місцями сильний сніг|338=Сильний сніг|350=Крижана крупа|353=Невелика злива|356=Злива|359=Сильна злива"
            . "|362=Невеликий дощ зі снігом|365=Дощ зі снігом|368=Невеликий снігопад|371=Снігопад"
            . "|374=Невелика крижана крупа|377=Крижана крупа|386=Невеликий дощ із грозою|389=Дощ із грозою"
            . "|392=Невеликий сніг із грозою|395=Сніг із грозою"
    )
    if !cache.Has(lang) {
        m := Map()
        if src.Has(lang)
            for pair in StrSplit(src[lang], "|") {
                kv := StrSplit(pair, "=", , 2)
                m[kv[1]] := kv[2]
            }
        cache[lang] := m
    }
    return cache[lang]
}

; description in the requested language: wttr.in's own translation when it exists,
; otherwise our table by weather code, otherwise the English text
WxDesc(o, lang) {
    en  := o["weatherDesc"][1]["value"]
    key := "lang_" lang
    txt := o.Has(key) ? o[key][1]["value"] : en
    if lang != "en" && txt = en {                      ; not translated by wttr.in
        tbl := WxDescTable(lang)
        if tbl.Has(o["weatherCode"])
            return tbl[o["weatherCode"]]
    }
    return txt
}

WxWindArrow(deg) {
    static a := ["↓", "↙", "←", "↖", "↑", "↗", "→", "↘"]
    return a[Mod(Round(Integer(deg) / 45), 8) + 1]
}

WxTemp(n) => Format("{:+d}°", Integer(n))

; GetPos / Move work in real pixels, control options are DPI-scaled: convert real -> option units
WxUnscale(n) => Round(n * 96 / A_ScreenDPI)

WxAddIcon(g, opts, code, size) {
    ic := WxIcon(code)
    WxFont(g, "s" size " c" ic[2], "Segoe UI Symbol")
    return g.AddText(opts " Center", ic[1])
}

; hourly entry whose "time" field equals the given value ("900", "1200", ...)
WxFindSlot(hourly, time) {
    for x in hourly
        if x["time"] = time
            return x
    return hourly[1]
}

; coordinates of the place wttr.in resolved for the request: the same
; "Location: ... [lat,lon]" footer the site shows under the 3-day forecast.
; Falls back to the less precise coordinates of the nearest weather area from j1.
WxGetCoords(base, j) {
    try {
        txt := WxHttp(base "?T&lang=en")
        if RegExMatch(txt, "\[\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\]", &m)
            return m[1] "," m[2]
    }
    a := j["nearest_area"][1]
    return a["latitude"] "," a["longitude"]
}

; is the title bar area at (x, y) still on one of the monitors?
WxOnScreen(x, y) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (x + 60 >= L && x + 60 < R && y + 10 >= T && y + 10 < B)
            return true
    }
    return false
}

; work area of the monitor that contains the point (the cursor sits on the taskbar,
; which is outside the work area, so the monitor is found by its full bounds)
WxWorkArea(px, py) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (px >= ml && px < mr && py >= mt && py < mb) {
            MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
            return {L: L, T: T, R: R, B: B}
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &L, &T, &R, &B)
    return {L: L, T: T, R: R, B: B}
}

; ---------- data (cached) ----------
; downloads wttr.in data, or reuses the previous download while it is fresh;
; on a network error the old data is used if there is any.
; force = skip the freshness check and report errors (manual refresh)
WxLoad(force := false) {
    c := WxState.cache
    if !force && IsObject(c) && (A_TickCount - c.tick < WeatherCacheMin * 60000)
        return c
    try {
        base   := "https://wttr.in/" WeatherCity
        j      := WxJson.Parse(WxHttp(base "?format=j1&lang=" WxLang()))
        ; one short request: the location string, same as wttr.in's %l (district, region, country;
        ; j1's nearest_area is the nearest weather station and can differ from it),
        ; and %T - the current time at that place
        info   := StrSplit(Trim(WxHttp(base "?format=%l|%T&lang=" WxLang())), "|")
        title  := Trim(info[1])
        offset := WxClockOffset(info.Length > 1 ? info[2] : "")
        coords := WxGetCoords(base, j)
        WxState.cache := {tick: A_TickCount, stamp: A_Now, offset: offset, j: j, title: title, coords: coords}
        return WxState.cache
    } catch as e {
        if IsObject(c) && !force
            return c
        throw e
    }
}

; ---------- day switcher: clickable labels, underline bars and one control group per day ----------
class WxDayTabs {
    __New(accent, dim) {
        this.labels := []
        this.bars := []
        this.groups := []
        this.accent := accent
        this.dim := dim
    }

    Select(i, *) {
        for k, grp in this.groups
            for c in grp
                c.Visible := (k = i)
        for k, b in this.bars
            b.Visible := (k = i)
        for k, l in this.labels {
            l.SetFont(k = i ? "norm s10 w600 c" this.accent : "norm s10 w400 c" this.dim, "Segoe UI")
            l.Redraw()
        }
        WxState.sel := i
    }
}

; ---------- one day: min/max line + 4 columns (morning / day / evening / night) ----------
; returns the array of created controls so the switcher can show/hide them
WxAddDay(g, p, x0, y0, d, t, lang, loc) {
    ; which hourly slots represent which part of the day (wttr.in "time" values) - tweak here
    static slots := [["morning", "900"], ["day", "1200"], ["evening", "1800"], ["night", "2100"]]
    colW := 104
    x0 += (430 - colW * 4) // 2                        ; center the four columns
    ctrls := []
    astro := WxAstro(d)

    WxFont(g, "s9 w600 c" p.dim)
    ; no width: the control is only as wide as its text, so the tooltip shows only over the text
    rangeCtl := g.AddText("x" x0 " y" y0 " h18 0x100", WxTemp(d["mintempC"]) " … " WxTemp(d["maxtempC"]))
    WxTip.Add(rangeCtl, WxRangeTip(d, t))
    ctrls.Push(rangeCtl)

    y := y0 + 24
    for k, s in slots {
        x := x0 + (k - 1) * colW
        h := WxFindSlot(d["hourly"], s[2])
        chance := Max(Integer(h["chanceofrain"]), Integer(h["chanceofsnow"]))
        speed := WxMs(h["windspeedKmph"])               ; wind in m/s, like on most weather sites
        gust  := h.Has("WindGustKmph") ? WxMs(h["WindGustKmph"]) : speed
        windRange := speed                              ; "speed-gust" like on the wttr.in site
        if (gust > speed)
            windRange .= "–" gust
        windFg := WxWindColor(Max(speed, gust), p)      ; text color by the wind strength

        ; a slot counts as past once its 3-hour period is over (by the time at the location):
        ; past labels are dimmed, the rest use the text color
        past := (StrCompare(d["date"], loc.date) < 0) || (d["date"] = loc.date && Integer(s[2]) + 300 <= loc.hm)
        labelColor := past ? p.dim : p.text

        yIcon := y + 18, yDesc := y + 58, yTemp := y + 92
        yFeels := y + 118, yWind := y + 138, yRain := y + 158

        ; part of the day, icon, description right under the icon (2 lines reserved), temperature
        WxFont(g, "s9 w600 c" labelColor)
        slotCtl := g.AddText("x" x " y" y " w" colW " h18 Center 0x100", t[s[1]])
        WxTip.Add(slotCtl, t["tipSlot"] " " WxHm(s[2]))
        ctrls.Push(slotCtl)

        ; the icon has a tooltip with extra data (0x100 = SS_NOTIFY, needed to get mouse messages)
        icon := WxAddIcon(g, "x" x " y" yIcon " w" colW " h40 0x200 0x100", h["weatherCode"], 22)
        WxTip.Add(icon, WxExtraTip(h, t, astro))
        ctrls.Push(icon)

        WxFont(g, "s9 w400 c" p.dim)
        ctrls.Push(g.AddText("x" x " y" yDesc " w" colW " h32 Center", WxDesc(h, lang)))

        WxFont(g, "s13 w600 c" p.text)
        ctrls.Push(g.AddText("x" x " y" yTemp " w" colW " h26 Center", WxTemp(h["tempC"])))

        ; feels like, wind, precipitation (regular weight), each with a tooltip on hover
        WxFont(g, "s9 w400 c" p.dim)
        feels := g.AddText("x" x " y" yFeels " w" colW " h18 Center 0x100", "(" WxTemp(h["FeelsLikeC"]) ")")
        WxTip.Add(feels, t["tipFeels"] " " WxTemp(h["FeelsLikeC"]))
        ctrls.Push(feels)

        WxFont(g, "s9 w400 c" windFg)
        wind := g.AddText("x" x " y" yWind " w" colW " h18 Center 0x100"
            , WxWindArrow(h["winddirDegree"]) " " windRange " " t["ms"])
        windTip := t["tipWind"] " " speed " " t["ms"]
        if (gust > speed)
            windTip .= ", " t["tipGust"] " " gust " " t["ms"]
        WxTip.Add(wind, windTip)
        ctrls.Push(wind)

        WxFont(g, "s9 w400 c" p.text)
        rain := g.AddText("x" x " y" yRain " w" colW " h18 Center 0x100"
            , "☂ " chance "% · " h["precipMM"] " " t["mm"])
        WxTip.Add(rain, t["tipChance"] ": " chance "%`n" t["tipAmount"] ": " h["precipMM"] " " t["mm"])
        ctrls.Push(rain)
    }
    return ctrls
}

; wttr.in slot time ("0", "300", "900", "1200"...) -> "00:00", "03:00", "09:00", "12:00"...
WxHm(time) {
    n := Integer(time)
    return Format("{:02d}:{:02d}", n // 100, Mod(n, 100))
}

; tooltip of the min/max line: the daily extremes come from all 8 slots of the day, so they can
; differ from the 4 columns; shows when they happen (from the 3-hourly data)
WxRangeTip(d, t) {
    minT := Integer(d["mintempC"]), maxT := Integer(d["maxtempC"])
    minAt := "", maxAt := ""
    for x in d["hourly"] {
        v := Integer(x["tempC"])
        if (minAt = "" && v = minT)
            minAt := " (" WxHm(x["time"]) ")"
        if (maxAt = "" && v = maxT)
            maxAt := " (" WxHm(x["time"]) ")"
    }
    return t["tipMin"] ": " WxTemp(minT) minAt "`n" t["tipMax"] ": " WxTemp(maxT) maxAt
}

; km/h -> m/s, rounded to a whole number
WxMs(kmh) => Round(Integer(kmh) / 3.6)

; text color of the wind by its strongest value in m/s: up to 9 normal, 10-14 pale yellow,
; 15 and more pale red (the usual wind gust scale; the colors come from the theme palette)
WxWindColor(ms, p) {
    if (ms >= 15)
        return p.windHigh
    if (ms >= 10)
        return p.windMid
    return p.text
}

; astronomy data of a day (moon phase, sunrise...); an empty Map when missing
WxAstro(d) => (d.Has("astronomy") && d["astronomy"].Length) ? d["astronomy"][1] : Map()

; "Moon: <glyph> <phase>, <illumination>%" from wttr.in's astronomy data, or "" when unknown
WxMoonLine(astro, t) {
    phase := astro.Has("moon_phase") ? astro["moon_phase"] : ""
    names := StrSplit(t["moonNames"], "|")
    ; same order as the moon glyphs U+1F311 ... U+1F318
    for i, en in ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"] {
        if (phase = en) {
            line := Chr(0x1F311 + i - 1) " " names[i]
            if astro.Has("moon_illumination")
                line .= ", " astro["moon_illumination"] "%"
            return t["moon"] ": " line
        }
    }
    return ""
}

; difference in minutes between the clock at the location and this PC's clock, measured from
; wttr.in's %T ("HH:MM:SS", the local time of the place); 0 (= trust the PC clock) when it can't be read
WxClockOffset(text) {
    if !RegExMatch(text, "^\s*(\d{1,2}):(\d\d)", &m)
        return 0
    diff := Integer(m[1]) * 60 + Integer(m[2]) - (Integer(FormatTime(A_Now, "HH")) * 60 + Integer(FormatTime(A_Now, "mm")))
    return Mod(Mod(diff + 720, 1440) + 1440, 1440) - 720      ; keep it within -12 ... +12 hours
}

; date and time at the location right now: this PC's clock shifted by the measured offset
WxLocalNow(data) {
    t := DateAdd(A_Now, data.offset, "Minutes")
    return {date: FormatTime(t, "yyyy-MM-dd"), hm: Integer(FormatTime(t, "HHmm"))}
}

; extra data for the icon tooltip (test): moon phase, pressure, UV index, visibility.
; Other fields in the hourly data: humidity, cloudcover, DewPointC, chanceofthunder, ...
WxExtraTip(h, t, astro) {
    pressure := h.Has("pressure") ? h["pressure"] : "?"
    press := pressure " " t["hpa"]                      ; as reported, if it is not a number
    if IsInteger(pressure)                              ; mm Hg first, hPa in parentheses
        press := Round(pressure * 0.750062) " " t["mmhg"] " (" pressure " " t["hpa"] ")"
    uv  := h.Has("uvIndex") ? h["uvIndex"] : "?"
    vis := h.Has("visibility") ? h["visibility"] : "?"
    moon := WxMoonLine(astro, t)
    out := (moon != "") ? moon "`n" : ""
    return out t["tipPress"] ": " press "`n" t["tipUV"] ": " uv "`n" t["tipVis"] ": " vis " " t["km"]
}

; ---------- window ----------
WxBuild(data, pos := "") {
    lang := WxLang()
    t    := WxLabels(lang)
    j    := data.j
    cc   := j["current_condition"][1]
    p    := WxPalette()
    loc  := WxLocalNow(data)                            ; date and time at the location

    ; +Owner = owned by the script's hidden main window: no taskbar button, no Alt+Tab entry
    ; title: location + the moment the data was downloaded
    g := Gui("+AlwaysOnTop -MinimizeBox +Owner" A_ScriptHwnd
        , data.title " (" FormatTime(data.stamp, "dd.MM.yyyy HH:mm") ")")
    g.BackColor := p.bg
    g.MarginX := 18, g.MarginY := 14
    WxDarkTitleBar(g.Hwnd, p.dark)
    g.OnEvent("Close", (*) => WxClose())
    g.OnEvent("Escape", (*) => WxClose())

    ; --- current conditions ---
    nowIcon := WxAddIcon(g, "xm y14 w70 h64 0x200 0x100", cc["weatherCode"], 36)
    WxTip.Add(nowIcon, WxExtraTip(cc, t, WxAstro(j["weather"][1])))
    WxFont(g, "s24 c" p.text)
    g.AddText("x96 y10 w220", WxTemp(cc["temp_C"]))
    WxFont(g, "s10 c" p.dim)
    g.AddText("x96 y+0 w340", WxDesc(cc, lang) ", " t["feels"] " " WxTemp(cc["FeelsLikeC"]))

    ; humidity / wind / precipitation in one row; separate controls, so that the wind
    ; can have its own text color
    windMs  := WxMs(cc["windspeedKmph"])
    windFg  := WxWindColor(windMs, p)
    windTxt := t["wind"] " " WxWindArrow(cc["winddirDegree"]) " " windMs " " t["ms"]
    WxFont(g, "s10 c" p.text)
    g.AddText("xm y+18", t["hum"] " " cc["humidity"] "%")
    WxFont(g, "s10 c" windFg)
    g.AddText("x+24 yp", windTxt)
    WxFont(g, "s10 c" p.text)
    g.AddText("x+24 yp", t["rain"] " " cc["precipMM"] " " t["mm"])
    g.AddText("xm y+12 w430 h1 Background" p.line)     ; separator line

    ; --- day switcher labels (today is selected by default) ---
    days := j["weather"]
    wd := StrSplit(t["wd"], "|")
    tabs := WxDayTabs(p.accent, p.dim)
    WxFont(g, "s10 w400 c" p.dim)
    for i, d in days {
        ; weekday name comes from our own table, so it follows the language setting
        date := StrReplace(d["date"], "-")
        name := wd[Integer(FormatTime(date, "WDay"))] " " FormatTime(date, "dd.MM")
        opts := (i = 1 ? "xm y+8" : "x+0 yp") " w100 h28 0x200 0x100 Center"
        lbl := g.AddText(opts, name)
        lbl.OnEvent("Click", tabs.Select.Bind(tabs, i))
        WxHandCursor.Add(lbl)
        tabs.labels.Push(lbl)
    }
    tabs.labels[1].GetPos(&hx, &hy, &hw, &hh)
    ux := WxUnscale(hx), uy := WxUnscale(hy), uw := WxUnscale(hw), uh := WxUnscale(hh)
    yLine := uy + uh
    yBar  := yLine - 2
    g.AddText("xm y" yLine " w430 h1 Background" p.line)   ; thin line under the labels
    loop days.Length {                                      ; one underline bar per label, only the selected one is visible
        bx := ux + (A_Index - 1) * uw
        tabs.bars.Push(g.AddText("x" bx " y" yBar " w" uw " h3 Background" p.accent, ""))
    }

    ; --- one control group per day, all placed at the same spot ---
    yContent := yLine + 12
    for d in days
        tabs.groups.Push(WxAddDay(g, p, g.MarginX, yContent, d, t, lang, loc))

    ; --- coordinates link in the top-right corner ---
    xLink := g.MarginX + 430 - 130
    WxFont(g, "s9 underline c" p.link)
    lnk := g.AddText("x" xLink " y10 w130 h18 Right 0x100", data.coords)
    url := "https://www.google.com/search?q=" StrReplace(data.coords, ",", "%2C")
    lnk.OnEvent("Click", (*) => Run(url))
    WxHandCursor.Add(lnk)
    WxTip.Add(lnk, t["tipCoords"])

    tabs.Select(Min(WxState.sel, days.Length))

    ; --- place the window in the bottom-right corner of the work area of the monitor under the cursor ---
    g.Show("Hide")                                      ; size the window without showing it
    g.GetPos(, , &gw, &gh)
    MouseGetPos(&mx, &my)
    wa := WxWorkArea(mx, my)
    m  := Round(A_ScreenDPI / 2.54 * WeatherEdgeCm)    ; cm -> pixels
    x  := Max(wa.L, wa.R - gw - m)
    y  := Max(wa.T, wa.B - gh - m)
    if !IsObject(pos)
        pos := WxState.pos                              ; where the window was at the last close
    if IsObject(pos) && WxOnScreen(pos.x, pos.y)        ; ...if that place is still on a screen
        x := pos.x, y := pos.y
    g.Show("x" x " y" y)

    WxState.gui := g
    WxState.shownTick := A_TickCount
    if WeatherAutoClose {
        WxState.timer := WxCheckFocus
        SetTimer(WxState.timer, 150)
    }
}

; closes the window when it has lost focus
WxCheckFocus() {
    g := WxState.gui
    if !IsObject(g)
        return
    if (A_TickCount - WxState.shownTick < 800)          ; give the new window time to get focus
        return
    if !WinActive("ahk_id " g.Hwnd)
        WxClose(true)
}

WxClose(byFocusLoss := false) {
    if WxState.timer {
        SetTimer(WxState.timer, 0)
        WxState.timer := ""
    }
    if IsObject(WxState.gui) {
        WxState.gui.GetPos(&px, &py)
        WxState.pos := {x: px, y: py}                   ; remember the position until the script restarts
        WxState.gui.Destroy()
        WxState.gui := ""
        WxHandCursor.hwnds.Clear()
        WxTip.Reset()
        if byFocusLoss
            WxState.closedTick := A_TickCount
    }
}

; shows the window, or hides it when it is already open
WxToggle() {
    if IsObject(WxState.gui) {
        WxClose()
        return
    }
    ; the focus watcher has just closed the window because the tray was clicked - stay closed
    if (A_TickCount - WxState.closedTick < 500)
        return
    try
        WxBuild(WxLoad())
    catch as e
        TrayTip("Error: " e.Message, "Weather")
}

; refresh key in the open window: download fresh data and rebuild the window in place
WxRefresh() {
    g := WxState.gui
    if !IsObject(g)
        return
    g.GetPos(&px, &py)
    oldTitle := g.Title
    g.Title := "⟳ " oldTitle                           ; sign of loading (the request blocks for a moment)
    try {
        data := WxLoad(true)
    } catch as e {
        g.Title := oldTitle
        TrayTip("Error: " e.Message, "Weather")
        return
    }
    WxClose()
    WxBuild(data, {x: px, y: py})
}

; ---------- tray icon: middle click ----------
WxTrayMessage(wParam, lParam, msg, hwnd) {
    if (lParam = 0x208)                                 ; WM_MBUTTONUP on the tray icon
        SetTimer(WxToggle, -1)                          ; do the work outside the message handler
}

; ---------- startup (at the end so everything above is already defined) ----------
OnMessage(0x404, WxTrayMessage)                         ; AHK_NOTIFYICON

; the refresh key works only while the weather window is the active window
HotIf((*) => IsObject(WxState.gui) && WinActive("ahk_id " WxState.gui.Hwnd))
Hotkey(WeatherRefreshKey, (*) => WxRefresh())
HotIf()

if (A_LineFile = A_ScriptFullPath) {                    ; run directly, not included
    Persistent()
    SetTimer(WxToggle, -1)
}
