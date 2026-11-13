# Enable script execution by setting the execution policy: Set-ExecutionPolicy RemoteSigned
# Run with PowerShell 7.4+ (pwsh) as administrator, or enable Developer Mode to allow creating symlinks.
#Requires -Version 7.4

$ErrorActionPreference = 'Stop'

# Output helpers: every phase prints a numbered header and every item a status line (OK, SKIP, WARN or FAIL).
# All results are collected for the summary at the end.
$phaseCount = 7
$phaseNames = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$statusColors = @{ OK = 'Green'; SKIP = 'DarkGray'; WARN = 'Yellow'; FAIL = 'Red' }
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Start-Phase($Name)
{
  $phaseNames.Add($Name)
  Write-Host ""
  Write-Host ("==> [{0}/{1}] {2}" -f $phaseNames.Count, $phaseCount, $Name) -ForegroundColor Cyan
}

function Write-Result($Status, $Item, $Detail)
{
  $results.Add([pscustomobject]@{ Phase = $phaseNames[-1]; Status = $Status; Item = $Item; Detail = $Detail })
  Write-Host ("    {0,-4}  " -f $Status) -ForegroundColor $statusColors[$Status] -NoNewline
  if ($Detail)
  {
    Write-Host "$Item " -NoNewline
    Write-Host "- $Detail" -ForegroundColor DarkGray
  } else
  {
    Write-Host $Item
  }
}

function Write-Summary
{
  Write-Host ""
  Write-Host "==> Summary" -ForegroundColor Cyan
  foreach ($phaseName in $phaseNames)
  {
    $phaseResults = @($results | Where-Object Phase -eq $phaseName)
    $counts = foreach ($status in 'OK', 'SKIP', 'WARN', 'FAIL')
    {
      $count = @($phaseResults | Where-Object Status -eq $status).Count
      if ($count) { "$count $status" }
    }
    $worst = 'FAIL', 'WARN', 'OK', 'SKIP' | Where-Object { $_ -in $phaseResults.Status } | Select-Object -First 1
    Write-Host ("    {0,-30}" -f $phaseName) -NoNewline
    Write-Host ($counts -join ', ') -ForegroundColor $statusColors[$worst ?? 'SKIP']
  }

  $issues = @($results | Where-Object Status -in 'WARN', 'FAIL')
  if ($issues)
  {
    Write-Host ""
    Write-Host "    Needs attention:"
    foreach ($issue in $issues)
    {
      Write-Host ("    {0,-4}  " -f $issue.Status) -ForegroundColor $statusColors[$issue.Status] -NoNewline
      Write-Host "[$($issue.Phase)] $($issue.Item) - $($issue.Detail)"
    }
  }

  $count = @{}
  foreach ($status in 'OK', 'SKIP', 'WARN', 'FAIL') { $count[$status] = @($results | Where-Object Status -eq $status).Count }
  $result = if ($count.FAIL) { 'FAILED' } elseif ($count.WARN) { 'FINISHED WITH WARNINGS' } else { 'SUCCEEDED' }
  Write-Host ""
  Write-Host ("Install {0} in {1:mm\:ss} ({2} OK, {3} SKIP, {4} WARN, {5} FAIL)" -f
    $result, $stopwatch.Elapsed, $count.OK, $count.SKIP, $count.WARN, $count.FAIL) `
    -ForegroundColor ($count.FAIL ? 'Red' : $count.WARN ? 'Yellow' : 'Green')
}

function Get-DisplayPath($Path)
{
  $Path -replace "^$([regex]::Escape($HOME))", '~'
}

# Returns the IDs of all packages installed from the winget source, or $null when they cannot be determined.
function Get-WinGetInstalledIds
{
  $exportFile = Join-Path ([System.IO.Path]::GetTempPath()) "dotfiles-winget-export-$PID.json"
  try
  {
    winget export --output $exportFile --source winget --accept-source-agreements --disable-interactivity | Out-Null
    if (Test-Path $exportFile)
    {
      @((Get-Content -Raw $exportFile | ConvertFrom-Json).Sources.Packages.PackageIdentifier)
    }
  } catch
  {
    $null
  } finally
  {
    Remove-Item $exportFile -ErrorAction SilentlyContinue
  }
}

# Creates a symlink, including its parent directory. An existing file or directory that is not a link is moved
# aside to <path>.bak-<timestamp> instead of being overwritten.
function New-Symlink($Path, $Target)
{
  $displayPath = Get-DisplayPath $Path
  try
  {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item.LinkType -and $item.LinkTarget -eq $Target)
    {
      Write-Result OK $displayPath 'already linked'
      return
    }

    $status, $detail = 'OK', 'linked'
    if ($item -and !$item.LinkType)
    {
      $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
      Move-Item -LiteralPath $Path -Destination $backup
      $status, $detail = 'WARN', "linked; existing $($item.PSIsContainer ? 'directory' : 'file') moved to '$(Get-DisplayPath $backup)'"
    } elseif ($item)
    {
      $detail = "relinked (was '$($item.LinkTarget)')"
    }
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
    Write-Result $status $displayPath $detail
  } catch
  {
    Write-Result FAIL $displayPath $_.Exception.Message
  }
}

function Get-ModuleVersion($Name)
{
  Get-InstalledPSResource -Name $Name -Scope CurrentUser -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty Version
}

Write-Host "Installing dotfiles from '$PSScriptRoot'" -ForegroundColor Cyan

# Checking prerequisites
Start-Phase 'Prerequisites'
Write-Result OK 'PowerShell' $PSVersionTable.PSVersion
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
$isDevMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
    -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
if ($isAdmin -or $isDevMode)
{
  Write-Result OK 'Symlink permission' ($isAdmin ? 'running as administrator' : 'Developer Mode enabled')
} else
{
  Write-Result FAIL 'Symlink permission' 'run this script as administrator or enable Developer Mode'
}
if (Get-Command winget -ErrorAction SilentlyContinue)
{
  Write-Result OK 'winget' (winget --version)
} else
{
  Write-Result FAIL 'winget' "not found; install 'App Installer' from the Microsoft Store first"
}
if ($results.Status -contains 'FAIL')
{
  Write-Summary
  exit 1
}

# Installing winget packages
# packages.json is shared; packages.local.json (same format, git-ignored) holds work- and machine-specific packages.
Start-Phase 'winget packages'
foreach ($packageFile in "$PSScriptRoot\winget\packages.json", "$PSScriptRoot\winget\packages.local.json")
{
  $fileName = Split-Path $packageFile -Leaf
  if (!(Test-Path $packageFile))
  {
    Write-Result SKIP $fileName 'file not found'
    continue
  }

  $ids = @((Get-Content -Raw $packageFile | ConvertFrom-Json).Sources.Packages.PackageIdentifier)
  Write-Host "    Checking $($ids.Count) packages from $fileName..."
  $before = Get-WinGetInstalledIds
  $toInstall = if ($null -ne $before) { @($ids | Where-Object { $_ -notin $before }) } else { $ids }
  if (!$toInstall)
  {
    Write-Result OK $fileName "all $($ids.Count) packages already installed"
    continue
  }

  Write-Host "    Installing $($toInstall.Count) of $($ids.Count) packages: $($toInstall -join ', ')"
  winget import --import-file $packageFile `
    --accept-package-agreements --accept-source-agreements --no-upgrade
  $exitCode = $LASTEXITCODE
  $after = Get-WinGetInstalledIds
  if ($null -ne $before -and $null -ne $after)
  {
    $missing = @($ids | Where-Object { $_ -notin $after })
    $detail = "{0} installed, {1} already installed" -f ($toInstall.Count - $missing.Count), ($ids.Count - $toInstall.Count)
    if ($missing)
    {
      Write-Result FAIL $fileName "$detail, $($missing.Count) not installed: $($missing -join ', ')"
    } else
    {
      Write-Result OK $fileName $detail
    }
  } elseif ($exitCode -eq 0)
  {
    Write-Result OK $fileName 'winget import succeeded'
  } else
  {
    Write-Result WARN $fileName ("winget import exited with 0x{0:X8}; one or more packages may not be installed (see output above)" -f $exitCode)
  }
}

# Keep AutoHotkey on v1 (the script in autohotkey\ uses v1 syntax)
Start-Phase 'AutoHotkey version pin'
winget pin add --id AutoHotkey.AutoHotkey --exact --version '1.1.*' --force --accept-source-agreements --source winget | Out-Null
if ($LASTEXITCODE -eq 0)
{
  Write-Result OK 'AutoHotkey.AutoHotkey' 'pinned to 1.1.*'
} else
{
  Write-Result WARN 'AutoHotkey.AutoHotkey' ("pinning to 1.1.* failed with exit code 0x{0:X8}" -f $LASTEXITCODE)
}

# Creating symlinks
Start-Phase 'Symlinks'
New-Symlink "C:\Users\$env:UserName\Documents\PowerShell\Profile.ps1" "$PSScriptRoot\powershell\Profile.ps1"
New-Symlink "C:\Users\$env:UserName\AppData\Roaming\Code\User\settings.json" "$PSScriptRoot\vscode\settings.json"
New-Symlink "C:\Users\$env:UserName\AppData\Roaming\Code\User\keybindings.json" "$PSScriptRoot\vscode\keybindings.json"
New-Symlink "C:\Users\$env:UserName\_vsvimrc" "$PSScriptRoot\vsvim\_vsvimrc"
New-Symlink "C:\Users\$env:UserName\.ideavimrc" "$PSScriptRoot\ideavim\ideavimrc"
New-Symlink "C:\Users\$env:UserName\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
  "$PSScriptRoot\windows-terminal\settings.json"
New-Symlink "C:\Users\$env:UserName\.vim" "$PSScriptRoot\vim"
New-Symlink "C:\Users\$env:UserName\vimfiles" "$PSScriptRoot\vim"
New-Symlink "C:\Users\$env:UserName\AppData\Local\nvim" "$PSScriptRoot\nvim"
New-Symlink "C:\Users\$env:UserName\AppData\Roaming\lf\lfrc" "$PSScriptRoot\lf\lfrc.ps1"
New-Symlink "C:\Users\$env:UserName\AppData\Roaming\lazygit\config.yml" "$PSScriptRoot\lazygit\config.yml"
New-Symlink "C:\Users\$env:UserName\.angular-config.json" "$PSScriptRoot\angular\angular-config.json"

# Create AutoHotKey shortcut in startup dir.
# Prefer the UIA-version for enabling UI access with apps run as admin.
Start-Phase 'AutoHotkey startup shortcut'
$shortcutPath = "C:\Users\$env:UserName\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\AutoHotKey.lnk"
$ahkExe = "C:\Program Files\AutoHotkey\AutoHotkeyU64_UIA.exe", "C:\Program Files\AutoHotkey\AutoHotkeyU64.exe" |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ahkExe)
{
  try
  {
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WscriptObj.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $ahkExe
    $shortcut.Arguments = "$PSScriptRoot\autohotkey\AutoHotKey.ahk"
    $shortcut.Save()
    Write-Result OK 'AutoHotKey.lnk' "starts $(Split-Path $ahkExe -Leaf)"
  } catch
  {
    Write-Result FAIL 'AutoHotKey.lnk' $_.Exception.Message
  }
} else
{
  Write-Result WARN 'AutoHotKey.lnk' "AutoHotkey v1 not found in 'C:\Program Files\AutoHotkey'; shortcut not created"
}

# Installing powershell modules
Start-Phase 'PowerShell modules'
$modules = 'PSReadLine', 'PSFzf', 'PoshColor', 'Microsoft.WinGet.Client'
foreach ($module in $modules)
{
  try
  {
    $before = Get-ModuleVersion $module
    if ($before)
    {
      Update-PSResource -Name $module -Repository PSGallery -Scope CurrentUser -TrustRepository
    } else
    {
      Install-PSResource -Name $module -Repository PSGallery -Scope CurrentUser -TrustRepository
    }
    $after = Get-ModuleVersion $module
    $detail = if (!$before) { "installed $after" } elseif ($after -gt $before) { "updated $before -> $after" } else { "up to date ($after)" }
    Write-Result OK $module $detail
  } catch
  {
    Write-Result FAIL $module $_.Exception.Message
  }
}

# Installing global npm packages
# packages.json is shared; packages.local.json (same format, git-ignored) holds work- and machine-specific packages.
Start-Phase 'npm global packages'
if (Get-Command npm -ErrorAction SilentlyContinue)
{
  foreach ($packageFile in "$PSScriptRoot\npm\packages.json", "$PSScriptRoot\npm\packages.local.json")
  {
    $fileName = Split-Path $packageFile -Leaf
    if (!(Test-Path $packageFile))
    {
      Write-Result SKIP $fileName 'file not found'
      continue
    }

    $packages = @((Get-Content -Raw $packageFile | ConvertFrom-Json).packages.name)
    if (!$packages)
    {
      Write-Result SKIP $fileName 'no packages configured'
      continue
    }

    try
    {
      $installedJson = npm list -g --depth=0 --json 2>$null | ConvertFrom-Json
      $installedNames = @($installedJson.dependencies.PSObject.Properties.Name)
    } catch
    {
      $installedNames = @()
    }

    $toInstall = @($packages | Where-Object { $_ -notin $installedNames })
    if ($toInstall.Count -eq 0)
    {
      Write-Result OK $fileName "all $($packages.Count) packages already installed"
    } else
    {
      Write-Host "    Installing $($toInstall.Count) of $($packages.Count) npm packages: $($toInstall -join ', ')..."
      npm install -g $toInstall --no-fund --no-audit
      if ($LASTEXITCODE -eq 0)
      {
        Write-Result OK $fileName "installed $($toInstall.Count) packages"
      } else
      {
        Write-Result WARN $fileName "npm install exited with code $LASTEXITCODE"
      }
    }
  }
} else
{
  Write-Result SKIP 'npm' 'npm CLI not found in PATH'
}

Write-Summary
if ($results.Status -contains 'FAIL')
{
  exit 1
}

# (Optional) Reset execution policy: Set-ExecutionPolicy Default
