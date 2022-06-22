# Set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# Environment variables
$env:SHELL = "pwsh"
$env:LANG = "en_US.utf8"
$env:NODE_PATH = "C:\Users\$($env:UserName)\scoop\apps\nvm\current\nodejs\nodejs"
$env:_PSFZF_FZF_DEFAULT_OPTS = "--bind ctrl-s:toggle-sort --bind ctrl-u:half-page-up --bind ctrl-d:half-page-down"

# Prompt
oh-my-posh init pwsh --config "$PSScriptRoot\pure.jke.omp.json" | Invoke-Expression

# Color highlighting for some basic PowerShell output
Import-Module PSColor

# Zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
  })

# Helper functions
function SetCursorToBlock { Write-Host -NoNewLine "`e[2 q" }
function SetCursorToLine { Write-Host -NoNewLine "`e[6 q" }
function GetGitProjectName {
  $gitTopLevel = (git rev-parse --show-toplevel) 2> $null
  $projectName = ""
  if ($gitTopLevel) {
    $projectName = Split-Path (Resolve-Path $gitTopLevel) -Leaf
  }
  return $projectName
}
function SetGitProjectAsWindowTitle {
  $projectName = GetGitProjectName
  if ($projectName) {
    $suffix = ""
    if ($args) { $suffix = " - " + $args }
    $Host.UI.RawUI.WindowTitle = $projectName + $suffix
  }
}

# PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource History
Set-PsReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
  if ($args[0] -eq 'Command') { SetCursorToBlock } else { SetCursorToLine }
}
Set-PSReadlineKeyHandler -Key Ctrl-l -Function ClearScreen

# PSFzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# Initialize cursor (disable cursor blink)
SetCursorToLine

function lgit {
  lazygit
  SetCursorToLine
}

function vim {
  SetGitProjectAsWindowTitle "vim"
  nvim $args
  SetCursorToLine
}

function la { ls -Force $args }

# Explorer
function e {
  if (!$args) { $args = Get-Location }
  explorer.exe $args
}

# Find and open file
# enter: open file
# ctrl-space: go to directory
# ctrl-y: copy filename
# alt-y: copy full path
function f {
  fd --type f | sort | fzf --tac --no-sort --multi `
    --bind "ctrl-u:half-page-up" `
    --bind "ctrl-d:half-page-down" `
    --bind "ctrl-t:toggle-all" `
    --bind "ctrl-a:select-all" `
    --bind "ctrl-x:deselect-all" `
    --bind "ctrl-s:toggle-sort" `
    --bind "ctrl-space:accept" `
    --bind "ctrl-y:execute-silent(Resolve-Path {} | Split-Path -Leaf | Set-Clipboard)+change-prompt(Filename copied > )" `
    --bind "alt-y:execute-silent(Resolve-Path {} | Set-Clipboard)+change-prompt(Path copied > )" `
    --bind "enter:execute-multi(echo {} | Invoke-Item)"
  | Split-Path -Parent | Set-Location
}

# Open notes project in vim while auto pulling/pushing from git in the background every 5 min.
# Cleans up background job after quiting vim.
function notes {
  $previousDir = Get-Location
  cd ~/Workspace/notes
  $Host.UI.RawUI.WindowTitle = "Notes"

  Start-Job -Name notes -ScriptBlock {
    while (1) {
      git pull
      git add --all
      $date = Get-Date -Format "dd/MM/yyyy HH:mm"
      git commit -m $date
      git push
      sleep 300
    }
  } | Out-Null

  nvim

  SetCursorToLine
  Stop-Job -Name notes
  Remove-Job -Name notes
  cd $previousDir
}
