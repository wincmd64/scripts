; Ctrl+Shift+V - Paste from clipboard to file (.png or .txt)

; === Directives: Only activate ^+v in Total Commander, Explorer, or Desktop ===
#HotIf WinActive("ahk_class TTOTAL_CMD") 
    || WinActive("ahk_class CabinetWClass") 
    || WinActive("ahk_class Progman") 
    || WinActive("ahk_class WorkerW")

^+v:: {
    targetDir := ""
    explorerWin := ""

    ; === 1. DETERMINE ACTIVE WINDOW AND RETRIEVE PATH ===

    if WinActive("ahk_class TTOTAL_CMD") {
        targetDir := GetTCPath()
    }
    else if WinActive("ahk_class CabinetWClass") {
        if (explorerWin := GetExplorerWindow())
            targetDir := explorerWin.Document.Folder.Self.Path
    }
    else if WinActive("ahk_class Progman") || WinActive("ahk_class WorkerW") {
        ; Desktop clicked
        targetDir := A_Desktop
    }

    if (targetDir == "" || !DirExist(targetDir))
        return

    ; === 2. PROCESS CLIPBOARD DATA AND CREATE FILE ===

    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    filePath := ""

    if DllCall("IsClipboardFormatAvailable", "UInt", 2) { ; CF_BITMAP = 2
        filePath := targetDir "\" timestamp "_clip.png"
        if !SaveClipboardImageToPng(filePath)
            return
    }
    else if (A_Clipboard != "") {
        filePath := targetDir "\" timestamp "_clip.txt"
        FileAppend(A_Clipboard, filePath, "UTF-8")
    } else {
        return
    }

    ; === 3. FOCUS / SELECT NEWLY CREATED FILE ===

    Loop 20 {
        if FileExist(filePath)
            break
        Sleep(50)
    }

    if WinActive("ahk_class TTOTAL_CMD") {
        SendMessage(1075, 2009, 0, , "ahk_class TTOTAL_CMD") ; Send cm_RereadSource
        tcPath := EnvGet("COMMANDER_PATH") "\TOTALCMD64.EXE"
        if FileExist(tcPath)
            Run('"' tcPath '" /O /S /L="' filePath '"')
    }
    else if (explorerWin && WinActive("ahk_class CabinetWClass")) {
        try {
            SplitPath(filePath, &fileNameOnly)
            folderItem := explorerWin.Document.Folder.ParseName(fileNameOnly)
            explorerWin.Document.SelectItem(folderItem, 13)
        }
    }
}

; --- Helper function: Retrieve active path from Total Commander via WM_USER+50 ---
GetTCPath() {
    tcHwnd := WinGetID("ahk_class TTOTAL_CMD")
    activeListHwnd := SendMessage(1074, 3, 0, , tcHwnd)
    leftListHwnd := SendMessage(1074, 1, 0, , tcHwnd)
    
    pathControlWhich := (activeListHwnd == leftListHwnd) ? 9 : 10
    pathControlHwnd := SendMessage(1074, pathControlWhich, 0, , tcHwnd)
    
    rawPath := ControlGetText(pathControlHwnd)
    cleanPath := RegExReplace(rawPath, "[>*\r\n]", "")
    return RTrim(Trim(cleanPath), "\")
}

; --- Helper function: Get COM object of the active File Explorer window ---
GetExplorerWindow() {
    activeHwnd := WinGetID("A")
    shell := ComObject("Shell.Application")
    for window in shell.Windows {
        if (window.HWND == activeHwnd)
            return window
    }
    return ""
}

#HotIf

; --- Helper function: Save GDI+ bitmap from clipboard to PNG file ---
SaveClipboardImageToPng(savePath) {
    static pToken := 0
    static clsidPNG := Buffer(16)
    
    if !pToken {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", si, "Ptr", 0)
        DllCall("ole32\CLSIDFromString", "WStr", "{557cf406-1a04-11d3-9a73-0000f81ef32e}", "Ptr", clsidPNG)
    }

    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
        return false
    
    hBitmap := DllCall("GetClipboardData", "UInt", 2, "Ptr")
    DllCall("CloseClipboard")
    
    if !hBitmap
        return false

    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap := 0)
    result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", savePath, "Ptr", clsidPNG, "Ptr", 0)
    
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("DeleteObject", "Ptr", hBitmap)
    return (result == 0)
}
