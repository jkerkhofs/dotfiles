# Set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$homeDir = "C:\Users\$( $env:UserName )";
$profilePath = (Get-Item -LiteralPath $PSCommandPath).ResolvedTarget
if (!$profilePath)
{
    $profilePath = $PSCommandPath
}
$repoRoot = Split-Path -Parent (Split-Path -Parent $profilePath)
. (Join-Path $repoRoot 'powershell\Updates.ps1')

# Environment variables
$env:SHELL = "pwsh"
$env:LANG = "en_US.utf8"
if ($env:NVM_SYMLINK -and (Test-Path $env:NVM_SYMLINK))
{
    $env:NODE_PATH = Join-Path $env:NVM_SYMLINK 'node_modules'
}
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
function SetCursorShape($shape)
{
    $atLineStart = try
    {
        [Console]::CursorLeft -eq 0
    }
    catch
    {
        $true
    }
    $nudge = if ($atLineStart)
    {
        "$ESC[C$ESC[D"
    }
    else
    {
        "$ESC[D$ESC[C"
    }
    [Console]::Write("$ESC[$shape q$nudge")
}
function SetCursorToBlock
{
    SetCursorShape 2
}
function SetCursorToLine
{
    SetCursorShape 6
}

function prompt
{
    SetCursorToLine
    $loc = $executionContext.SessionState.Path.CurrentLocation;

    Write-Host -ForegroundColor Blue $loc.path.Replace($homeDir, '~');
    Write-Host -NoNewline -ForegroundColor Yellow "❯";

    if ($loc.Provider.Name -eq "FileSystem")
    {
        [Console]::Write("$ESC]9;9;`"$( $loc.ProviderPath )`"$ESC\")
    }
    return " "
}

# Color highlighting for some basic PowerShell output
Import-Module PoshColor

# Zoxide
Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6)
    {
        'prompt'
    }
    else
    {
        'pwd'
    }
    (zoxide init --hook $hook powershell | Out-String)
})

# Helper functions
function GetGitProjectName
{
    $gitTopLevel = (git rev-parse --show-toplevel) 2> $null
    $projectName = ""
    if ($gitTopLevel)
    {
        $projectName = Split-Path (Resolve-Path $gitTopLevel) -Leaf
    }
    return $projectName
}
function SetGitProjectAsWindowTitle
{
    $projectName = GetGitProjectName
    if ($projectName)
    {
        $suffix = ""
        if ($args)
        {
            $suffix = " - " + $args
        }
        $Host.UI.RawUI.WindowTitle = $projectName + $suffix
    }
}

# PSReadLine
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -Colors @{ InlinePrediction = "#685d52" }
Set-PSReadLineOption -EditMode Vi
function OnViModeChange
{
    if ($args[0] -eq 'Command')
    {
        SetCursorToBlock
    }
    else
    {
        SetCursorToLine
    }
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

function lgit
{
    lazygit
}

function vim
{
    SetGitProjectAsWindowTitle "vim"
    nvim $args
    Clear-Host
}

function la
{
    Get-ChildItem -Force $args
}

# Open downloads
function down
{
    $previousDir = Get-Location
    Set-Location "~\Downloads"
    lf
    Set-Location $previousDir
    Clear-Host
}

# Open Drive
function drive
{
    $previousDir = Get-Location
    Set-Location "G:\My Drive"
    lf
    Set-Location $previousDir
    Clear-Host
}

# Open default setup for doing administration
function admin
{
    $previousDir = Get-Location
    Set-Location "~\Downloads"
    wt -w 0 split-pane -V --title Administration -d "G:\My Drive\Administration" lf
    lf
    Set-Location $previousDir
    Clear-Host
}

# Explorer
function e
{
    if ($args)
    {
        explorer.exe $args
    }
    else
    {
        explorer.exe Get-Location
    }
}

# Find and open file
# ctrl-y: copy filename
# alt-y: copy full path
# enter: open file
function f
{
    fd --type f | Sort-Object | fzf --tac --no-sort --multi `
    --bind "ctrl-y:execute-silent(Resolve-Path {} | Split-Path -Leaf | Set-Clipboard)+change-prompt(Filename copied > )" `
    --bind "alt-y:execute-silent(Resolve-Path {} | Set-Clipboard)+change-prompt(Path copied > )" `
    --bind "enter:execute-multi(echo {} | Invoke-Item)" `
  | Split-Path -Parent | Set-Location
}

# Interactive winget update: select packages to upgrade with fzf
function wup
{
    try
    {
        $ignoreFile = Join-Path $repoRoot 'winget\wup-ignore.local.json'
        $candidates = @(Get-WinGetUpdateCandidate -IgnoreFile $ignoreFile)
        if (!$candidates)
        {
            Write-Host -ForegroundColor Green "Everything is up to date"; return
        }
        $selected = @(Select-UpdateCandidate $candidates)
        if (!$selected)
        {
            return
        }
        Update-WinGetCandidate $selected | Format-Table Id, Status, RebootRequired -AutoSize
    }
    catch
    {
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
}

# Update Neovim plugins (lazy.nvim), mason packages and treesitter parsers (see :UpdateAll)
# and show which plugins changed in lazy-lock.json (roll back with git or :Lazy restore)
function nup
{
    try
    {
        $result = Invoke-NeovimUpdate $repoRoot
        Write-Host
        if ($result.Changes)
        {
            foreach ($change in $result.Changes)
            {
                Write-Host "$( $change.Name ): $( $change.Detail )"
            }
            Write-Host "Roll back with git or :Lazy restore."
        }
        else
        {
            Write-Host -ForegroundColor Green "No plugin commits changed"
        }
        if ($result.ExitCode -ne 0)
        {
            Write-Host -ForegroundColor Red "Update finished with errors (exit code $( $result.ExitCode ))"
        }
    }
    catch
    {
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
}

# Interactive global npm update: select packages to upgrade with fzf
function npup
{
    try
    {
        $candidates = @(Get-NpmUpdateCandidate)
        if (!$candidates)
        {
            Write-Host -ForegroundColor Green "Everything is up to date"; return
        }
        $selected = @(Select-UpdateCandidate $candidates)
        if (!$selected)
        {
            return
        }
        Update-NpmCandidate $selected | Format-Table Id, Status, From, To -AutoSize
    }
    catch
    {
        Write-Host -ForegroundColor Red $_.Exception.Message
    }
}

# Run all dotfiles updates (PowerShell modules, winget, Neovim, npm), see update.ps1
function up
{
    & (Join-Path $repoRoot 'update.ps1') -FromProfile
}

# Open notes project in vim while auto pulling/pushing from git in the background every 5 min.
# Cleans up background job after quiting vim.
function notes
{
    $previousDir = Get-Location
    Set-Location ~/Workspace/notes

    Start-Job -Name notes -ScriptBlock {
        while (1)
        {
            git pull
            git add --all
            $date = Get-Date -Format "dd/MM/yyyy HH:mm"
            git commit -m $date
            git push
            Start-Sleep 300
        }
    } | Out-Null

    nvim

    Stop-Job -Name notes
    Remove-Job -Name notes
    Set-Location $previousDir
    Clear-Host
}
