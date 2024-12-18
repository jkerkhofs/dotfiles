# Set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$homeDir = "C:\Users\$($env:UserName)";

# Environment variables
$env:SHELL = "pwsh"
$env:LANG = "en_US.utf8"
$env:NODE_PATH = "$($homeDir)\scoop\apps\nvm\current\nodejs\nodejs"
$env:FZF_DEFAULT_OPTS = @'
    --bind "ctrl-u:half-page-up"
    --bind "ctrl-d:half-page-down"
    --bind "ctrl-space:toggle"
    --bind "ctrl-t:toggle-all"
    --bind "del:deselect-all"
    --bind "ctrl-s:toggle-sort"
    --bind "shift-right:accept"
'@
$env:DOTNET_CLI_TELEMETRY_OPTOUT = 1 # Get rid of dotnet telemetry

# Settings
$PSStyle.Progress.UseOSCIndicator = $true

function prompt {
  $loc = $executionContext.SessionState.Path.CurrentLocation;

  Write-Host -ForegroundColor Blue $loc.path.Replace($homeDir, '~');
  Write-Host -NoNewline -ForegroundColor Yellow "❯";

  $out = " ";
  if ($loc.Provider.Name -eq "FileSystem") {
    $out += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
  }
  return $out
}

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

# CompletionPredictor
Import-Module CompletionPredictor

# PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -Colors @{ InlinePrediction = "#685d52" }
Set-PsReadLineOption -EditMode Vi
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
  if ($args[0] -eq 'Command') { SetCursorToBlock } else { SetCursorToLine }
}
Set-PSReadLineKeyHandler -Key Ctrl-j -Function SwitchPredictionView
Set-PSReadLineKeyHandler -Key Ctrl-k -Function ShowCommandHelp
Set-PSReadlineKeyHandler -Key Ctrl-l -Function ClearScreen

# PSFzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
# Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# Initialize cursor (disable cursor blink)
SetCursorToLine

# Initialize lf server for faster startup when needed
# If server is already running, this job will complete immediately
Start-Job -Name start-lf-server -ScriptBlock {
  lf -server
} | Out-Null

function lgit {
  lazygit
  SetCursorToLine
}

function vim {
  SetGitProjectAsWindowTitle "vim"
  nvim $args
  SetCursorToLine
  clear
}

function la { ls -Force $args }

# Open downloads
function down {
  $Host.UI.RawUI.WindowTitle = "Downloads"
  $previousDir = Get-Location
  cd "~\Downloads"
  lf
  cd $previousDir
  clear
}

# Open Drive
function drive {
  $Host.UI.RawUI.WindowTitle = "Drive"
  $previousDir = Get-Location
  cd "G:\My Drive"
  lf
  cd $previousDir
  clear
}

# Open default setup for doing administration
function admin {
  $Host.UI.RawUI.WindowTitle = "Downloads"
  $previousDir = Get-Location
  cd "~\Downloads"
  wt -w 0 split-pane -V --title Administration -d "G:\My Drive\Administration" lf
  lf
  cd $previousDir
  clear
}

# Explorer
function e {
  if (!$args) { $args = Get-Location }
  explorer.exe $args
}

# Find and open file
# ctrl-y: copy filename
# alt-y: copy full path
# enter: open file
function f {
  fd --type f | sort | fzf --tac --no-sort --multi `
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
  clear
}
