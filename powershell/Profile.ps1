# set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

Import-Module Terminal-Icons
oh-my-posh init pwsh --config "$(scoop prefix oh-my-posh)\themes\pure.omp.json" | Invoke-Expression


# Helper functions
function SetCursorToBlock { Write-Host -NoNewLine "`e[2 q" }
function SetCursorToLine { Write-Host -NoNewLine "`e[6 q" }
function ResetCursor { SetCursorToLine }


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
  nvim $args
  ResetCursor
}

function la { ls -Force $args }

# (e)xplorer
function e {
  if (!$args) { $args = Get-Location }
  explorer.exe $args
}

# (f)ind and open file
function f { fzf | Invoke-Item }

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

  vim

  Stop-Job -Name notes
  Remove-Job -Name notes
  cd $previousDir
}


# Setting the global node_path
$env:NODE_PATH = npm root -g


# Zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
})
