# Enable script execution by setting the execution policy: Set-ExecutionPolicy RemoteSigned
# Run with PowerShell 7.4+ (pwsh) as administrator, or enable Developer Mode to allow creating symlinks.
#Requires -Version 7.4

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
. "$repoRoot\powershell\Setup.ps1"
. "$repoRoot\powershell\Updates.ps1"
. "$repoRoot\powershell\UpdatePhases.ps1"

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
    }
    catch
    {
        $null
    }
    finally
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
            $backup = "$Path.bak-$( Get-Date -Format 'yyyyMMddHHmmss' )"
            Move-Item -LiteralPath $Path -Destination $backup
            $status, $detail = 'WARN', "linked; existing $( $item.PSIsContainer ? 'directory' : 'file' ) moved to '$( Get-DisplayPath $backup )'"
        }
        elseif ($item)
        {
            $detail = "relinked (was '$( $item.LinkTarget )')"
        }
        New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
        Write-Result $status $displayPath $detail
    }
    catch
    {
        Write-Result FAIL $displayPath $_.Exception.Message
    }
}

Write-Host "Installing dotfiles from '$repoRoot'" -ForegroundColor Cyan

# Checking prerequisites
$installPhases = @(
    New-SetupPhase 'Prerequisites' {
        Write-Result OK 'PowerShell' $PSVersionTable.PSVersion
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $isDevMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
        if ($isAdmin -or $isDevMode)
        {
            Write-Result OK 'Symlink permission' ($isAdmin ? 'running as administrator' : 'Developer Mode enabled')
        }
        else
        {
            Write-Result FAIL 'Symlink permission' 'run this script as administrator or enable Developer Mode'
        }
        if (Get-Command winget -ErrorAction SilentlyContinue)
        {
            Write-Result OK 'winget' (winget --version)
        }
        else
        {
            Write-Result FAIL 'winget' "not found; install 'App Installer' from the Microsoft Store first"
        }
    } -StopOnFail

# Installing winget packages
# packages.json is shared; packages.local.json (same format, git-ignored) holds work- and machine-specific packages.
    New-SetupPhase 'winget packages' {
        foreach ($packageFile in "$repoRoot\winget\packages.json", "$repoRoot\winget\packages.local.json")
        {
            $fileName = Split-Path $packageFile -Leaf
            if (!(Test-Path $packageFile))
            {
                Write-Result SKIP $fileName 'file not found'
                continue
            }

            $ids = @((Get-Content -Raw $packageFile | ConvertFrom-Json).Sources.Packages.PackageIdentifier)
            Write-Host "    Checking $( $ids.Count ) packages from $fileName..."
            $before = Get-WinGetInstalledIds
            $toInstall = if ($null -ne $before)
            {
                @($ids | Where-Object { $_ -notin $before })
            }
            else
            {
                $ids
            }
            if (!$toInstall)
            {
                Write-Result OK $fileName "all $( $ids.Count ) packages already installed"
                continue
            }

            Write-Host "    Installing $( $toInstall.Count ) of $( $ids.Count ) packages: $( $toInstall -join ', ' )"
            winget import --import-file $packageFile --accept-package-agreements --accept-source-agreements --no-upgrade
            $exitCode = $LASTEXITCODE
            $after = Get-WinGetInstalledIds
            if ($null -ne $before -and $null -ne $after)
            {
                $missing = @($ids | Where-Object { $_ -notin $after })
                $detail = "{0} installed, {1} already installed" -f ($toInstall.Count - $missing.Count), ($ids.Count - $toInstall.Count)
                if ($missing)
                {
                    Write-Result FAIL $fileName "$detail, $( $missing.Count ) not installed: $( $missing -join ', ' )"
                }
                else
                {
                    Write-Result OK $fileName $detail
                }
            }
            elseif ($exitCode -eq 0)
            {
                Write-Result OK $fileName 'winget import succeeded'
            }
            else
            {
                Write-Result WARN $fileName ("winget import exited with 0x{0:X8}; one or more packages may not be installed (see output above)" -f $exitCode)
            }
        }
    }

# Keep AutoHotkey on v1 (the script in autohotkey\ uses v1 syntax)
    New-SetupPhase 'AutoHotkey version pin' {
        winget pin add --id AutoHotkey.AutoHotkey --exact --version '1.1.*' --force --accept-source-agreements --source winget | Out-Null
        if ($LASTEXITCODE -eq 0)
        {
            Write-Result OK 'AutoHotkey.AutoHotkey' 'pinned to 1.1.*'
        }
        else
        {
            Write-Result WARN 'AutoHotkey.AutoHotkey' ("pinning to 1.1.* failed with exit code 0x{0:X8}" -f $LASTEXITCODE)
        }
    }

# Creating symlinks
    New-SetupPhase 'Symlinks' {
        New-Symlink "C:\Users\$env:UserName\Documents\PowerShell\Profile.ps1" "$repoRoot\powershell\Profile.ps1"
        New-Symlink "C:\Users\$env:UserName\AppData\Roaming\Code\User\settings.json" "$repoRoot\vscode\settings.json"
        New-Symlink "C:\Users\$env:UserName\AppData\Roaming\Code\User\keybindings.json" "$repoRoot\vscode\keybindings.json"
        New-Symlink "C:\Users\$env:UserName\_vsvimrc" "$repoRoot\vsvim\_vsvimrc"
        New-Symlink "C:\Users\$env:UserName\.ideavimrc" "$repoRoot\ideavim\ideavimrc"
        New-Symlink "C:\Users\$env:UserName\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" "$repoRoot\windows-terminal\settings.json"
        New-Symlink "C:\Users\$env:UserName\.vim" "$repoRoot\vim"
        New-Symlink "C:\Users\$env:UserName\vimfiles" "$repoRoot\vim"
        New-Symlink "C:\Users\$env:UserName\AppData\Local\nvim" "$repoRoot\nvim"
        New-Symlink "C:\Users\$env:UserName\AppData\Roaming\lf\lfrc" "$repoRoot\lf\lfrc.ps1"
        New-Symlink "C:\Users\$env:UserName\AppData\Roaming\lazygit\config.yml" "$repoRoot\lazygit\config.yml"
        New-Symlink "C:\Users\$env:UserName\.angular-config.json" "$repoRoot\angular\angular-config.json"
    }

# Create AutoHotKey shortcut in startup dir.
# Prefer the UIA-version for enabling UI access with apps run as admin.
    New-SetupPhase 'AutoHotkey startup shortcut' {
        $shortcutPath = "C:\Users\$env:UserName\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\AutoHotKey.lnk"
        $ahkExe = "C:\Program Files\AutoHotkey\AutoHotkeyU64_UIA.exe", "C:\Program Files\AutoHotkey\AutoHotkeyU64.exe" | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($ahkExe)
        {
            try
            {
                $WScriptObj = New-Object -ComObject ("WScript.Shell")
                $shortcut = $WscriptObj.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $ahkExe
                $shortcut.Arguments = "$repoRoot\autohotkey\AutoHotKey.ahk"
                $shortcut.Save()
                Write-Result OK 'AutoHotKey.lnk' "starts $( Split-Path $ahkExe -Leaf )"
            }
            catch
            {
                Write-Result FAIL 'AutoHotKey.lnk' $_.Exception.Message
            }
        }
        else
        {
            Write-Result WARN 'AutoHotKey.lnk' "AutoHotkey v1 not found in 'C:\Program Files\AutoHotkey'; shortcut not created"
        }
    }

# Installing powershell modules
    New-SetupPhase 'PowerShell modules' {
        foreach ($module in $powerShellModules)
        {
            try
            {
                $version = Get-ModuleVersion $module
                if ($version)
                {
                    Write-Result OK $module "already installed ($version)"
                }
                else
                {
                    Install-PSResource -Name $module -Repository PSGallery -Scope CurrentUser -TrustRepository
                    $version = Get-ModuleVersion $module
                    if (!$version)
                    {
                        throw 'installation completed, but no installed version was found'
                    }
                    Write-Result OK $module "installed $version"
                }
            }
            catch
            {
                Write-Result FAIL $module $_.Exception.Message
            }
        }
    }

# Installing global npm packages
# packages.json is shared; packages.local.json (same format, git-ignored) holds work- and machine-specific packages.
    New-SetupPhase 'npm global packages' {
        if (Get-Command npm -ErrorAction SilentlyContinue)
        {
            foreach ($packageFile in "$repoRoot\npm\packages.json", "$repoRoot\npm\packages.local.json")
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
                    $installedJson = npm list -g --depth=0 --json 2> $null | ConvertFrom-Json
                    $installedNames = @($installedJson.dependencies.PSObject.Properties.Name)
                }
                catch
                {
                    $installedNames = @()
                }

                $toInstall = @($packages | Where-Object { $_ -notin $installedNames })
                if ($toInstall.Count -eq 0)
                {
                    Write-Result OK $fileName "all $( $packages.Count ) packages already installed"
                }
                else
                {
                    Write-Host "    Installing $( $toInstall.Count ) of $( $packages.Count ) npm packages: $( $toInstall -join ', ' )..."
                    npm install -g $toInstall --no-fund --no-audit
                    if ($LASTEXITCODE -eq 0)
                    {
                        Write-Result OK $fileName "installed $( $toInstall.Count ) packages"
                    }
                    else
                    {
                        Write-Result WARN $fileName "npm install exited with code $LASTEXITCODE"
                    }
                }
            }
        }
        else
        {
            Write-Result SKIP 'npm' 'npm CLI not found in PATH'
        }
    }

# Installing global dotnet tools
# tools.json is shared; tools.local.json (same format, git-ignored) holds work- and machine-specific tools.
# Updating the tools is done by :UpdateAll in Neovim.
    New-SetupPhase 'dotnet global tools' {
        if (Get-Command dotnet -ErrorAction SilentlyContinue)
        {
            foreach ($toolFile in "$repoRoot\dotnet\tools.json", "$repoRoot\dotnet\tools.local.json")
            {
                $fileName = Split-Path $toolFile -Leaf
                if (!(Test-Path $toolFile))
                {
                    Write-Result SKIP $fileName 'file not found'
                    continue
                }

                $tools = @((Get-Content -Raw $toolFile | ConvertFrom-Json).tools.name)
                if (!$tools)
                {
                    Write-Result SKIP $fileName 'no tools configured'
                    continue
                }

                # the first two lines of 'dotnet tool list' are the table header, the first column is the package id
                $installedIds = @(dotnet tool list -g 2> $null | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] })
                $toInstall = @($tools | Where-Object { $_ -notin $installedIds })
                if ($toInstall.Count -eq 0)
                {
                    Write-Result OK $fileName "all $( $tools.Count ) tools already installed"
                    continue
                }

                Write-Host "    Installing $( $toInstall.Count ) of $( $tools.Count ) dotnet tools: $( $toInstall -join ', ' )..."
                $failedTools = @()
                foreach ($tool in $toInstall)
                {
                    dotnet tool install -g $tool
                    if ($LASTEXITCODE -ne 0)
                    {
                        $failedTools += $tool
                    }
                }
                if ($failedTools.Count -eq 0)
                {
                    Write-Result OK $fileName "installed $( $toInstall.Count ) tools"
                }
                else
                {
                    Write-Result WARN $fileName "dotnet tool install failed for: $( $failedTools -join ', ' )"
                }
            }
        }
        else
        {
            Write-Result SKIP 'dotnet' 'dotnet CLI not found in PATH'
        }
    }

)
if (!(Invoke-SetupPhase 'Install' ($installPhases + $updatePhases)))
{
    exit 1
}

# (Optional) Reset execution policy: Set-ExecutionPolicy Default
