# Set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$homeDir = "C:\Users\$($env:UserName)";

# Environment variables
$env:SHELL = "pwsh"
$env:LANG = "en_US.utf8"
if ($env:NVM_SYMLINK) { $env:NODE_PATH = Join-Path $env:NVM_SYMLINK 'node_modules' }
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

# Cursor control
# Windows Terminal only renders a cursor shape change when the cursor moves (microsoft/terminal#4106),
# so nudge the cursor back and forth after changing the shape.
$ESC = [char]27
function SetCursorShape($shape) {
  $atLineStart = try { [Console]::CursorLeft -eq 0 } catch { $true }
  $nudge = if ($atLineStart) { "$ESC[C$ESC[D" } else { "$ESC[D$ESC[C" }
  [Console]::Write("$ESC[$shape q$nudge")
}
function SetCursorToBlock { SetCursorShape 2 }
function SetCursorToLine { SetCursorShape 6 }

function prompt {
  SetCursorToLine
  $loc = $executionContext.SessionState.Path.CurrentLocation;

  Write-Host -ForegroundColor Blue $loc.path.Replace($homeDir, '~');
  Write-Host -NoNewline -ForegroundColor Yellow "❯";

  if ($loc.Provider.Name -eq "FileSystem") {
    [Console]::Write("$ESC]9;9;`"$($loc.ProviderPath)`"$ESC\")
  }
  return " "
}

# Color highlighting for some basic PowerShell output
Import-Module PoshColor

# Zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
  })

# Helper functions
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
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -Colors @{ InlinePrediction = "#685d52" }
Set-PSReadLineOption -EditMode Vi
function OnViModeChange {
  if ($args[0] -eq 'Command') { SetCursorToBlock } else { SetCursorToLine }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $Function:OnViModeChange
Set-PSReadLineKeyHandler -Key Ctrl-j -Function SwitchPredictionView
Set-PSReadLineKeyHandler -Key Ctrl-k -Function ShowCommandHelp
Set-PSReadLineKeyHandler -Key Ctrl-l -Function ClearScreen

# PSFzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
# Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }

# Initialize lf server for faster startup when needed
# If server is already running, this job will complete immediately
Start-Job -Name start-lf-server -ScriptBlock {
  lf -server
} | Out-Null

function lgit {
  lazygit
}

function vim {
  SetGitProjectAsWindowTitle "vim"
  nvim $args
  clear
}

function la { ls -Force $args }

# Open downloads
function down {
  $previousDir = Get-Location
  cd "~\Downloads"
  lf
  cd $previousDir
  clear
}

# Open Drive
function drive {
  $previousDir = Get-Location
  cd "G:\My Drive"
  lf
  cd $previousDir
  clear
}

# Open default setup for doing administration
function admin {
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
    --bind "enter:execute-multi(echo {} | Invoke-Item)" `
  | Split-Path -Parent | Set-Location
}

# Interactive winget update: select packages to upgrade with fzf
function wup {
  if (!(Get-Module -ListAvailable Microsoft.WinGet.Client)) {
    Write-Host -ForegroundColor Red "Microsoft.WinGet.Client not installed (run install.ps1 or Install-PSResource Microsoft.WinGet.Client)"
    return
  }

  $packages = @(Get-WinGetPackage | Where-Object IsUpdateAvailable | Sort-Object Name)
  if (!$packages) { Write-Host -ForegroundColor Green "Everything is up to date"; return }

  $nameWidth = ($packages.Name | Measure-Object Length -Maximum).Maximum
  $idWidth   = ($packages.Id   | Measure-Object Length -Maximum).Maximum
  $lines = $packages | ForEach-Object {
    $availableVersion = $_.AvailableVersions | Select-Object -First 1
    if ($availableVersion -eq 'Unknown') { $availableVersion = '' }
    "{0}`t{1} {2} {3} -> {4}" -f $_.Id, $_.Name.PadRight($nameWidth), $_.Id.PadRight($idWidth),
      $_.InstalledVersion, $availableVersion
  }

  $selected = $lines | fzf --multi --delimiter "`t" --with-nth 2.. `
    --header "ctrl-space: toggle | ctrl-t: toggle all | del: deselect all | enter: update"
  if (!$selected) { return }

  $selectedIds = $selected | ForEach-Object { ($_ -split "`t", 2)[0] }
  $results = foreach ($id in $selectedIds) {
    Write-Host -ForegroundColor Blue "Updating $id..."
    try {
      $result = Update-WinGetPackage -Id $id -MatchOption Equals -Mode Silent -ErrorAction Stop
      [pscustomobject]@{
        Id             = $id
        Status         = $result.Status
        RebootRequired = $result.RebootRequired
      }
    } catch {
      [pscustomobject]@{
        Id             = $id
        Status         = "Failed: $($_.Exception.Message)"
        RebootRequired = $null
      }
    }
  }
  $results | Format-Table Id, Status, RebootRequired -AutoSize
}

# Open notes project in vim while auto pulling/pushing from git in the background every 5 min.
# Cleans up background job after quiting vim.
function notes {
  $previousDir = Get-Location
  cd ~/Workspace/notes

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

  Stop-Job -Name notes
  Remove-Job -Name notes
  cd $previousDir
  clear
}
