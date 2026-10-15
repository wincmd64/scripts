#Requires AutoHotkey v2.0

/*
Birthdays table: only the name and birth date is necessary to specify. Other fields calculated automatically.

USAGE
  Direct Run or from another script:
      Include the file in your main script:
          #Include *i birthdays.ahk
      and add a tray menu item (any text and icon you like):
          try {
              A_TrayMenu.Add("Birthdays", %"BD_Show"%)
              A_TrayMenu.SetIcon("Birthdays", "shell32.dll", 161)
          }

DATA FILE
  Any plain text file, the extension does not matter (.csv, .txt ...), UTF-8 encoding.
  One person per line, two fields: full name and birth date:

      Full name;Birth date
      Ivanov Ivan Ivanovich;03.01.1987
      Petrova Anna;1990-05-21

  - Delimiter: ; or , or Tab (detected for each line).
  - Date: DD.MM.YYYY, DD/MM/YYYY or YYYY-MM-DD.
  - A header line is optional and can be anything: any line whose second field
    is not a valid date is skipped (such lines are not counted in the window title).
  - Empty lines are ignored.
*/

; ============================ Settings ============================
; Path to the data file (two fields: full name, birth date).
; Default: next to this file. Change it here if needed.
BD_csvPath := RegExReplace(A_LineFile, "[^\\]+$") "birthdays.csv"

; Interface language, including zodiac signs: "ru" or "en"
BD_lang := "ru"

; Font size (pt) for the whole Birthdays window
BD_fontSize := 10

; Column widths in pixels, in table order (ФИО, Дата рождения, Знак зодиака,
; Возраст, Дней до ДР, Юбилей). 0 = auto-size that column
BD_colWidths := [0, 0, 0, 0, 0, 0]

; A jubilee is every Nth birthday: 10 -> 30, 40, 50...; 5 -> 25, 30, 35...
BD_jubileeStep := 10

; Colors are RGB hex numbers: 0xRRGGBB
BD_colorToday := 0xFF0000   ; birthday is today
BD_soonDays   := 7          ; highlight birthdays that are 1..BD_soonDays days away
BD_colorSoon  := 0x0000FF   ; color for those "soon" birthdays and for a jubilee "this year" / "next year"
; ==================================================================

; ------------------------- Translations ---------------------------
BD_i18n := Map()
BD_i18n["ru"] := Map(
    "title", "Дни рождения",
    "name", "ФИО", "birth", "Дата рождения", "zodiac", "Знак зодиака",
    "age", "Возраст", "days", "Дней до ДР", "jubilee", "Юбилей",
    "edit", "Редактировать", "refresh", "Обновить", "ok", "OK",
    "today", "сегодня", "thisYear", "в этом году", "nextYear", "в следующем году",
    "notFound", "Файл не найден:",
    "signs", ["Козерог", "Водолей", "Рыбы", "Овен", "Телец", "Близнецы",
              "Рак", "Лев", "Дева", "Весы", "Скорпион", "Стрелец"])
BD_i18n["en"] := Map(
    "title", "Birthdays",
    "name", "Full name", "birth", "Birth date", "zodiac", "Zodiac sign",
    "age", "Age", "days", "Days to birthday", "jubilee", "Jubilee",
    "edit", "Edit", "refresh", "Refresh", "ok", "OK",
    "today", "today", "thisYear", "this year", "nextYear", "next year",
    "notFound", "File not found:",
    "signs", ["Capricorn", "Aquarius", "Pisces", "Aries", "Taurus", "Gemini",
              "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius"])

BD_lang := StrLower(Trim(BD_lang))
if !BD_i18n.Has(BD_lang)
    BD_lang := "en"

; Returns a translated string for the current language
BD_T(key) {
    return BD_i18n[BD_lang][key]
}

; "через 5 лет" / "in 5 years" (n >= 2)
BD_YearsAhead(n) {
    if (BD_lang = "ru") {
        m100 := Mod(n, 100), m10 := Mod(n, 10)
        word := (m100 >= 11 && m100 <= 14) ? "лет"
              : (m10 = 1) ? "год"
              : (m10 >= 2 && m10 <= 4) ? "года" : "лет"
        return "через " n " " word
    }
    return "in " n " years"
}
; ------------------------------------------------------------------

; Window state
BD_gui := ""            ; Birthdays window (empty if closed)
BD_lv := ""             ; ListView control
BD_btnEdit := ""
BD_btnRefresh := ""
BD_btnOk := ""
BD_hBold := 0           ; bold font handle (column headers)
BD_winPos := ""         ; window position/size, remembered for the whole session
BD_rowDays := []        ; days to birthday for every table row (used for coloring)
BD_rowJub := []         ; true if the jubilee of the row is "this year" / "next year"

; Run directly (not included) -> just open the window
if (A_LineFile = A_ScriptFullPath)
    BD_Show()

; Opens the window (or brings it to front if it is already open).
; Used as a menu callback, hence the (*) parameters.
BD_Show(*) {
    global BD_gui, BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk, BD_winPos, BD_csvPath, BD_fontSize

    if IsObject(BD_gui) {
        BD_gui.Restore()
        BD_gui.Show()
        return
    }

    rows := BD_Load(BD_csvPath)
    if !IsObject(rows)
        return

    ; Resizable, but without the maximize button.
    ; Title = full path to the file + number of records (header not counted)
    BD_gui := Gui("+Resize -MaximizeBox", BD_Title(rows))
    BD_gui.SetFont("s" BD_fontSize)

    ; The 7th column is an empty zero-width helper: it keeps the real last column
    ; from being stretched to the control width during auto-size
    BD_lv := BD_gui.Add("ListView", "r15 w600 Grid",
        [BD_T("name"), BD_T("birth"), BD_T("zodiac"), BD_T("age"), BD_T("days"), BD_T("jubilee"), ""])
    BD_lv.ModifyCol(7, 0)
    BD_lv.OnNotify(-12, BD_CustomDraw)  ; NM_CUSTOMDRAW: row colors

    bw := Round(BD_fontSize * 8 * A_ScreenDPI / 96)
    BD_btnEdit := BD_gui.Add("Button", "", BD_T("edit"))        ; width from the text
    BD_btnRefresh := BD_gui.Add("Button", "w" bw, BD_T("refresh"))
    BD_btnOk := BD_gui.Add("Button", "w" bw " Default", BD_T("ok"))
    BD_btnEdit.OnEvent("Click", BD_Edit)
    BD_btnRefresh.OnEvent("Click", BD_Refresh)
    BD_btnOk.OnEvent("Click", BD_Close)

    ; Esc and the close button both close the window
    BD_gui.OnEvent("Escape", BD_Close)
    BD_gui.OnEvent("Close", BD_Close)
    BD_gui.OnEvent("Size", (g, minMax, w, h) => (minMax = -1) ? "" : BD_Layout(w, h))

    BD_CreateBoldFont()
    ; Bold column headers
    hHeader := SendMessage(0x101F, 0, 0, BD_lv)         ; LVM_GETHEADER
    SendMessage(0x30, BD_hBold, 1, hHeader)             ; WM_SETFONT
    BD_FillList(rows)

    if IsObject(BD_winPos) {
        ; Restore the size and position from the previous opening
        cw := BD_winPos["w"], ch := BD_winPos["h"]
        showOpts := "x" BD_winPos["x"] " y" BD_winPos["y"] " w" cw " h" ch
    } else {
        ; First opening: fit the window to the table width
        total := 0
        loop 6
            total += SendMessage(0x101D, A_Index - 1, 0, BD_lv)     ; LVM_GETCOLUMNWIDTH
        lvW := Min(total + DllCall("GetSystemMetrics", "Int", 2) + 6, A_ScreenWidth - 100)
        BD_lv.Move(, , lvW)

        BD_lv.GetPos(, , &lw, &lh)
        BD_btnOk.GetPos(, , , &bh)
        cw := lw + 2 * BD_gui.MarginX
        ch := lh + 3 * BD_gui.MarginY + bh
        showOpts := "w" cw " h" ch
    }

    BD_Layout(cw, ch)
    BD_gui.Show(showOpts)
}

BD_Title(rows) {
    global BD_csvPath
    return BD_csvPath " (" rows.Length ")"
}

; Places the table and the buttons: Edit in the bottom left corner,
; Refresh and OK in the bottom right corner
BD_Layout(w, h) {
    global BD_gui, BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk
    mx := BD_gui.MarginX, my := BD_gui.MarginY
    BD_btnOk.GetPos(, , &bw, &bh)
    BD_lv.Move(mx, my, Max(w - 2 * mx, 100), Max(h - 3 * my - bh, 50))
    BD_btnEdit.Move(mx, h - my - bh)
    BD_btnOk.Move(w - mx - bw, h - my - bh)
    BD_btnRefresh.Move(w - 2 * mx - 2 * bw, h - my - bh)
}

; Opens the data file in Notepad
BD_Edit(*) {
    global BD_csvPath
    Run('notepad.exe "' BD_csvPath '"')
}

; Re-reads the file and refills the table
BD_Refresh(*) {
    global BD_gui, BD_csvPath
    rows := BD_Load(BD_csvPath)
    if IsObject(rows) {                 ; on error keep the old content
        BD_FillList(rows)
        BD_gui.Title := BD_Title(rows)
    }
}

BD_FillList(rows) {
    global BD_lv, BD_colWidths, BD_rowDays, BD_rowJub
    BD_rowDays := []
    BD_rowJub := []
    BD_lv.Opt("-Redraw")
    BD_lv.Delete()
    for r in rows {
        BD_lv.Add("", r[1], r[2], r[3], r[4], r[5], r[6])
        BD_rowDays.Push(r[7])           ; raw number of days, for coloring
        BD_rowJub.Push(r[8])
    }

    ; Column widths: fixed from the settings, or auto-size (header + content + small padding)
    pad := Round(12 * A_ScreenDPI / 96)
    loop 6 {
        w := (BD_colWidths.Has(A_Index) && IsInteger(BD_colWidths[A_Index])) ? BD_colWidths[A_Index] : 0
        if (w > 0) {
            BD_lv.ModifyCol(A_Index, w)
        } else {
            BD_lv.ModifyCol(A_Index, "AutoHdr")
            BD_lv.ModifyCol(A_Index, SendMessage(0x101D, A_Index - 1, 0, BD_lv) + pad)
        }
    }
    BD_lv.Opt("+Redraw")
}

BD_Close(*) {
    global BD_gui, BD_hBold, BD_winPos
    ; Remember position and size (client area) for the next opening
    if (WinGetMinMax("ahk_id " BD_gui.Hwnd) = 0) {
        BD_gui.GetPos(&x, &y)
        BD_gui.GetClientPos(, , &w, &h)
        BD_winPos := Map("x", x, "y", y, "w", w, "h", h)
    }
    BD_gui.Destroy()
    BD_gui := ""
    if BD_hBold {
        DllCall("DeleteObject", "Ptr", BD_hBold)
        BD_hBold := 0
    }
    if (A_LineFile = A_ScriptFullPath)  ; run directly -> nothing else to keep alive
        ExitApp
}

; Creates a bold copy of the ListView's current font
BD_CreateBoldFont() {
    global BD_lv, BD_hBold
    hFont := SendMessage(0x31, 0, 0, BD_lv)             ; WM_GETFONT
    lf := Buffer(92, 0)                                 ; LOGFONTW
    DllCall("GetObject", "Ptr", hFont, "Int", 92, "Ptr", lf)
    NumPut("Int", 700, lf, 16)                          ; lfWeight = FW_BOLD
    BD_hBold := DllCall("CreateFontIndirectW", "Ptr", lf, "Ptr")
}

; Custom draw of the table cells:
;   birthday today (0 days)            -> whole row in BD_colorToday
;   birthday in 1..BD_soonDays days    -> whole row in BD_colorSoon
;   jubilee "this year" / "next year"  -> the "Юбилей" cell in BD_colorSoon
BD_CustomDraw(ctrl, lParam) {
    stage := NumGet(lParam, 3 * A_PtrSize, "UInt")      ; NMCUSTOMDRAW.dwDrawStage
    if (stage = 0x1)                                    ; CDDS_PREPAINT
        return 0x20                                     ; CDRF_NOTIFYITEMDRAW
    if (stage = 0x10001)                                ; CDDS_ITEMPREPAINT
        return 0x20                                     ; CDRF_NOTIFYSUBITEMDRAW
    if (stage != 0x30001)                               ; CDDS_ITEMPREPAINT | CDDS_SUBITEM
        return 0

    row := NumGet(lParam, 5 * A_PtrSize + 16, "Ptr") + 1    ; dwItemSpec (0-based)
    if !BD_rowDays.Has(row)
        return 0
    days := BD_rowDays[row]

    ; NMLVCUSTOMDRAW: clrText, clrTextBk, iSubItem follow the NMCUSTOMDRAW structure
    clrOffset := (A_PtrSize = 8) ? 80 : 48
    subItem := NumGet(lParam, clrOffset + 8, "Int")     ; 0-based column

    color := ""
    if (days = 0) {
        color := BD_colorToday
    } else {
        if (days <= BD_soonDays)
            color := BD_colorSoon
        if (subItem = 5 && BD_rowJub.Has(row) && BD_rowJub[row])
            color := BD_colorSoon
    }
    if (color != "")
        NumPut("UInt", BD_RgbToBgr(color), lParam, clrOffset)
    return 0                                            ; CDRF_DODEFAULT
}

; 0xRRGGBB -> COLORREF (0x00BBGGRR)
BD_RgbToBgr(c) {
    return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
}

; Reads the data file and returns an array of rows:
; [name, birth date, zodiac sign, age, days to birthday (text), jubilee, days (number), jubilee soon (bool)]
BD_Load(path) {
    if !FileExist(path) {
        MsgBox(BD_T("notFound") "`n" path, BD_T("title"), "Icon!")
        return ""
    }

    text := FileRead(path, "UTF-8")     ; BOM is stripped automatically
    today := SubStr(A_Now, 1, 8)        ; YYYYMMDD
    rows := []

    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if (line = "")
            continue

        ; Auto-detect delimiter: ; , or tab
        delim := InStr(line, ";") ? ";" : InStr(line, "`t") ? "`t" : ","
        f := StrSplit(line, delim)
        if (f.Length < 2)
            continue

        name := Trim(f[1], '" `t')
        d := BD_ParseDate(Trim(f[2], '" `t'))
        if !d                           ; header row or bad date - skip
            continue

        rows.Push(BD_BuildRow(name, d, today))
    }
    return rows
}

; Parses DD.MM.YYYY, DD/MM/YYYY or YYYY-MM-DD into a Map(y, m, d); returns 0 on failure
BD_ParseDate(s) {
    if RegExMatch(s, "^(\d{1,2})[./](\d{1,2})[./](\d{4})$", &m)
        y := Integer(m[3]), mo := Integer(m[2]), d := Integer(m[1])
    else if RegExMatch(s, "^(\d{4})-(\d{1,2})-(\d{1,2})$", &m)
        y := Integer(m[1]), mo := Integer(m[2]), d := Integer(m[3])
    else
        return 0

    if (mo < 1 || mo > 12 || d < 1 || d > BD_DaysInMonth(y, mo))
        return 0
    return Map("y", y, "m", mo, "d", d)
}

BD_BuildRow(name, d, today) {
    curY := Integer(SubStr(today, 1, 4))
    curMD := SubStr(today, 5, 4)
    bMD := Format("{:02}{:02}", d["m"], d["d"])

    ; Full years lived
    age := curY - d["y"] - (bMD > curMD ? 1 : 0)

    ; Next birthday (Feb 29 in a non-leap year -> Mar 1, same as Excel DATE())
    nextY := curY + (bMD < curMD ? 1 : 0)
    daysLeft := DateDiff(BD_BirthdayInYear(d, nextY), today, "Days")

    ; Jubilee: the nearest birthday whose age is a multiple of BD_jubileeStep
    jubilee := ""
    jubSoon := false                        ; jubilee is this year or next year
    nextAge := nextY - d["y"]               ; age at the upcoming birthday
    if (BD_jubileeStep > 0 && nextAge > 0) {
        birthdaysToGo := Mod(BD_jubileeStep - Mod(nextAge, BD_jubileeStep), BD_jubileeStep)
        k := birthdaysToGo + (nextY - curY) ; calendar years from now: 0 = this year
        jubSoon := (k = 1) || (k = 0 && daysLeft > 0)
        if (k = 0)
            jubilee := (daysLeft = 0) ? BD_T("today") : BD_T("thisYear")
        else if (k = 1)
            jubilee := BD_T("nextYear")
        else
            jubilee := BD_YearsAhead(k)
    }

    return [name, Format("{:02}.{:02}.{:04}", d["d"], d["m"], d["y"]),
            BD_Zodiac(bMD), age, (daysLeft = 0) ? BD_T("today") : daysLeft, jubilee, daysLeft, jubSoon]
}

; Returns the birthday date (YYYYMMDD) in the given year
BD_BirthdayInYear(d, year) {
    m := d["m"], dd := d["d"]
    if (m = 2 && dd = 29 && BD_DaysInMonth(year, 2) = 28)
        m := 3, dd := 1
    return Format("{:04}{:02}{:02}", year, m, dd)
}

BD_DaysInMonth(y, m) {
    if (m = 2)
        return (Mod(y, 4) = 0 && (Mod(y, 100) != 0 || Mod(y, 400) = 0)) ? 29 : 28
    return (m = 4 || m = 6 || m = 9 || m = 11) ? 30 : 31
}

; Zodiac sign by "MMDD" string (same boundaries as in the xlsx).
; Sign names come from the translation table: Capricorn, Aquarius, ... Sagittarius
BD_Zodiac(md) {
    static limits := ["0121", "0220", "0321", "0421", "0522", "0622",
                      "0723", "0823", "0924", "1024", "1123", "1222"]
    signs := BD_T("signs")
    for i, limit in limits {
        if (md < limit)
            return signs[i]
    }
    return signs[1]                     ; Dec 22 - Dec 31 -> Capricorn again
}
