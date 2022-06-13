#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
CoordMode, Mouse, Screen ; Move the mouse relative to the screen.
SetCapsLockState, AlwaysOff ; Force Capslock to stay off.

; Map Capslock to Control.
*Capslock::Send {Blind}{LControl down}

; Map press & release of Capslock with no other key to Esc.
*Capslock up::
    Send {Blind}{LControl up}
    if A_PRIORKEY = CapsLock
    {
        Send {Esc}
    }
    return

ToggleCaps(){
    ; this is needed because by default, AHK turns CapsLock off before doing Send.
    SetStoreCapsLockMode, Off
    Send {CapsLock}
    SetStoreCapsLockMode, On
    return
}
>!#CapsLock::ToggleCaps()

; Move the cursor to the top-left of the screen.
#Esc::MouseMove, 0, 0

; Ctrl + hjkl for vimlike movements
^h::Send {CtrlUp}{Left}{CtrlDown}
^j::Send {CtrlUp}{Down}{CtrlDown}
^k::Send {CtrlUp}{Up}{CtrlDown}
^l::Send {CtrlUp}{Right}{CtrlDown}

; Win + Shift + hjkl for contolling windows
#+h::Send #{Left}   ; snap left
#+j::Send #{Down}   ; restore
#+k::Send #{Up}     ; maximize
#+l::Send #{Right}  ; snap right

; Win + backspace to delete (* to allow shift for permanent delete).
*#BS::Send {delete}

; Win + Enter to open context menu.
#Enter::Send {AppsKey}

; Win + q to Alt + F4 (quit app).
#q::Send !{F4}

; RightAlt + $, for euro sign.
>!$::Send {U+20AC}

; Media Keys
^F7::Send {Media_Prev}
^F8::Send {Media_Play_Pause}
^F9::Send {Media_Next}
^F10::Send {Volume_Mute}
^F11::Send {Volume_Down}
^F12::Send {Volume_Up}

; Screen brightness
^F1:: AdjustScreenBrightness(-10)
^F2:: AdjustScreenBrightness(10)

AdjustScreenBrightness(step) {
	static service := "winmgmts:{impersonationLevel=impersonate}!\\.\root\WMI"
	monitors := ComObjGet(service).ExecQuery("SELECT * FROM WmiMonitorBrightness WHERE Active=TRUE")
	monMethods := ComObjGet(service).ExecQuery("SELECT * FROM wmiMonitorBrightNessMethods WHERE Active=TRUE")
	for i in monitors {
		curr := i.CurrentBrightness
		break
	}
	toSet := curr + step
	if (toSet < 0)
		toSet := 0
	if (toSet > 100)
		toSet := 100
	for i in monMethods {
		i.WmiSetBrightness(1, toSet)
		break
	}
	BrightnessOSD()
}

BrightnessOSD() {
	static PostMessagePtr := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "PostMessageW" : "PostMessageA", "Ptr")
	 ,WM_SHELLHOOK := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK", "UInt")
	static FindWindow := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "FindWindowW" : "FindWindowA", "Ptr")
	HWND := DllCall(FindWindow, "Str", "NativeHWNDHost", "Str", "", "Ptr")
	IF !(HWND) {
		try IF ((shellProvider := ComObjCreate("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{00000000-0000-0000-C000-000000000046}"))) {
			try IF ((flyoutDisp := ComObjQuery(shellProvider, "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}", "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}"))) {
				DllCall(NumGet(NumGet(flyoutDisp+0)+3*A_PtrSize), "Ptr", flyoutDisp, "Int", 0, "UInt", 0)
				 ,ObjRelease(flyoutDisp)
			}
			ObjRelease(shellProvider)
		}
		HWND := DllCall(FindWindow, "Str", "NativeHWNDHost", "Str", "", "Ptr")
	}
	DllCall(PostMessagePtr, "Ptr", HWND, "UInt", WM_SHELLHOOK, "Ptr", 0x37, "Ptr", 0)
}

;-----------------------------------------------------------------------------------;
; RightAlt mapping for accents, umlauts, ...                                        ;
; Based on https://gist.github.com/danidiaz/583824e50e3667ab50963cc30c7df0ec        ;
;-----------------------------------------------------------------------------------;

; RightAlt + ' then vocal, for acute accent
; RightAlt + ' then c, for cedille
; RightAlt + ' then b, for Eszett
; RightAlt + ' then n, for eñe
; RightAlt + ' then ?, for inverted question mark
; RightAlt + ' then -, for em dash
; RightAlt + ' then [, for open guillemet
; RightAlt + ' then ], for close guillemet
>!'::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    if (key == "a") { 
        Send {U+00E1}
    }
    else if (key == "A") { 
        Send {U+00C1}
    }
    if (key == "b") { 
        Send {U+00DF}
    }
    else if (key == "B") { 
        Send {U+1E9E}
    }
    if (key == "c") { 
        Send {U+00E7}
    }
    else if (key == "C") { 
        Send {U+00C7}
    }
    else if (key == "e") { 
        Send {U+00E9}
    }
    else if (key == "E") { 
        Send {U+00C9}
    }
    else if (key == "i") { 
        Send {U+00ED}
    }
    else if (key == "I") { 
        Send {U+00CD}
    }
    else if (key == "o") { 
        Send {U+00F3}
    }
    else if (key == "O") { 
        Send {U+00D3}
    }
    else if (key == "u") { 
        Send {U+00FA}
    }
    else if (key == "U") { 
        Send {U+00DA}
    }
    else if (key == "n") { 
        Send {U+00F1}
    }
    else if (key == "N") { 
        Send {U+00D1}
    }
    else if (key == "?") {  
        Send {U+00BF}  ; inverted question mark 
    }
    else if (key == "-") { 
        Send {U+2014} ; em dash
    }
    else if (key == "[") { 
        Send {U+00AB} ; LEFT-POINTING DOUBLE ANGLE QUOTATION MARK (guillemet)
    }
    else if (key == "]") { 
        Send {U+00BB} ; RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK (guillemet) 
    }
return

; RightAlt + ; then vocal, for grave accent
>!;::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    if (key == "a") { 
        Send {U+00E0}
    }
    else if (key == "A") { 
        Send {U+00C0}
    }
    else if (key == "e") { 
        Send {U+00E8}
    }
    else if (key == "E") { 
        Send {U+00C8}
    }
    else if (key == "i") { 
        Send {U+00EC}
    }
    else if (key == "I") { 
        Send {U+00CC}
    }
    else if (key == "o") { 
        Send {U+00F2}
    }
    else if (key == "O") { 
        Send {U+00D2}
    }
    else if (key == "u") { 
        Send {U+00F9}
    }
    else if (key == "U") { 
        Send {U+00D9}
    }
return

; RightAlt + ^ then vocal, for circumflex
>!^::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    if (key == "a") { 
        Send {U+00E2}
    }
    else if (key == "A") { 
        Send {U+00C2}
    }
    else if (key == "e") { 
        Send {U+00EA}
    }
    else if (key == "E") { 
        Send {U+00CA}
    }
    else if (key == "i") { 
        Send {U+00EE}
    }
    else if (key == "I") { 
        Send {U+00CE}
    }
    else if (key == "o") { 
        Send {U+00F4}
    }
    else if (key == "O") { 
        Send {U+00D4}
    }
    else if (key == "u") { 
        Send {U+00FB}
    }
    else if (key == "U") { 
        Send {U+00DB}
    }
return

; RightAlt + " then vocal, for umlaut
>!"::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    if (key == "a") { 
        Send {U+00E4}
    }
    else if (key == "A") { 
        Send {U+00C4}
    }
    else if (key == "e") { 
        Send {U+00EB}
    }
    else if (key == "E") { 
        Send {U+00CB}
    }
    else if (key == "i") { 
        Send {U+00EF}
    }
    else if (key == "I") { 
        Send {U+00CF}
    }
    else if (key == "o") { 
        Send {U+00F6}
    }
    else if (key == "O") { 
        Send {U+00D6}
    }
    else if (key == "u") { 
        Send {U+00FC}
    }
    else if (key == "U") { 
        Send {U+00DC}
    }
return
