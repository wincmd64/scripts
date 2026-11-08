#Requires AutoHotkey v2.0

/*
Calendar. Optionally marks birthdays from a plain data file.

USAGE
  Direct Run or from another script:
      Include the file in your main script:
          #Include *i Calendar.ahk
      and add a tray menu item:
          try TrayAddTop("Calendar", %"cal_Show"%, "timedate.cpl")

DATA FILE (birthdays, optional)
  Any plain text file in UTF-8 encoding; the extension does not matter (.csv, .txt, ...).
  One person per line, with two fields: full name and birth date:

      Full name;Birth date
      Ivanov Ivan Ivanovich;03.01.1987
      Petrova Anna;1990-05-21

  - Delimiter: semicolon, comma or Tab (detected for each line).
  - Date: DD.MM.YYYY, DD/MM/YYYY or YYYY-MM-DD.
  - A header line is optional and can say anything: every line whose second field
    is not a valid date is skipped.
  - Empty lines are ignored. A missing file simply means no birthdays are shown;
    F2 offers to create a sample file.
  - Born on Feb 29: the birthday is shown on Mar 1 in non-leap years.

KEYS (while the Calendar window is active)
  Left / PgUp / Wheel up      previous year
  Right / PgDn / Wheel down   next year
  Home                        current year
  F1                          toggle gray headers of past months
  F5                          re-read the data file
  F2                          edit the data file in Notepad (offers to create it if missing)
  Esc                         close
*/


; ============================ Settings ============================

; Path to the birthdays file (default: next to this file). Empty = no birthdays
cal_csvPath := RegExReplace(A_LineFile, "[^\\]+$") "birthdays.csv"

cal_lang := "system"                ; "system" (Windows display language), "en", "ru" or "uk"
cal_theme := "system"               ; "system" (follow the Windows app theme), "dark" or "light"
cal_fontSize := 9                   ; Font size (pt) of the whole Calendar window
cal_cols := 4                       ; Number of month columns: 4 -> 4x3 (default), 3 -> 3x4, 2 -> 2x6, ...
cal_weekNumbers := 0                ; Show ISO week numbers to the left of every month: 1 = yes, 0 = no
cal_dimPast := 0                    ; Gray out the headers of past months: 1 = yes, 0 = no (F1 toggles it on the fly)

; Keys (any AutoHotkey key name, e.g. "F5" or "^r"); empty = no key.
; They work only while the Calendar window is active
cal_refreshKey := "F5"
cal_editKey := "F2"
cal_pastKey := "F1"

; Month header gradient: 1 = cold-to-warm colors, 0 = one neutral color
cal_gradient := 1
; "Temperature" of every month, January..December: 0 = coldest (blue), 1 = warmest (red)
cal_monthTemp := [0.00, 0.08, 0.30, 0.48, 0.64, 0.82, 1.00, 0.94, 0.72, 0.42, 0.12, 0.02]
; Color ramp that the temperature is mapped to: [temperature, 0xRRGGBB], ascending
cal_ramp := [[0.00, 0x2457C5],     ; deep blue
             [0.20, 0x2F86D6],     ; azure
             [0.35, 0x2FA6A0],     ; teal
             [0.50, 0x9DBA2E],     ; yellow-green
             [0.65, 0xE6B91E],     ; yellow
             [0.80, 0xF08A1E],     ; orange
             [1.00, 0xD9291C]]     ; red
cal_neutralColor := 0x4A6FA5       ; header color when cal_gradient is 0

; Colors are RGB hex numbers: 0xRRGGBB. The "Dark" ones are for the dark theme
cal_colorWeekend := 0xC62828
cal_colorWeekendDark := 0xFF6B6B
cal_colorBirthday := 0x8E24AA       ; circle around a birthday
cal_colorBirthdayDark := 0xC77DFF
cal_colorJubilee := 0xE0A000        ; circle around a jubilee birthday (every 10th)
cal_colorJubileeDark := 0xFFC933
cal_colorPast := 0x9AA0A6           ; header of a past month (when cal_dimPast is on)
cal_colorPastDark := 0x4A4D52


; ------------------------- Translations ---------------------------
cal_i18n := Map()
cal_i18n["ru"] := Map(
    "title", "Календарь", "today", "Сегодня",
    "zodiac", "Знак зодиака", "turns", "Исполнится", "turnsNow", "Исполняется", "turned", "Исполнилось",
    "todayWord", "сегодня", "inWord", "через", "daysWord", "дн.",
    "dateFmt", "{1}, {2} {3} {4} г.",
    "createAsk", "Файл с днями рождения не найден. Создать пример?",
    "createFail", "Не удалось создать файл:",
    "months", ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
               "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"],
    "monthsGen", ["января", "февраля", "марта", "апреля", "мая", "июня",
                  "июля", "августа", "сентября", "октября", "ноября", "декабря"],
    "wdays", ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"],
    "wdaysFull", ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"],
    "signs", ["Козерог", "Водолей", "Рыбы", "Овен", "Телец", "Близнецы",
              "Рак", "Лев", "Дева", "Весы", "Скорпион", "Стрелец"])
cal_i18n["uk"] := Map(
    "title", "Календар", "today", "Сьогодні",
    "zodiac", "Знак зодіаку", "turns", "Виповниться", "turnsNow", "Виповнюється", "turned", "Виповнилось",
    "todayWord", "сьогодні", "inWord", "через", "daysWord", "дн.",
    "dateFmt", "{1}, {2} {3} {4} р.",
    "createAsk", "Файл із днями народження не знайдено. Створити приклад?",
    "createFail", "Не вдалося створити файл:",
    "months", ["Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень",
               "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"],
    "monthsGen", ["січня", "лютого", "березня", "квітня", "травня", "червня",
                  "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"],
    "wdays", ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"],
    "wdaysFull", ["Понеділок", "Вівторок", "Середа", "Четвер", "Пʼятниця", "Субота", "Неділя"],
    "signs", ["Козеріг", "Водолій", "Риби", "Овен", "Телець", "Близнюки",
              "Рак", "Лев", "Діва", "Терези", "Скорпіон", "Стрілець"])
cal_i18n["en"] := Map(
    "title", "Calendar", "today", "Today",
    "zodiac", "Zodiac sign", "turns", "Turns", "turnsNow", "Turns today", "turned", "Turned",
    "todayWord", "today", "inWord", "in", "daysWord", "days",
    "dateFmt", "{1}, {3} {2}, {4}",
    "createAsk", "The birthdays file was not found. Create a sample?",
    "createFail", "Could not create the file:",
    "months", ["January", "February", "March", "April", "May", "June",
               "July", "August", "September", "October", "November", "December"],
    "monthsGen", ["January", "February", "March", "April", "May", "June",
                  "July", "August", "September", "October", "November", "December"],
    "wdays", ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
    "wdaysFull", ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
    "signs", ["Capricorn", "Aquarius", "Pisces", "Aries", "Taurus", "Gemini",
              "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius"])

; Returns a translated item (string or array) for the current language
cal_T(key) {
    return cal_i18n[cal_langCode][key]
}

; Resolves the cal_lang setting to "en", "ru" or "uk"
cal_ResolveLang() {
    l := StrLower(Trim(cal_lang))
    if (l = "ua")
        l := "uk"
    if (l = "en" || l = "ru" || l = "uk")
        return l
    ; "system": the primary language ID is the low byte of A_Language (0x19 = Russian, 0x22 = Ukrainian)
    id := Integer("0x" A_Language) & 0xFF
    return (id = 0x19) ? "ru" : (id = 0x22) ? "uk" : "en"
}

; Today's long date for the window title, e.g. "Воскресенье, 8 ноября 2026 г."
cal_TitleDate() {
    wd := Mod(Integer(FormatTime(A_Now, "WDay")) + 5, 7) + 1      ; 1 = Monday ... 7 = Sunday
    return Format(cal_T("dateFmt"), cal_T("wdaysFull")[wd], Integer(A_DD), cal_T("monthsGen")[Integer(A_MM)], A_YYYY)
}
; ------------------------------------------------------------------

; Window state
cal_gui := ""               ; Calendar window (empty if closed)
cal_year := 0               ; year shown now
cal_winPos := ""            ; window position, remembered for the whole session
cal_dark := false           ; the dark theme is used for the current window
cal_appModeForced := false  ; true after the process was switched to the dark app mode
cal_keysBound := false      ; true after the window hotkeys were registered
cal_langCode := "en"        ; interface language in use: "en", "ru" or "uk"
cal_monthNames := []        ; 12 month names
cal_dayNames := []          ; 7 weekday names, Monday first
cal_people := []            ; birthdays as read from the file: Map(name, y, m, d)
cal_hot := []               ; hover areas of the birthday days in the current window: Map(x, y, w, h, tip)
cal_tipIdx := 0             ; index in cal_hot of the shown tooltip (0 = none)

; Run directly (not included) -> just open the window
if (A_LineFile = A_ScriptFullPath)
    cal_Show()

; Opens the window (or brings it to front if it is already open).
; Used as a menu callback, hence the (*) parameters.
cal_Show(*) {
    global cal_gui

    if IsObject(cal_gui) {
        cal_gui.Restore()
        cal_Refresh()                   ; also picks up changes of the data file
        return
    }
    cal_LoadLocale()
    cal_LoadPeople()
    cal_BindKeys()
    cal_Build(Integer(A_YYYY))
    SetTimer(cal_HoverTick, 100)        ; tooltips for the birthdays
}

; Builds the window for the given year. If a window is already open, the new one
; appears at the same place and the old one is destroyed (this is how the year changes).
cal_Build(year) {
    global cal_gui, cal_year, cal_dark, cal_hot, cal_tipIdx

    year := Min(Max(year, 1601), 9998)          ; range supported by FormatTime
    cal_dark := cal_IsDark()

    if cal_dark {
        bgColor := 0x1E1E1E
        textColor := 0xE6E6E6
        dimColor := 0x9A9A9A
        weekendColor := cal_colorWeekendDark
        bdColor := cal_colorBirthdayDark
        jubColor := cal_colorJubileeDark
    } else {
        bgColor := 0xFFFFFF
        textColor := 0x202020
        dimColor := 0x808080
        weekendColor := cal_colorWeekend
        bdColor := cal_colorBirthday
        jubColor := cal_colorJubilee
    }

    ; All sizes are in real pixels (-DPIScale), scaled here once
    fs := cal_fontSize
    sc := A_ScreenDPI / 96
    cols := (IsInteger(cal_cols) && cal_cols >= 1 && cal_cols <= 12) ? cal_cols : 4
    rows := Ceil(12 / cols)
    cw := Round(fs * 2.9 * sc)                  ; day cell width
    ch := Round(fs * 2.3 * sc)                  ; day cell height (also the birthday circle diameter)
    ringT := Max(2, Round(2 * sc))              ; birthday ring thickness
    hh := Round(fs * 2.6 * sc)                  ; month header height
    wk := cal_weekNumbers ? cw : 0              ; week number column width
    blockW := wk + 7 * cw                       ; one month: width
    blockH := hh + 7 * ch                       ; one month: header + weekday row + 6 week rows
    gap := Round(fs * 2 * sc)                   ; space between months
    mx := Round(fs * 1.5 * sc)                  ; window margins
    my := Round(fs * 1.2 * sc)
    barH := Round(fs * 2.8 * sc)                ; height of the top bar (year and buttons)
    btnW := Round(fs * 3.4 * sc)                ; width of the "previous" / "next" buttons
    btnGap := Round(fs * 0.7 * sc)              ; space between those two buttons
    todayW := Round(fs * 8 * sc)                ; width of the "Today" button
    gridW := cols * blockW + (cols - 1) * gap
    winW := 2 * mx + gridW
    top := my + barH + my                       ; y of the first month row
    winH := top + rows * blockH + (rows - 1) * gap + my

    ; Birthdays of this year by day (key = month * 100 + day)
    curY := Integer(A_YYYY), curM := Integer(A_MM), curD := Integer(A_DD)
    byDay := cal_BirthdaysByDay(year)
    title := cal_TitleDate()

    ToolTip()                                   ; the old window is going away, so is its tooltip
    cal_tipIdx := 0
    cal_hot := []

    g := Gui("-Resize -MaximizeBox -DPIScale", title)
    g.BackColor := Format("{:06X}", bgColor)
    g.SetFont("s" fs " c" Format("{:06X}", textColor), "Segoe UI")

    ; ---- Top bar: [<] [>]   year   [Today] ----
    btnPrev := g.Add("Button", Format("x{} y{} w{} h{}", mx, my, btnW, barH), Chr(0x25C4))
    btnNext := g.Add("Button", Format("x{} y{} w{} h{}", mx + btnW + btnGap, my, btnW, barH), Chr(0x25BA))
    btnPrev.SetFont("s" Round(fs * 1.2), "Segoe UI Symbol")
    btnNext.SetFont("s" Round(fs * 1.2), "Segoe UI Symbol")
    btnToday := g.Add("Button", Format("x{} y{} w{} h{}", winW - mx - todayW, my, todayW, barH), cal_T("today"))
    side := Max(2 * btnW + btnGap, todayW)      ; same room on both sides keeps the year centered
    yearLbl := g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center", mx + side, my, gridW - 2 * side, barH), year)
    yearLbl.SetFont("s" Round(fs * 1.7) " bold c" Format("{:06X}", textColor), "Segoe UI")
    btnPrev.OnEvent("Click", (*) => cal_Go(-1))
    btnNext.OnEvent("Click", (*) => cal_Go(1))
    btnToday.OnEvent("Click", cal_GoToday)

    ; ---- 12 months ----
    loop 12 {
        m := A_Index
        colNo := Mod(m - 1, cols)
        rowNo := (m - 1) // cols
        x0 := mx + colNo * (blockW + gap)
        y0 := top + rowNo * (blockH + gap)
        hc := cal_MonthColor(m)                 ; header color of this month
        if (cal_dimPast && (year < curY || (year = curY && m < curM)))
            hc := cal_dark ? cal_colorPastDark : cal_colorPast      ; this month is already over
        hcText := cal_TextOn(hc)                ; readable text color on that header

        ; Month header: the gradient color lives here
        headerCtl := g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center Background{:06X} c{:06X}",
            x0, y0, blockW, hh, hc, hcText), cal_monthNames[m])
        cal_BoldFont(headerCtl, fs, hcText)

        ; Weekday names (Sat and Sun are tinted)
        loop 7 {
            c := A_Index - 1                    ; column: 0 = Monday ... 6 = Sunday
            g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center c{:06X}",
                x0 + wk + c * cw, y0 + hh, cw, ch, (c >= 5) ? weekendColor : dimColor), cal_dayNames[c + 1])
        }

        ; Where the 1st of the month falls in the grid (weeks start on Monday)
        first := Format("{:04}{:02}01", year, m)
        wday := Integer(FormatTime(first, "WDay"))      ; 1 = Sunday ... 7 = Saturday
        offset := Mod(wday + 5, 7)                      ; 0 = Monday ... 6 = Sunday
        nDays := cal_DaysInMonth(year, m)

        ; Day cells
        loop nDays {
            d := A_Index
            pos := offset + d - 1
            r := pos // 7
            c := Mod(pos, 7)
            x := x0 + wk + c * cw
            y := y0 + hh + ch + r * ch
            isToday := (year = curY && m = curM && d = curD)

            ; Birthdays on this day (a jubilee gets its own circle color)
            people := byDay.Has(m * 100 + d) ? byDay[m * 100 + d] : ""
            hasBd := IsObject(people)
            isJub := false
            if hasBd {
                for p in people {
                    n := year - p["y"]
                    if (n > 0 && Mod(n, 10) = 0)
                        isJub := true
                }
            }

            if isToday {
                ; Today: filled with the color of its month header.
                ; With a birthday the number is drawn over the circle below instead
                cell := g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center Background{:06X} c{:06X}",
                    x, y, cw, ch, hc, hcText), hasBd ? "" : d)
                cal_BoldFont(cell, fs, hcText)
            } else if !hasBd {
                g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center c{:06X}",
                    x, y, cw, ch, (c >= 5) ? weekendColor : textColor), d)
            }

            if hasBd {
                ; The circle is a tiny picture: a ring on the normal background, or a filled
                ; circle on the "today" square. The number is a transparent Text above it
                mark := isJub ? jubColor : bdColor
                path := cal_CircleBmp(ch, ringT, mark, isToday ? hc : bgColor, isToday)
                g.Add("Picture", Format("x{} y{} w{} h{}", x + (cw - ch) // 2, y, ch, ch), path)
                try FileDelete(path)            ; the picture is already loaded
                numColor := isToday ? cal_TextOn(mark) : (c >= 5) ? weekendColor : textColor
                num := g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center BackgroundTrans c{:06X}",
                    x, y, cw, ch, numColor), d)
                if isToday
                    cal_BoldFont(num, fs, numColor)
                cal_hot.Push(Map("x", x, "y", y, "w", cw, "h", ch, "tip", cal_TipText(people, year)))
            }
        }

        ; ISO week numbers: the week is taken from the Thursday cell of each row
        if (wk > 0) {
            loop 6 {
                r := A_Index - 1
                if (r * 7 - offset + 7 < 1 || r * 7 - offset + 1 > nDays)
                    continue                    ; the row has no days of this month
                dd := Min(Max(r * 7 + 3 - offset + 1, 1), nDays)       ; column 3 = Thursday
                ymd := Format("{:04}{:02}{:02}", year, m, dd)
                weekNo := Integer(SubStr(FormatTime(ymd, "YWeek"), 5))
                g.Add("Text", Format("x{} y{} w{} h{} +0x200 Center c{:06X}",
                    x0, y0 + hh + ch + r * ch, wk, ch, dimColor), weekNo)
            }
        }
    }

    if cal_dark
        cal_ApplyDarkMode(g, [btnPrev, btnNext, btnToday])
    else
        cal_ResetAppMode()

    ; Esc and the close button both close the window
    g.OnEvent("Escape", cal_Close)
    g.OnEvent("Close", cal_Close)

    ; Show the new window in place of the old one (if any), then drop the old one
    old := cal_gui
    cal_SavePos()
    opts := "w" winW " h" winH
    if IsObject(cal_winPos)
        opts := "x" cal_winPos["x"] " y" cal_winPos["y"] " " opts
    g.Show(opts)
    cal_gui := g
    cal_year := year
    if IsObject(old)
        old.Destroy()
}

; Remembers the window position (not while minimized)
cal_SavePos() {
    global cal_winPos
    if !IsObject(cal_gui)
        return
    if (WinGetMinMax("ahk_id " cal_gui.Hwnd) != 0)
        return
    cal_gui.GetPos(&x, &y)
    cal_winPos := Map("x", x, "y", y)
}

cal_Close(*) {
    global cal_gui, cal_tipIdx
    cal_SavePos()
    SetTimer(cal_HoverTick, 0)
    ToolTip()
    cal_tipIdx := 0
    cal_gui.Destroy()
    cal_gui := ""
    if (A_LineFile = A_ScriptFullPath)  ; run directly -> nothing else to keep alive
        ExitApp
    ; Next opening starts the hover timer again (see cal_Show)
}

; Shows the year that is delta years away from the current one
cal_Go(delta) {
    cal_Build(cal_year + delta)
}

cal_GoToday(*) {
    cal_Build(Integer(A_YYYY))
}

cal_Prev(*) {
    cal_Go(-1)
}

cal_Next(*) {
    cal_Go(1)
}

; Re-reads the data file and redraws the current year
cal_Refresh(*) {
    cal_LoadPeople()
    cal_Build(cal_year)
}

; Opens the data file in Notepad; if it does not exist, offers to create a sample
cal_Edit(*) {
    path := Trim(cal_csvPath)
    if (path = "")
        return
    if !FileExist(path) {
        if (MsgBox(cal_T("createAsk") "`n`n" path, cal_T("title"), "YesNo Iconi") != "Yes")
            return
        if cal_CreateSample(path)
            cal_Refresh()
        else
            MsgBox(cal_T("createFail") "`n`n" path, cal_T("title"), "Iconx")
        return
    }
    Run('notepad.exe "' path '"')
}

; Writes a small sample data file (UTF-8 with BOM); returns true on success
cal_CreateSample(path) {
    text := "Full name;Birth date`r`n"
    text .= "Сара Коннор;13.11.1965`r`n"
    text .= "Кайл Риз;12.05.2003`r`n"
    text .= "Джон Коннор;28.02.1985`r`n"
    try {
        f := FileOpen(path, "w", "UTF-8")
        f.Write(text)
        f.Close()
        return true
    } catch {
        return false
    }
}

; Grays / colors the headers of past months and redraws
cal_TogglePast(*) {
    global cal_dimPast
    cal_dimPast := !cal_dimPast
    cal_Build(cal_year)
}

; Window hotkeys: work only while the Calendar window is active
cal_BindKeys() {
    global cal_keysBound
    if cal_keysBound
        return
    cal_keysBound := true
    HotIf(cal_WindowActive)
    for k in ["Left", "PgUp", "WheelUp"]
        try Hotkey(k, cal_Prev, "On")
    for k in ["Right", "PgDn", "WheelDown"]
        try Hotkey(k, cal_Next, "On")
    try Hotkey("Home", cal_GoToday, "On")
    key := Trim(cal_refreshKey)
    if (key != "")
        try Hotkey(key, cal_Refresh, "On")  ; an invalid key name is ignored
    key := Trim(cal_editKey)
    if (key != "")
        try Hotkey(key, cal_Edit, "On")
    key := Trim(cal_pastKey)
    if (key != "")
        try Hotkey(key, cal_TogglePast, "On")
    HotIf()
}

cal_WindowActive(*) {
    return IsObject(cal_gui) && WinActive("ahk_id " cal_gui.Hwnd)
}

; ---------------------------- Birthdays ---------------------------

; Reads the data file into cal_people (a missing or unreadable file = no birthdays)
cal_LoadPeople() {
    global cal_people
    cal_people := []
    path := Trim(cal_csvPath)
    if (path = "" || !FileExist(path))
        return
    try {
        text := FileRead(path, "UTF-8")     ; BOM is stripped automatically
    } catch {
        return
    }

    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if (line = "")
            continue

        ; Auto-detect delimiter: ; , or tab
        delim := InStr(line, ";") ? ";" : InStr(line, "`t") ? "`t" : ","
        f := StrSplit(line, delim)
        if (f.Length < 2)
            continue

        d := cal_ParseDate(Trim(f[2], '" `t'))
        if !d                               ; header row or bad date - skip
            continue
        cal_people.Push(Map("name", Trim(f[1], '" `t'), "y", d["y"], "m", d["m"], "d", d["d"]))
    }
}

; Parses DD.MM.YYYY, DD/MM/YYYY or YYYY-MM-DD into a Map(y, m, d); returns 0 on failure
cal_ParseDate(s) {
    if RegExMatch(s, "^(\d{1,2})[./](\d{1,2})[./](\d{4})$", &mt)
        y := Integer(mt[3]), mo := Integer(mt[2]), d := Integer(mt[1])
    else if RegExMatch(s, "^(\d{4})-(\d{1,2})-(\d{1,2})$", &mt)
        y := Integer(mt[1]), mo := Integer(mt[2]), d := Integer(mt[3])
    else
        return 0

    if (y < 1 || mo < 1 || mo > 12 || d < 1 || d > cal_DaysInMonth(y, mo))
        return 0
    return Map("y", y, "m", mo, "d", d)
}

; Month and day of the person's birthday in the given year as [m, d]
; (Feb 29 in a non-leap year -> Mar 1)
cal_BirthdayMD(p, year) {
    m := p["m"], d := p["d"]
    if (m = 2 && d = 29 && cal_DaysInMonth(year, 2) = 28)
        m := 3, d := 1
    return [m, d]
}

; Birthdays of the given year grouped by day: Map(month * 100 + day -> array of people).
; Nobody is shown in the years before the birth year
cal_BirthdaysByDay(year) {
    res := Map()
    for p in cal_people {
        if (year < p["y"])
            continue
        md := cal_BirthdayMD(p, year)
        key := md[1] * 100 + md[2]
        if !res.Has(key)
            res[key] := []
        res[key].Push(p)
    }
    return res
}

; Tooltip text for a day: one block per person, blocks separated by an empty line.
; Name, birth date (with "(in N days)" while the birthday is still ahead this year), zodiac sign,
; age reached on that birthday. All relative to today
cal_TipText(list, year) {
    today := SubStr(A_Now, 1, 8)
    curY := Integer(A_YYYY)
    out := ""
    for p in list {
        n := year - p["y"]                          ; age reached on that birthday
        md := cal_BirthdayMD(p, year)
        daysTo := DateDiff(Format("{:04}{:02}{:02}", year, md[1], md[2]), today, "Days")

        txt := p["name"] "`n" Format("{:02}.{:02}.{:04}", p["d"], p["m"], p["y"])
        if (daysTo > 0 && year = curY) {            ; days left: current year only
            daysWord := (cal_langCode = "en" && daysTo = 1) ? "day" : cal_T("daysWord")
            txt .= " (" cal_T("inWord") " " daysTo " " daysWord ")"
        } else if (daysTo = 0) {
            txt .= " (" cal_T("todayWord") ")"
        }                                           ; passed or another year: no brackets

        txt .= "`n" cal_T("zodiac") ": " cal_T("signs")[cal_ZodiacIdx(Format("{:02}{:02}", p["m"], p["d"]))]

        ageKey := (daysTo > 0) ? "turns" : (daysTo = 0) ? "turnsNow" : "turned"
        txt .= "`n" cal_T(ageKey) ": " n

        out .= (out != "" ? "`n`n" : "") txt
    }
    return out
}

; Zodiac sign index (1 = Capricorn ... 12 = Sagittarius) by "MMDD" string
cal_ZodiacIdx(md) {
    static limits := ["0121", "0220", "0321", "0421", "0522", "0622",
                      "0723", "0823", "0924", "1024", "1123", "1222"]
    for i, limit in limits {
        if (md < limit)
            return i
    }
    return 1                            ; Dec 22 - Dec 31 -> Capricorn again
}

; Timer: shows a tooltip while the mouse is over a birthday day, hides it otherwise.
; The day cells are plain Text controls that let the mouse through, so the cursor
; position is checked against the stored cell rectangles
cal_HoverTick() {
    global cal_tipIdx
    if !IsObject(cal_gui) {
        ToolTip()
        cal_tipIdx := 0
        return
    }
    CoordMode("Mouse", "Screen")
    CoordMode("ToolTip", "Screen")
    MouseGetPos(&sx, &sy, &hwnd)
    idx := 0
    if (hwnd = cal_gui.Hwnd) {
        ; Screen -> window client coordinates
        pt := Buffer(8, 0)
        NumPut("Int", sx, pt, 0)
        NumPut("Int", sy, pt, 4)
        DllCall("user32\ScreenToClient", "Ptr", cal_gui.Hwnd, "Ptr", pt)
        cx := NumGet(pt, 0, "Int")
        cy := NumGet(pt, 4, "Int")
        for i, area in cal_hot {
            if (cx >= area["x"] && cx < area["x"] + area["w"] && cy >= area["y"] && cy < area["y"] + area["h"]) {
                idx := i
                break
            }
        }
    }
    if (idx = cal_tipIdx)
        return
    cal_tipIdx := idx
    if idx
        ToolTip(cal_hot[idx]["tip"], sx + 16, sy + 20)
    else
        ToolTip()
}

; Writes a small 24-bit BMP file with an anti-aliased ring (or a filled circle) of the given
; diameter d and returns its path. Everything else is filled with bgColor, so no transparency
; is needed. The pixels are computed here, no GDI/GDI+ calls
cal_CircleBmp(d, ringT, markColor, bgColor, filled) {
    static seq := 0
    seq++
    path := A_Temp "\cal_circle_" A_TickCount "_" seq ".bmp"

    rowBytes := (d * 3 + 3) & ~3                ; every row is padded to 4 bytes
    size := 54 + rowBytes * d
    buf := Buffer(size, 0)
    NumPut("UShort", 0x4D42, buf, 0)            ; "BM"
    NumPut("UInt", size, buf, 2)                ; file size
    NumPut("UInt", 54, buf, 10)                 ; offset of the pixel data
    NumPut("UInt", 40, buf, 14)                 ; BITMAPINFOHEADER size
    NumPut("Int", d, buf, 18)                   ; width
    NumPut("Int", d, buf, 22)                   ; height (positive = rows go bottom-up)
    NumPut("UShort", 1, buf, 26)                ; planes
    NumPut("UShort", 24, buf, 28)               ; bits per pixel

    mR := (markColor >> 16) & 0xFF, mG := (markColor >> 8) & 0xFF, mB := markColor & 0xFF
    bR := (bgColor >> 16) & 0xFF, bG := (bgColor >> 8) & 0xFF, bB := bgColor & 0xFF
    r := d / 2
    rOut := r - 0.5                             ; outer edge of the circle
    rIn := rOut - ringT                         ; inner edge of the ring
    loop d {
        py := A_Index - 1                       ; pixel row from the top
        rowOff := 54 + (d - 1 - py) * rowBytes
        loop d {
            px := A_Index - 1
            dist := Sqrt((px + 0.5 - r) ** 2 + (py + 0.5 - r) ** 2)
            a := Min(Max(rOut - dist + 0.5, 0), 1)              ; coverage of the outer edge
            if !filled
                a *= Min(Max(dist - rIn + 0.5, 0), 1)           ; and of the inner edge
            off := rowOff + px * 3
            NumPut("UChar", Round(bB + (mB - bB) * a), buf, off)        ; BMP stores B, G, R
            NumPut("UChar", Round(bG + (mG - bG) * a), buf, off + 1)
            NumPut("UChar", Round(bR + (mR - bR) * a), buf, off + 2)
        }
    }
    f := FileOpen(path, "w")
    f.RawWrite(buf)
    f.Close()
    return path
}
; ------------------------------------------------------------------

; ----------------------- Colors of the headers ---------------------

; Header color (0xRRGGBB) of the month m (1..12)
cal_MonthColor(m) {
    if !cal_gradient
        return cal_neutralColor
    t := cal_monthTemp.Has(m) ? cal_monthTemp[m] : 0.5
    return cal_RampColor(t)
}

; Maps a temperature 0..1 to a color: linear blend between the two nearest ramp stops
cal_RampColor(t) {
    n := cal_ramp.Length
    t := Min(Max(t, 0), 1)
    loop n - 1 {
        a := cal_ramp[A_Index]
        b := cal_ramp[A_Index + 1]
        if (t <= b[1] || A_Index = n - 1) {
            f := (b[1] = a[1]) ? 0 : Min(Max((t - a[1]) / (b[1] - a[1]), 0), 1)
            ca := a[2], cb := b[2]
            rr := cal_Lerp((ca >> 16) & 0xFF, (cb >> 16) & 0xFF, f)
            gg := cal_Lerp((ca >> 8) & 0xFF, (cb >> 8) & 0xFF, f)
            bb := cal_Lerp(ca & 0xFF, cb & 0xFF, f)
            return (rr << 16) | (gg << 8) | bb
        }
    }
    return cal_ramp[n][2]
}

cal_Lerp(a, b, f) {
    return Round(a + (b - a) * f)
}

; Dark or white text, whichever is readable on the given background color
cal_TextOn(c) {
    lum := 0.299 * ((c >> 16) & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * (c & 0xFF)
    return (lum >= 150) ? 0x1A1A1A : 0xFFFFFF
}

; Bold font for one control (the color is passed too, so it is not lost)
cal_BoldFont(ctrl, fs, rgb) {
    ctrl.SetFont("s" fs " bold c" Format("{:06X}", rgb), "Segoe UI")
}
; ------------------------------------------------------------------

; ------------------------- Dates and language ---------------------

cal_DaysInMonth(y, m) {
    if (m = 2)
        return (Mod(y, 4) = 0 && (Mod(y, 100) != 0 || Mod(y, 400) = 0)) ? 29 : 28
    return (m = 4 || m = 6 || m = 9 || m = 11) ? 30 : 31
}

; Picks the language (called on every opening)
cal_LoadLocale() {
    global cal_langCode, cal_monthNames, cal_dayNames

    cal_langCode := cal_ResolveLang()
    cal_monthNames := cal_T("months")
    cal_dayNames := cal_T("wdays")
}
; ------------------------------------------------------------------

; ----------------------------- Theme ------------------------------

; Resolves the cal_theme setting: true = dark. "system" reads the Windows app theme from the registry
cal_IsDark() {
    t := StrLower(Trim(cal_theme))
    if (t = "dark")
        return true
    if (t = "light")
        return false
    try {
        return RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 0
    } catch {
        return false                    ; no such value -> light
    }
}

; Dark title bar and dark-themed native controls (best effort, Windows 10 1903+)
cal_ApplyDarkMode(g, ctrls) {
    buf := Buffer(4, 0)
    NumPut("Int", 1, buf)
    ; DWMWA_USE_IMMERSIVE_DARK_MODE is 20 on recent builds, 19 on older Windows 10
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Ptr", buf, "Int", 4) != 0
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 19, "Ptr", buf, "Int", 4)
    cal_SetAppMode(2)                   ; 2 = ForceDark
    for ctrl in ctrls
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

; The dark app mode is process-wide (it also affects the menus of the script that includes this file),
; so it is switched back when a later opening uses the light theme
cal_ResetAppMode() {
    if cal_appModeForced
        cal_SetAppMode(0)               ; 0 = Default
}

; uxtheme ordinal 135 = SetPreferredAppMode (0 = Default, 2 = ForceDark)
cal_SetAppMode(mode) {
    global cal_appModeForced
    try {
        hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        fn := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        if fn {
            DllCall(fn, "Int", mode)
            cal_appModeForced := (mode = 2)
        }
    }
}
; ------------------------------------------------------------------
