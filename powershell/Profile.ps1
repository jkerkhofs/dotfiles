# set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

oh-my-posh init pwsh --config "$PSScriptRoot\pure.jke.omp.json" | Invoke-Expression


# Helper functions
function SetCursorToBlock { Write-Host -NoNewLine "`e[2 q" }
function SetCursorToLine { Write-Host -NoNewLine "`e[6 q" }
function ResetCursor { SetCursorToLine }
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


# Initialize cursor (disable cursor blink)
SetCursorToLine

# PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource History
Set-PsReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
  if ($args[0] -eq 'Command') { SetCursorToBlock } else { SetCursorToLine }
}


# Aliases
Set-Alias c clear
Set-Alias lgit lazygit

function vim {
  SetGitProjectAsWindowTitle "vim"
  nvim $args
  ResetCursor
}

function la { ls -Force $args }

# Explorer
function e {
  if (!$args) { $args = Get-Location }
  explorer.exe $args
}

# File: find and open file
function f { fzf --tac --header="Open file" | Invoke-Item }

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

  ResetCursor
  Stop-Job -Name notes
  Remove-Job -Name notes
  cd $previousDir
}

# Open workspace with vim, lazygit, shell
function work {
  # open new tab
  new-tab
  # open new tab with lazygit
  new-tab lazygit
  # move focus back two tabs
  wt -w 0 ft -p `; ft -p
  vim
}

# New Tab
function new-tab {
  wt -w 0 nt -p PowerShell -d $pwd $args
}


# Setting the global node_path
$env:NODE_PATH = npm root -g


# Zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
  })
