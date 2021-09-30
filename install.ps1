# Enable script execution by setting the execution policy: Set-ExecutionPolicy RemoteSigned


# Creating symlinks
New-Item -ItemType SymbolicLink `
-Path "C:\Users\$env:UserName\AppData\Roaming\Code\User\settings.json" `
-Target "$PSScriptRoot\vscode\settings.json" `
-Force

New-Item -ItemType SymbolicLink `
-Path "C:\Users\$env:UserName\AppData\Roaming\Code\User\keybindings.json" `
-Target "$PSScriptRoot\vscode\keybindings.json" `
-Force

New-Item -ItemType SymbolicLink `
-Path "C:\Users\$env:UserName\_vsvimrc" `
-Target "$PSScriptRoot\vsvim\_vsvimrc" `
-Force

New-Item -ItemType SymbolicLink `
-Path (Get-Item "C:\users\$env:UserName\AppData\Local\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json").FullName `
-Target "$PSScriptRoot\windows-terminal\settings.json" `
-Force


# Create AutoHotKey shortcut in startup dir.
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut("C:\Users\$env:UserName\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\AutoHotKey.lnk")
$shortcut.TargetPath = "C:\Program Files\AutoHotkey\AutoHotkeyU64_UIA.exe" # Should be the UIA-version for enabling UI access with apps run as admin.
$shortcut.Arguments = "$PSScriptRoot\autohotkey\AutoHotKey.ahk"
$shortcut.Save()


# (Optional) Reset execution policy: Set-ExecutionPolicy Default