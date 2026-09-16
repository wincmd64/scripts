; Ctrl+Shift+V - pastes clipboard content (image or text)  
; as a new file. Works in three contexts:
;   - Total Commander  -> saved into the active panel's current path
;   - Windows Explorer -> saved into the currently open folder
;   - Desktop          -> saved directly on the desktop
;
; Image clipboard data is saved as "<timestamp>_clip.png" (via GDI+),
; text clipboard data as "<timestamp>_clip.txt".
;
; After saving, the script also moves the cursor/selection onto the newly
; created file, mimicking what Explorer already does natively:
;   - Total Commander: re-sorts by date to bring the new file to the top,
;     places the cursor on it, then restores the original name sort
;     (there is no direct "select file by name" command in TC's internal
;     command set, see WM_USER+50/51 docs).
;   - Explorer: uses the Shell.Application COM SelectItem method.
;   - Desktop: forces Explorer to notice the new icon (SHChangeNotify),
;     then selects it directly via ListView messages (LVM_FINDITEM /
;     LVM_SETITEMSTATE), since the desktop has no equivalent of TC's
;     "reread source" command and no COM selection API either.


TC_QUERY := 1074 ; WM_USER+50 - query data from Total Commander
TC_EXEC  := 1075 ; WM_USER+51 - execute a Total Commander internal command

#HotIf WinActive("ahk_class TTOTAL_CMD")
    || WinActive("ahk_class CabinetWClass")
    || WinActive("ahk_class Progman")
    || WinActive("ahk_class WorkerW")

^+v:: { ; Ctrl+Shift+V
    activeClass := WinGetClass("A")
    targetDir := ""
    explorerWin := ""

    ; === 1. Determine the destination folder ===
    switch activeClass {
        case "TTOTAL_CMD":
            targetDir := GetTCPath()
        case "CabinetWClass":
            if (explorerWin := GetExplorerWindow())
                targetDir := explorerWin.Document.Folder.Self.Path
        case "Progman", "WorkerW":
            targetDir := A_Desktop
        default:
            return
    }
    if (targetDir == "" || !DirExist(targetDir))
        return

    ; === 2. Save the clipboard contents to a file ===
    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")

    if DllCall("IsClipboardFormatAvailable", "UInt", 2) { ; CF_BITMAP
        filePath := targetDir "\" timestamp "_clip.png"
        if !SaveClipboardImageToPng(filePath)
            return
    } else if (A_Clipboard != "") {
        filePath := targetDir "\" timestamp "_clip.txt"
        FileAppend(A_Clipboard, filePath, "UTF-8")
    } else {
        return
    }

    Loop 20 {
        if FileExist(filePath)
            break
        Sleep(50)
    }
    SplitPath(filePath, &fileName)

    ; === 3. Move the cursor/selection onto the new file ===
    switch activeClass {
        case "TTOTAL_CMD":
            SelectInTC(fileName)
        case "CabinetWClass":
            if explorerWin {
                try explorerWin.Document.SelectItem(explorerWin.Document.Folder.ParseName(fileName), 13)
            }
        case "Progman", "WorkerW":
            SelectOnDesktop(filePath, fileName)
    }
}

; --- Active panel's path in TC (via WM_USER+50) ---
GetTCPath() {
    tcHwnd := WinGetID("ahk_class TTOTAL_CMD")
    activeList := SendMessage(TC_QUERY, 3, 0, , tcHwnd)   ; active file list
    leftList := SendMessage(TC_QUERY, 1, 0, , tcHwnd)     ; left panel's file list
    pathCtrl := SendMessage(TC_QUERY, (activeList == leftList) ? 9 : 10, 0, , tcHwnd)
    path := RegExReplace(ControlGetText(pathCtrl), "[>*\r\n]", "")
    return RTrim(Trim(path), "\")
}

; --- Put the cursor on the new file in TC: sort by date, then back to name ---
SelectInTC(fileName) {
    tcHwnd := WinGetID("ahk_class TTOTAL_CMD")
    activePanel := SendMessage(TC_QUERY, 1000, 0, , tcHwnd) ; 1=left, 2=right
    countWParam := (activePanel = 1) ? 1001 : 1002
    initialCount := SendMessage(TC_QUERY, countWParam, 0, , tcHwnd)

    Loop 20 { ; wait until the panel actually sees the new file (max ~2 sec)
        PostMessage(TC_EXEC, 2009, 0, , tcHwnd) ; cm_RereadSource
        Sleep(100)
        if (SendMessage(TC_QUERY, countWParam, 0, , tcHwnd) > initialCount)
            break
    }

    ; cm_SrcByName 8 / cm_SrcByDateTime 2 / cm_GoToFirstFile / cm_SrcByName 9
    PostMessage(TC_EXEC, 321,  8, , tcHwnd)
    PostMessage(TC_EXEC, 324,  2, , tcHwnd)
    PostMessage(TC_EXEC, 2050, 0, , tcHwnd)
    PostMessage(TC_EXEC, 321,  9, , tcHwnd)
}

; --- COM object for the active Explorer window ---
GetExplorerWindow() {
    activeHwnd := WinGetID("A")
    for window in ComObject("Shell.Application").Windows {
        if (window.HWND == activeHwnd)
            return window
    }
    return ""
}

#HotIf

; --- hwnd of the desktop's icon list (Progman/WorkerW -> SHELLDLL_DefView -> SysListView32) ---
GetDesktopListView() {
    defView := DllCall("FindWindowEx", "Ptr", WinExist("ahk_class Progman"), "Ptr", 0, "Str", "SHELLDLL_DefView", "Ptr", 0, "Ptr")
    if !defView {
        for w in WinGetList("ahk_class WorkerW") { ; on Win10/11 icons sometimes live in a separate WorkerW
            defView := DllCall("FindWindowEx", "Ptr", w, "Ptr", 0, "Str", "SHELLDLL_DefView", "Ptr", 0, "Ptr")
            if defView
                break
        }
    }
    return defView ? DllCall("FindWindowEx", "Ptr", defView, "Ptr", 0, "Str", "SysListView32", "Ptr", 0, "Ptr") : 0
}

; --- Allocate memory in another process, write a buffer into it, return the remote address ---
AllocWriteRemote(hProc, buf, size) {
    remote := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "UPtr", size, "UInt", 0x1000, "UInt", 0x04, "Ptr")
    if remote
        DllCall("WriteProcessMemory", "Ptr", hProc, "Ptr", remote, "Ptr", buf, "UPtr", size, "Ptr", 0)
    return remote
}

; --- Put the cursor on the new file on the Desktop.
;     force Explorer to notice the new file (SHChangeNotify), then select it
;     directly via LVM_FINDITEM/LVM_SETITEMSTATE - "typing" the name via
;     ControlSend is unreliable because Explorer doesn't always refresh the
;     view in time. ---
SelectOnDesktop(filePath, fileName) {
    static LVM_FINDITEMW     := 0x1000 + 83
    static LVM_SETITEMSTATE  := 0x1000 + 43
    static LVM_ENSUREVISIBLE := 0x1000 + 19

    DllCall("shell32\SHChangeNotify", "Int", 0x2, "UInt", 0x5, "WStr", filePath, "Ptr", 0) ; SHCNE_CREATE, SHCNF_PATHW

    listHwnd := 0
    Loop 10 {
        if (listHwnd := GetDesktopListView())
            break
        Sleep(50)
    }
    if !listHwnd
        return

    pid := 0
    DllCall("GetWindowThreadProcessId", "Ptr", listHwnd, "UInt*", &pid)
    hProc := pid ? DllCall("OpenProcess", "UInt", 0x38, "Int", false, "UInt", pid, "Ptr") : 0 ; VM_OPERATION|VM_READ|VM_WRITE
    if !hProc
        return

    try {
        nameBuf := Buffer((StrLen(fileName) + 1) * 2)
        StrPut(fileName, nameBuf, "UTF-16")
        remoteName := AllocWriteRemote(hProc, nameBuf, nameBuf.Size)

        findInfo := Buffer(40, 0)
        NumPut("UInt", 0x0002, findInfo, 0)  ; LVFI_STRING
        NumPut("Ptr", remoteName, findInfo, 8)
        remoteFindInfo := AllocWriteRemote(hProc, findInfo, 40)

        index := -1
        Loop 10 { ; the icon may not have made it into the view yet
            index := SendMessage(LVM_FINDITEMW, -1, remoteFindInfo, , "ahk_id " listHwnd)
            if (index != -1 && index != 0xFFFFFFFF)
                break
            Sleep(100)
        }
        if (index = -1 || index = 0xFFFFFFFF)
            return

        lvItem := Buffer(96, 0)
        NumPut("UInt", 0x0008, lvItem, 0)   ; LVIF_STATE
        NumPut("UInt", 0x0003, lvItem, 12)  ; LVIS_FOCUSED|LVIS_SELECTED
        NumPut("UInt", 0x0003, lvItem, 16)
        remoteLvItem := AllocWriteRemote(hProc, lvItem, 96)

        SendMessage(LVM_SETITEMSTATE, index, remoteLvItem, , "ahk_id " listHwnd)
        SendMessage(LVM_ENSUREVISIBLE, index, 0, , "ahk_id " listHwnd)

        for remotePtr in [remoteName, remoteFindInfo, remoteLvItem]
            DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", remotePtr, "UPtr", 0, "UInt", 0x8000)
    } finally {
        DllCall("CloseHandle", "Ptr", hProc)
    }
}

; --- Save a clipboard bitmap as a PNG file (via GDI+) ---
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
