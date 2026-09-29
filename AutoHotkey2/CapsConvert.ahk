; CapsLock: converts selected text (or line to cursor) between layouts and toggles system language.
; Fork from https://habr.com/ru/articles/987334/#comment_29413890

#Requires AutoHotkey v2.0
#SingleInstance Force

en := "QWERTYUIOP{}|ASDFGHJKL:`"ZXCVBNM<>?~@#$^&qwertyuiop[]asdfghjkl;'zxcvbnm,./``"

; Select secondary layout (uncomment needed language):
second := "ЙЦУКЕНГШЩЗХЪ/ФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё`"№;:?йцукенгшщзхъфывапролджэячсмитьбю.ё" ; RU
; second := "ЙЦУКЕНГШЩЗХЇ/ФІВАПРОЛДЖЄЯЧСМИТЬБЮ,Ґ`"№;:?йцукенгшщзхїфівапролджєячсмитьбю.ґ" ; UA

en2second := Map()
for ch in StrSplit(en)
    en2second[ ch ] := SubStr( second, A_Index, 1 )

second2en := Map()
for ch in StrSplit(second)
    second2en[ ch ] := SubStr( en, A_Index, 1 )

CapsLock:: {
    
    backup := ClipboardAll()
    
    A_Clipboard := ""
    Send "#{Space}^c"
    if !ClipWait(0.1) {
        Send "+{Home}^c"
        ClipWait 0.3
    }
    
    if A_Clipboard {
        
        result := ""
        mode := "en"
        
        Loop Parse A_Clipboard {
            
            c2nd := en2second.Get( A_LoopField, "" )
            cEN  := second2en.Get( A_LoopField, "" )
            
            if cEN && c2nd {
                result .= mode = "en" ? cEN : c2nd
            } else if cEN {
                result .= cEN
                mode := "en"
            } else if c2nd {
                result .= c2nd
                mode := "second"
            } else {
                result .= A_LoopField
            }
            
        }
        
        A_Clipboard := result
        Send "^v"
        Sleep 100
        
    }
    
    A_Clipboard := backup
    return
    
}