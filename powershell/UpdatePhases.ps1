# script scope: run by install.ps1 and update.ps1
$script:updatePhases = @(
    New-SetupPhase 'PowerShell module updates' {
        foreach ($module in $powerShellModules)
        {
            try
            {
                $before = Get-ModuleVersion $module
                if (!$before)
                {
                    Write-Result WARN $module 'not installed (run install.ps1)'
                    continue
                }

                Update-PSResource -Name $module -Repository PSGallery -Scope CurrentUser -TrustRepository
                $after = Get-ModuleVersion $module
                if ($after -gt $before)
                {
                    Write-Result OK $module "updated $before -> $after" -Updated
                }
                else
                {
                    Write-Result OK $module "up to date ($after)"
                }
            }
            catch
            {
                Write-Result FAIL $module $_.Exception.Message
            }
        }
    }
    New-SetupPhase 'winget updates' {
        if (!(Read-YesNo 'Update winget packages?'))
        {
            Write-Result SKIP 'winget packages' 'skipped'
        }
        else
        {
            $ignoreFile = Join-Path $repoRoot 'winget\wup-ignore.local.json'
            $candidates = @(Get-WinGetUpdateCandidate -IgnoreFile $ignoreFile)
            if (!$candidates)
            {
                Write-Result OK 'winget packages' 'everything up to date'
            }
            else
            {
                $selected = @(Select-UpdateCandidate $candidates)
                if (!$selected)
                {
                    Write-Result SKIP 'winget packages' 'nothing selected'
                }
                else
                {
                    foreach ($update in Update-WinGetCandidate $selected)
                    {
                        if ($update.Status -eq 'Updated')
                        {
                            Write-Result OK $update.Id $update.Detail -Updated
                        }
                        else
                        {
                            Write-Result FAIL $update.Id $update.Detail
                        }
                    }
                }
            }
        }
    }
    New-SetupPhase 'Neovim update' {
        if (!(Read-YesNo 'Update Neovim plugins and tooling? Close Neovim first'))
        {
            Write-Result SKIP 'UpdateAll' 'skipped'
        }
        else
        {
            $update = Invoke-NeovimUpdate $repoRoot
            foreach ($change in $update.Changes)
            {
                Write-Result OK $change.Name $change.Detail -Updated
            }
            if ($update.ExitCode -ne 0)
            {
                Write-Result FAIL 'UpdateAll' 'finished with errors (see output above)'
            }
            elseif (!$update.Changes)
            {
                Write-Result OK 'UpdateAll' 'everything up to date'
            }
        }
    }
    New-SetupPhase 'npm updates' {
        if (!(Read-YesNo 'Update global npm packages?'))
        {
            Write-Result SKIP 'npm packages' 'skipped'
        }
        else
        {
            $candidates = @(Get-NpmUpdateCandidate)
            if (!$candidates)
            {
                Write-Result OK 'npm packages' 'everything up to date'
            }
            else
            {
                $selected = @(Select-UpdateCandidate $candidates)
                if (!$selected)
                {
                    Write-Result SKIP 'npm packages' 'nothing selected'
                }
                else
                {
                    foreach ($update in Update-NpmCandidate $selected)
                    {
                        if ($update.Status -eq 'Updated')
                        {
                            Write-Result OK $update.Id $update.Detail -Updated
                        }
                        else
                        {
                            Write-Result FAIL $update.Id $update.Detail
                        }
                    }
                }
            }
        }
    }
)
