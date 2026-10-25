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

; Theme: "system" (follow the Windows app theme), "dark" or "light"
BD_theme := "system"

; Font size (pt) for the whole Birthdays window
BD_fontSize := 10

; Column widths in pixels, in table order (ФИО, Дата рождения, Знак зодиака,
; Возраст, Дней до ДР, Юбилей). 0 = auto-size that column
BD_colWidths := [0, 0, 0, 0, 0, 0]

; Initial sort: column number 1..6, negative = descending, 0 = order of the file.
; A click on a column header changes it: ascending -> descending -> order of the file
BD_sort := 0

; Key that refreshes the table while the Birthdays window is active.
; Any AutoHotkey key name, e.g. "F5" or "^r" (Ctrl+R); empty = no key
BD_refreshKey := "F5"

; A jubilee is every Nth birthday: 10 -> 30, 40, 50...; 5 -> 25, 30, 35...
BD_jubileeStep := 10

; Colors are RGB hex numbers: 0xRRGGBB
BD_colorToday := 0xFF0000   ; birthday is today
BD_soonDays   := 7          ; highlight birthdays that are 1..BD_soonDays days away
BD_colorSoon  := 0x0000FF   ; color for those "soon" birthdays and for a jubilee "this year" / "next year"
; The same two colors for the dark theme (lighter, to stay readable on a dark background)
BD_colorTodayDark := 0xFF5555
BD_colorSoonDark  := 0x5C9DFF
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
BD_rows := []           ; rows as read from the file (before sorting)
BD_sortCol := (IsInteger(BD_sort) && Abs(BD_sort) <= 6) ? Abs(BD_sort) : 0   ; 0 = file order
BD_sortDesc := (IsInteger(BD_sort) && BD_sort < 0)
BD_dark := false        ; the dark theme is used for the current window
BD_hdr := []            ; dark theme: Text controls that replace the native column header
BD_hdrFill := ""        ; dark theme: header filler on the right of the last column
BD_hdrH := 0            ; dark theme: header height in pixels
BD_appModeForced := false   ; true after the process was switched to the dark app mode

; Run directly (not included) -> just open the window
if (A_LineFile = A_ScriptFullPath)
    BD_Show()

; Opens the window (or brings it to front if it is already open).
; Used as a menu callback, hence the (*) parameters.
BD_Show(*) {
    global BD_gui, BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk, BD_winPos, BD_csvPath, BD_fontSize
    global BD_dark, BD_hdr, BD_hdrFill, BD_hdrH

    if IsObject(BD_gui) {
        BD_gui.Restore()
        BD_gui.Show()
        return
    }

    rows := BD_Load(BD_csvPath)
    if !IsObject(rows)
        return

    BD_dark := BD_IsDark()

    ; Resizable, but without the maximize button.
    ; Title = full path to the file + number of records (header not counted)
    BD_gui := Gui("+Resize -MaximizeBox", BD_Title(rows))
    fontOpts := "s" BD_fontSize
    if BD_dark {
        fontOpts .= " cE6E6E6"
        BD_gui.BackColor := "1E1E1E"
    }
    BD_gui.SetFont(fontOpts)

    ; The 7th column is an empty zero-width helper: it keeps the real last column
    ; from being stretched to the control width during auto-size
    titles := BD_ColTitles()
    titles.Push("")

    BD_hdr := []
    if BD_dark {
        ; The native header ignores custom text colors under the dark theme (black on dark),
        ; so it is hidden (-Hdr) and a row of clickable Text controls is drawn instead.
        ; They are placed above the table by BD_PlaceHeader().
        BD_hdrH := Round(BD_fontSize * 2.4 * A_ScreenDPI / 96)
        for i, title in BD_ColTitles() {
            cell := BD_gui.Add("Text", "x0 y0 w50 h" BD_hdrH " +0x200 +0x100 Background2D2D2D cE6E6E6", "")
            cell.SetFont("s" BD_fontSize " bold cE6E6E6")
            cell.OnEvent("Click", BD_HdrClick.Bind(i))
            BD_hdr.Push(cell)
        }
        BD_hdrFill := BD_gui.Add("Text", "x0 y0 w20 h" BD_hdrH " Background2D2D2D", "")
    }

    lvOpts := BD_dark ? "r15 w600 -E0x200 -Hdr Background262626 cE6E6E6" : "r15 w600 Grid"
    BD_lv := BD_gui.Add("ListView", lvOpts, titles)
    BD_lv.ModifyCol(7, 0)
    BD_lv.OnEvent("ColClick", BD_ColClick)
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
    BD_BindRefreshKey()

    if BD_dark {
        BD_ApplyDarkMode()
    } else {
        BD_ResetAppMode()
        BD_CreateBoldFont()
        ; Bold column headers
        hHeader := SendMessage(0x101F, 0, 0, BD_lv)     ; LVM_GETHEADER
        SendMessage(0x30, BD_hBold, 1, hHeader)         ; WM_SETFONT
    }
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
        ch := lh + 3 * BD_gui.MarginY + bh + (BD_dark ? BD_hdrH : 0)
        showOpts := "w" cw " h" ch
    }

    BD_Layout(cw, ch)
    BD_gui.Show(showOpts)
}

BD_Title(rows) {
    global BD_csvPath
    return BD_csvPath " (" rows.Length ")"
}

; Places the table and the buttons: Edit and Refresh in the bottom left corner,
; OK in the bottom right corner
BD_Layout(w, h) {
    global BD_gui, BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk, BD_dark, BD_hdrH
    mx := BD_gui.MarginX, my := BD_gui.MarginY
    hh := BD_dark ? BD_hdrH : 0         ; dark theme: room for the fake header above the table
    BD_btnOk.GetPos(, , &bw, &bh)
    BD_lv.Move(mx, my + hh, Max(w - 2 * mx, 100), Max(h - 3 * my - bh - hh, 50))
    BD_btnEdit.GetPos(, , &ew)
    BD_btnEdit.Move(mx, h - my - bh)
    BD_btnRefresh.Move(mx + ew + mx, h - my - bh)
    BD_btnOk.Move(w - mx - bw, h - my - bh)
    if BD_dark
        BD_PlaceHeader()
}

; Dark theme: puts the header cells right above the table columns
BD_PlaceHeader() {
    global BD_lv, BD_hdr, BD_hdrFill, BD_hdrH
    BD_lv.GetPos(&lx, &ly, &lw)
    x := lx
    for i, cell in BD_hdr {
        colW := SendMessage(0x101D, i - 1, 0, BD_lv)    ; LVM_GETCOLUMNWIDTH
        cell.Move(x, ly - BD_hdrH, Max(colW - 1, 1), BD_hdrH)   ; 1 px narrower leaves a thin divider
        x += colW
    }
    BD_hdrFill.Move(x, ly - BD_hdrH, Max(lx + lw - x, 1), BD_hdrH)
}

; Dark theme: a click on a header cell sorts like a click on a native header
BD_HdrClick(col, *) {
    BD_ColClick("", col)
}

; Refresh hotkey: works only while the Birthdays window is active
BD_BindRefreshKey() {
    global BD_refreshKey
    key := Trim(BD_refreshKey)
    if (key = "")
        return
    HotIf(BD_WindowActive)
    try Hotkey(key, BD_Refresh, "On")   ; an invalid key name is ignored
    HotIf()
}

BD_WindowActive(*) {
    global BD_gui
    return IsObject(BD_gui) && WinActive("ahk_id " BD_gui.Hwnd)
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
        if BD_dark
            BD_PlaceHeader()            ; column widths may have changed
        BD_gui.Title := BD_Title(rows)
    }
}

BD_ColTitles() {
    return [BD_T("name"), BD_T("birth"), BD_T("zodiac"), BD_T("age"), BD_T("days"), BD_T("jubilee")]
}

; Takes freshly read rows, remembers them and shows the table
BD_FillList(rows) {
    global BD_rows
    BD_rows := rows
    BD_Render(true)
}

; Fills the table from BD_rows using the current sort; fit = also re-size the columns
BD_Render(fit) {
    global BD_lv, BD_rowDays, BD_rowJub
    BD_rowDays := []
    BD_rowJub := []
    BD_lv.Opt("-Redraw")
    BD_lv.Delete()
    for r in BD_SortedRows() {
        BD_lv.Add("", r[1], r[2], r[3], r[4], r[5], r[6])
        BD_rowDays.Push(r[7])           ; raw number of days, for coloring
        BD_rowJub.Push(r[8])
    }
    if fit
        BD_FitColumns()
    BD_MarkSort()
    BD_lv.Opt("+Redraw")
}

; Column widths: fixed from the settings, or auto-size (header + content + small padding).
; The header is measured together with the sort arrow, so the arrow always fits.
BD_FitColumns() {
    global BD_lv, BD_colWidths, BD_dark, BD_hdr
    titles := BD_ColTitles()
    pad := Round(12 * A_ScreenDPI / 96)
    loop 6 {
        w := (BD_colWidths.Has(A_Index) && IsInteger(BD_colWidths[A_Index])) ? BD_colWidths[A_Index] : 0
        if (w > 0) {
            BD_lv.ModifyCol(A_Index, w)
        } else if BD_dark {
            ; There is no native header to measure: use the content width and the width of the header cell text
            BD_lv.ModifyCol(A_Index, "Auto")
            contentW := SendMessage(0x101D, A_Index - 1, 0, BD_lv)
            headerW := BD_TextWidth(BD_hdr[A_Index], " " titles[A_Index] " " Chr(0x25BC))
            BD_lv.ModifyCol(A_Index, Max(contentW, headerW) + pad)
        } else {
            BD_lv.ModifyCol(A_Index, , titles[A_Index] " " Chr(0x25BC))
            BD_lv.ModifyCol(A_Index, "AutoHdr")
            BD_lv.ModifyCol(A_Index, SendMessage(0x101D, A_Index - 1, 0, BD_lv) + pad)
        }
    }
}

; Width in pixels of a text in the font of the given control
BD_TextWidth(ctrl, text) {
    hdc := DllCall("GetDC", "Ptr", ctrl.Hwnd, "Ptr")
    hOld := DllCall("SelectObject", "Ptr", hdc, "Ptr", SendMessage(0x31, 0, 0, ctrl), "Ptr")   ; WM_GETFONT
    size := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", size)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", hOld)
    DllCall("ReleaseDC", "Ptr", ctrl.Hwnd, "Ptr", hdc)
    return NumGet(size, 0, "Int")
}

; Shows an arrow in the header of the sorted column
BD_MarkSort() {
    global BD_lv, BD_sortCol, BD_sortDesc, BD_dark, BD_hdr
    titles := BD_ColTitles()
    loop 6 {
        mark := (A_Index = BD_sortCol) ? " " Chr(BD_sortDesc ? 0x25BC : 0x25B2) : ""
        if BD_dark
            BD_hdr[A_Index].Text := " " titles[A_Index] mark
        else
            BD_lv.ModifyCol(A_Index, , titles[A_Index] mark)
    }
}

; Header click: ascending -> descending -> order of the file
BD_ColClick(ctrl, col) {
    global BD_sortCol, BD_sortDesc
    if (col > 6)
        return
    if (BD_sortCol != col) {
        BD_sortCol := col
        BD_sortDesc := false
    } else if !BD_sortDesc {
        BD_sortDesc := true
    } else {
        BD_sortCol := 0
        BD_sortDesc := false
    }
    BD_Render(false)
}

; Returns BD_rows sorted by the current column (a stable insertion sort)
BD_SortedRows() {
    global BD_rows, BD_sortCol
    if (BD_sortCol < 1)
        return BD_rows
    out := BD_rows.Clone()
    loop out.Length - 1 {
        i := A_Index + 1
        item := out[i]
        j := i - 1
        while (j >= 1 && BD_CompareRows(out[j], item) > 0) {
            out[j + 1] := out[j]
            j--
        }
        out[j + 1] := item
    }
    return out
}

; Compares two rows by the sorted column (ties: by days to birthday)
BD_CompareRows(a, b) {
    global BD_sortCol, BD_sortDesc
    ; Row element used as the sort key for each column:
    ; name, birth date (YYYYMMDD), zodiac (calendar order), age, days to birthday, jubilee (years ahead)
    static keys := [1, 9, 10, 4, 7, 11]
    k := keys[BD_sortCol]
    x := a[k], y := b[k]
    if (k = 1)
        c := StrCompare(x, y, "Locale")
    else
        c := (x < y) ? -1 : (x > y) ? 1 : 0
    if (c != 0)
        return BD_sortDesc ? -c : c
    return (a[7] < b[7]) ? -1 : (a[7] > b[7]) ? 1 : 0
}

; Resolves the BD_theme setting: true = dark. "system" reads the Windows app theme from the registry
BD_IsDark() {
    t := StrLower(Trim(BD_theme))
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
BD_ApplyDarkMode() {
    global BD_gui, BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk
    buf := Buffer(4, 0)
    NumPut("Int", 1, buf)
    ; DWMWA_USE_IMMERSIVE_DARK_MODE is 20 on recent builds, 19 on older Windows 10
    if DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", BD_gui.Hwnd, "Int", 20, "Ptr", buf, "Int", 4) != 0
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", BD_gui.Hwnd, "Int", 19, "Ptr", buf, "Int", 4)
    BD_SetAppMode(2)                    ; 2 = ForceDark
    for ctrl in [BD_lv, BD_btnEdit, BD_btnRefresh, BD_btnOk]
        DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

; The dark app mode is process-wide (it also affects the menus of the script that includes this file),
; so it is switched back when a later opening uses the light theme
BD_ResetAppMode() {
    global BD_appModeForced
    if BD_appModeForced
        BD_SetAppMode(0)                ; 0 = Default
}

; uxtheme ordinal 135 = SetPreferredAppMode (0 = Default, 2 = ForceDark)
BD_SetAppMode(mode) {
    global BD_appModeForced
    try {
        hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        fn := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
        if fn {
            DllCall(fn, "Int", mode)
            BD_appModeForced := (mode = 2)
        }
    }
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

    colorToday := BD_dark ? BD_colorTodayDark : BD_colorToday
    colorSoon := BD_dark ? BD_colorSoonDark : BD_colorSoon

    color := ""
    if (days = 0) {
        color := colorToday
    } else {
        if (days <= BD_soonDays)
            color := colorSoon
        if (subItem = 5 && BD_rowJub.Has(row) && BD_rowJub[row])
            color := colorSoon
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
; [name, birth date, zodiac sign, age, days to birthday (text), jubilee,
;  days (number), jubilee soon (bool), birth date (YYYYMMDD), zodiac index, years to jubilee]
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
    jubK := 9999                            ; years until the jubilee (for sorting)
    nextAge := nextY - d["y"]               ; age at the upcoming birthday
    if (BD_jubileeStep > 0 && nextAge > 0) {
        birthdaysToGo := Mod(BD_jubileeStep - Mod(nextAge, BD_jubileeStep), BD_jubileeStep)
        k := birthdaysToGo + (nextY - curY) ; calendar years from now: 0 = this year
        jubSoon := (k = 1) || (k = 0 && daysLeft > 0)
        jubK := k
        if (k = 0)
            jubilee := (daysLeft = 0) ? BD_T("today") : BD_T("thisYear")
        else if (k = 1)
            jubilee := BD_T("nextYear")
        else
            jubilee := BD_YearsAhead(k)
    }

    zodiacIdx := BD_ZodiacIdx(bMD)
    birthKey := Integer(Format("{:04}{:02}{:02}", d["y"], d["m"], d["d"]))     ; for sorting

    return [name, Format("{:02}.{:02}.{:04}", d["d"], d["m"], d["y"]),
            BD_T("signs")[zodiacIdx], age, (daysLeft = 0) ? BD_T("today") : daysLeft, jubilee,
            daysLeft, jubSoon, birthKey, zodiacIdx, jubK]
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

; Zodiac sign index (1 = Capricorn ... 12 = Sagittarius) by "MMDD" string.
; Boundaries are the same as in the xlsx; names come from the translation table.
BD_ZodiacIdx(md) {
    static limits := ["0121", "0220", "0321", "0421", "0522", "0622",
                      "0723", "0823", "0924", "1024", "1123", "1222"]
    for i, limit in limits {
        if (md < limit)
            return i
    }
    return 1                            ; Dec 22 - Dec 31 -> Capricorn again
}
