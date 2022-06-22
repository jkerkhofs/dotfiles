#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
CoordMode, Mouse, Screen ; Move the mouse relative to the screen.
SetCapsLockState, AlwaysOff ; Force CapsLock to stay off.
SetKeyDelay 0 ; Set key delay to lowest recommended value.
GroupAdd, VimApps, ahk_exe WindowsTerminal.exe
GroupAdd, VimApps, ahk_exe devenv.exe
GroupAdd, VimApps, ahk_exe Code.exe

; Map CapsLock to Esc
CapsLock::Esc

; Fix glitches with CapsLock-modifier combos
!CapsLock::Return
^CapsLock::Return
+CapsLock::Return
#CapsLock::Return
!+CapsLock::Return
^+CapsLock::Return
#+CapsLock::Return

; Right Alt + CapsLock to toggle CapsLock
>!CapsLock::
  If GetKeyState("CapsLock", "T") = 1
    SetCapsLockState, AlwaysOff
  Else
    SetCapsLockState, AlwaysOn
  Return

; Vim movements everywhere
CapsLock & h::Send {Blind}{Left}
CapsLock & j::Send {Blind}{Down}
CapsLock & k::Send {Blind}{Up}
CapsLock & l::Send {Blind}{Right}
CapsLock & d::Send {Blind}{PgDn}
CapsLock & u::Send {Blind}{PgUp}

; Map CapsLock + d|u back to Ctrl + d|u for vim-like apps
#IfWinActive ahk_group VimApps
  CapsLock & d::Send {Blind}^d
  CapsLock & u::Send {Blind}^u
#IfWinActive

; CapsLock + char behaves like Ctrl + char
CapsLock & q::Send {Blind}^q
CapsLock & w::Send {Blind}^w
CapsLock & e::Send {Blind}^e
CapsLock & r::Send {Blind}^r
CapsLock & t::Send {Blind}^t
CapsLock & y::Send {Blind}^y
CapsLock & i::Send {Blind}^i
CapsLock & o::Send {Blind}^o
CapsLock & p::Send {Blind}^p
CapsLock & a::Send {Blind}^a
CapsLock & s::Send {Blind}^s
CapsLock & f::Send {Blind}^f
CapsLock & g::Send {Blind}^g
CapsLock & z::Send {Blind}^z
CapsLock & x::Send {Blind}^x
CapsLock & c::Send {Blind}^c
CapsLock & v::Send {Blind}^v
CapsLock & b::Send {Blind}^b
CapsLock & n::Send {Blind}^n
CapsLock & m::Send {Blind}^m
CapsLock & -::Send {Blind}^-
CapsLock & =::Send {Blind}^=
CapsLock & [::Send {Blind}^[
CapsLock & ]::Send {Blind}^]
CapsLock & `;::Send {Blind}^`;
CapsLock & '::Send {Blind}^'
CapsLock & \::Send {Blind}^\
CapsLock & ,::Send {Blind}^,
CapsLock & .::Send {Blind}^.
CapsLock & /::Send {Blind}^/
CapsLock & 0::Send {Blind}^0
CapsLock & 1::Send {Blind}^1
CapsLock & 2::Send {Blind}^2
CapsLock & 3::Send {Blind}^3
CapsLock & 4::Send {Blind}^4
CapsLock & 5::Send {Blind}^5
CapsLock & 6::Send {Blind}^6
CapsLock & 7::Send {Blind}^7
CapsLock & 8::Send {Blind}^8
CapsLock & 9::Send {Blind}^9
CapsLock & Space::Send {Blind}^{Space}
CapsLock & Enter::Send {Blind}^{Enter}
CapsLock & Backspace::Send {Blind}^{Backspace}

; Win + backspace to delete (* to allow shift for permanent delete).
*#BS::Send {Delete}

; Win + Enter to open context menu.
#Enter::Send {AppsKey}

; Win + q to Alt + F4 (quit app).
#q::Send !{F4}

; Win + Shift + h|j|k|l for contolling windows
#+h::Send #{Left}   ; snap left
#+j::Send #{Down}   ; restore
#+k::Send #{Up}     ; maximize
#+l::Send #{Right}  ; snap right

; Move the cursor to the top-left of the screen.
#Esc::MouseMove, 0, 0

; Media Keys
CapsLock & F7::Send {Media_Prev}
CapsLock & F8::Send {Media_Play_Pause}
CapsLock & F9::Send {Media_Next}
CapsLock & F10::Send {Volume_Mute}
CapsLock & F11::Send {Volume_Down}
CapsLock & F12::Send {Volume_Up}

; Screen brightness
CapsLock & F1:: AdjustScreenBrightness(-10)
CapsLock & F2:: AdjustScreenBrightness(10)

AdjustScreenBrightness(step) {
	static service := "winmgmts:{impersonationLevel=impersonate}!\\.\root\WMI"
	monitors := ComObjGet(service).ExecQuery("SELECT * FROM WmiMonitorBrightness WHERE Active=TRUE")
	monMethods := ComObjGet(service).ExecQuery("SELECT * FROM wmiMonitorBrightNessMethods WHERE Active=TRUE")
	For i In monitors {
		curr := i.CurrentBrightness
		Break
	}
	toSet := curr + step
	If (toSet < 0)
		toSet := 0
	If (toSet > 100)
		toSet := 100
	For i In monMethods {
		i.WmiSetBrightness(1, toSet)
		Break
	}
	BrightnessOSD()
}

BrightnessOSD() {
	static PostMessagePtr := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "PostMessageW" : "PostMessageA", "Ptr")
	 ,WM_SHELLHOOK := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK", "UInt")
	static FindWindow := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", A_IsUnicode ? "FindWindowW" : "FindWindowA", "Ptr")
	HWND := DllCall(FindWindow, "Str", "NativeHWNDHost", "Str", "", "Ptr")
	If !(HWND) {
		Try If ((shellProvider := ComObjCreate("{C2F03A33-21F5-47FA-B4BB-156362A2F239}", "{00000000-0000-0000-C000-000000000046}"))) {
			Try If ((flyoutDisp := ComObjQuery(shellProvider, "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}", "{41f9d2fb-7834-4ab6-8b1b-73e74064b465}"))) {
				DllCall(NumGet(NumGet(flyoutDisp+0)+3*A_PtrSize), "Ptr", flyoutDisp, "Int", 0, "UInt", 0)
				 ,ObjRelease(flyoutDisp)
			}
			ObjRelease(shellProvider)
		}
		HWND := DllCall(FindWindow, "Str", "NativeHWNDHost", "Str", "", "Ptr")
	}
	DllCall(PostMessagePtr, "Ptr", HWND, "UInt", WM_SHELLHOOK, "Ptr", 0x37, "Ptr", 0)
}

#IfWinActive ahk_exe msedge.exe
  ; Open new tab (regardless of shift)
  CapsLock & t::
    If GetKeyState("Shift","P")
      Send ^t
    else
      Send ^t
    Return

  ; Close tab (regardless of shift)
  CapsLock & w::
    If GetKeyState("Shift","P")
      Send ^w
    else
      Send ^w
    Return

  ; CapsLock + Shift + [ => navigates tabs
  ; CapsLock + [ => goes back in history
  CapsLock & [::
    If GetKeyState("Shift","P")
      Send ^+{Tab}
    else
      Send !{Left}
    Return

  ; CapsLock + Shift + [ => navigates tabs
  ; CapsLock + [ => goes forward in history
  CapsLock & ]::
    If GetKeyState("Shift","P")
      Send ^{Tab}
    else
      Send !{Right}
    Return

  ; CapsLock + Space moves focus to webpage
  CapsLock & Space::Send {F10}{F10}
#IfWinActive


;-----------------------------------------------------------------------------------;
; RightAlt mapping for accents, umlauts, ...                                        ;
; Based on https://gist.github.com/danidiaz/583824e50e3667ab50963cc30c7df0ec        ;
;-----------------------------------------------------------------------------------;

; RightAlt + $, for euro sign.
>!$::Send {U+20AC}

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
    If (key == "a") { 
        Send {U+00E1}
    }
    Else If (key == "A") { 
        Send {U+00C1}
    }
    If (key == "b") { 
        Send {U+00DF}
    }
    Else If (key == "B") { 
        Send {U+1E9E}
    }
    If (key == "c") { 
        Send {U+00E7}
    }
    Else If (key == "C") { 
        Send {U+00C7}
    }
    Else If (key == "e") { 
        Send {U+00E9}
    }
    Else If (key == "E") { 
        Send {U+00C9}
    }
    Else If (key == "i") { 
        Send {U+00ED}
    }
    Else If (key == "I") { 
        Send {U+00CD}
    }
    Else If (key == "o") { 
        Send {U+00F3}
    }
    Else If (key == "O") { 
        Send {U+00D3}
    }
    Else If (key == "u") { 
        Send {U+00FA}
    }
    Else If (key == "U") { 
        Send {U+00DA}
    }
    Else If (key == "n") { 
        Send {U+00F1}
    }
    Else If (key == "N") { 
        Send {U+00D1}
    }
    Else If (key == "?") {  
        Send {U+00BF}  ; inverted question mark 
    }
    Else If (key == "-") { 
        Send {U+2014} ; em dash
    }
    Else If (key == "[") { 
        Send {U+00AB} ; LEFT-POINTING DOUBLE ANGLE QUOTATION MARK (guillemet)
    }
    Else If (key == "]") { 
        Send {U+00BB} ; RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK (guillemet) 
    }
Return

; RightAlt + ; then vocal, for grave accent
>!;::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    If (key == "a") { 
        Send {U+00E0}
    }
    Else If (key == "A") { 
        Send {U+00C0}
    }
    Else If (key == "e") { 
        Send {U+00E8}
    }
    Else If (key == "E") { 
        Send {U+00C8}
    }
    Else If (key == "i") { 
        Send {U+00EC}
    }
    Else If (key == "I") { 
        Send {U+00CC}
    }
    Else If (key == "o") { 
        Send {U+00F2}
    }
    Else If (key == "O") { 
        Send {U+00D2}
    }
    Else If (key == "u") { 
        Send {U+00F9}
    }
    Else If (key == "U") { 
        Send {U+00D9}
    }
Return

; RightAlt + ^ then vocal, for circumflex
>!^::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    If (key == "a") { 
        Send {U+00E2}
    }
    Else If (key == "A") { 
        Send {U+00C2}
    }
    Else If (key == "e") { 
        Send {U+00EA}
    }
    Else If (key == "E") { 
        Send {U+00CA}
    }
    Else If (key == "i") { 
        Send {U+00EE}
    }
    Else If (key == "I") { 
        Send {U+00CE}
    }
    Else If (key == "o") { 
        Send {U+00F4}
    }
    Else If (key == "O") { 
        Send {U+00D4}
    }
    Else If (key == "u") { 
        Send {U+00FB}
    }
    Else If (key == "U") { 
        Send {U+00DB}
    }
Return

; RightAlt + " then vocal, for umlaut
>!"::
    Input, key, L1 M T3, {Delete}{Esc}{Home}{End}{Enter}{BS}
    If (key == "a") { 
        Send {U+00E4}
    }
    Else If (key == "A") { 
        Send {U+00C4}
    }
    Else If (key == "e") { 
        Send {U+00EB}
    }
    Else If (key == "E") { 
        Send {U+00CB}
    }
    Else If (key == "i") { 
        Send {U+00EF}
    }
    Else If (key == "I") { 
        Send {U+00CF}
    }
    Else If (key == "o") { 
        Send {U+00F6}
    }
    Else If (key == "O") { 
        Send {U+00D6}
    }
    Else If (key == "u") { 
        Send {U+00FC}
    }
    Else If (key == "U") { 
        Send {U+00DC}
    }
Return
