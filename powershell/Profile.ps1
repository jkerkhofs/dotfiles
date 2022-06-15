# Set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# Setting the global node_path
$env:NODE_PATH = "C:\Users\$($env:UserName)\scoop\apps\nvm\current\nodejs\nodejs"

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

# Initialize cursor (disable cursor blink)
SetCursorToLine

# Aliases
Set-Alias c clear

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

# File: find and open file
function f { fzf --tac --multi --bind ctrl-t:toggle-all --header="Open file" | Invoke-Item }

# Yank File Name: find and yank filename
function yfn {
  $path = ""
  if ($args) { $path = Resolve-Path $args }
  else { $path = fzf --tac --header="Yank filename" | Resolve-Path }
  $path | Split-Path -Leaf | Set-Clipboard
}

# Yank File Path: find and yank filepath
function yfp {
  $path = ""
  if ($args) { $path = Resolve-Path $args }
  else { $path = fzf --tac --header="Yank filepath" | Resolve-Path }
  $path | Set-Clipboard
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
