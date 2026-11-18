function Assert-UpdateCommand($Name)
{
    if (!(Get-Command $Name -ErrorAction SilentlyContinue))
    {
        throw "$Name CLI not found in PATH"
    }
}

function Get-WinGetUpdateCandidate
{
    param([string] $IgnoreFile)

    if (!(Get-Module -ListAvailable Microsoft.WinGet.Client))
    {
        throw "Microsoft.WinGet.Client not installed (run install.ps1 or Install-PSResource Microsoft.WinGet.Client)"
    }
    Import-Module Microsoft.WinGet.Client -ErrorAction Stop

    $ignoredIds = @()
    if ($IgnoreFile -and (Test-Path -LiteralPath $IgnoreFile))
    {
        try
        {
            $ignoredIds = @((Get-Content -Raw -LiteralPath $IgnoreFile | ConvertFrom-Json -ErrorAction Stop).id | Where-Object { $_ })
        }
        catch
        {
            Write-Host -ForegroundColor Yellow "Could not read $IgnoreFile, nothing is ignored: $( $_.Exception.Message )"
        }
    }

    $updatable = @(Get-WinGetPackage -ErrorAction Stop | Where-Object IsUpdateAvailable)
    $ignored = @($updatable | Where-Object { $_.Id -in $ignoredIds })
    if ($ignored)
    {
        Write-Host -ForegroundColor DarkGray "Ignored: $( $ignored.Id -join ', ' )"
    }

    foreach ($package in $updatable | Where-Object { $_.Id -notin $ignoredIds } | Sort-Object Name)
    {
        $availableVersion = $package.AvailableVersions | Select-Object -First 1
        if ($availableVersion -eq 'Unknown')
        {
            $availableVersion = ''
        }
        [pscustomobject]@{
            Id = [string]$package.Id
            Name = [string]$package.Name
            'From' = [string]$package.InstalledVersion
            To = [string]$availableVersion
        }
    }
}

function Get-NpmUpdateCandidate
{
    Assert-UpdateCommand npm

    $output = npm outdated -g --json 2> $null | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -notin 0, 1)
    {
        throw "npm outdated exited with code $exitCode"
    }
    if ( [string]::IsNullOrWhiteSpace($output))
    {
        return @()
    }

    try
    {
        $packages = ConvertFrom-Json -InputObject $output -AsHashtable -ErrorAction Stop
    }
    catch
    {
        throw "Could not parse npm outdated output: $( $_.Exception.Message )"
    }
    if ($packages -isnot [System.Collections.IDictionary])
    {
        throw 'npm outdated returned an unexpected JSON structure'
    }

    foreach ($name in $packages.Keys | Sort-Object)
    {
        $package = $packages[$name]
        if (!$package.latest)
        {
            continue
        }
        [pscustomobject]@{
            Id = [string]$name
            Name = [string]$name
            'From' = [string]$package.current
            To = [string]$package.latest
        }
    }
}

function Select-UpdateCandidate
{
    param(
        [object[]] $Candidate,
        [string] $Header = 'ctrl-space: toggle | ctrl-t: toggle all | del: deselect all | enter: update'
    )

    $candidates = @($Candidate)
    if (!$candidates)
    {
        return @()
    }
    Assert-UpdateCommand fzf

    $nameWidth = ($candidates.Name | Measure-Object Length -Maximum).Maximum
    $idWidth = ($candidates.Id | Measure-Object Length -Maximum).Maximum
    $lines = foreach ($candidate in $candidates)
    {
        "{0}`t{1} {2} {3} -> {4}" -f $candidate.Id,
        ([string]$candidate.Name).PadRight($nameWidth),
        ([string]$candidate.Id).PadRight($idWidth), $candidate.From, $candidate.To
    }

    $selectedLines = @($lines | fzf --multi --delimiter "`t" --with-nth 2.. --header $Header)
    if ($LASTEXITCODE -ne 0 -or !$selectedLines)
    {
        return @()
    }
    $selectedIds = @($selectedLines | ForEach-Object { ($_ -split "`t", 2)[0] })
    @($candidates | Where-Object { $_.Id -in $selectedIds })
}

function Update-WinGetCandidate
{
    param([object[]] $Candidate)

    foreach ($candidate in $Candidate)
    {
        Write-Host -ForegroundColor Blue "Updating $( $candidate.Id )..."
        try
        {
            $operation = Update-WinGetPackage -Id $candidate.Id -MatchOption Equals -Mode Silent -ErrorAction Stop
            $rebootRequired = [bool]$operation.RebootRequired
            if ("$( $operation.Status )" -in 'Ok', 'Success', '0')
            {
                $detail = "updated $( $candidate.From ) -> $( $candidate.To )"
                if ($rebootRequired)
                {
                    $detail += '; reboot required'
                }
                [pscustomobject]@{
                    Id = $candidate.Id
                    Name = $candidate.Name
                    'From' = $candidate.From
                    To = $candidate.To
                    Status = 'Updated'
                    Detail = $detail
                    RebootRequired = $rebootRequired
                }
            }
            else
            {
                [pscustomobject]@{
                    Id = $candidate.Id
                    Name = $candidate.Name
                    'From' = $candidate.From
                    To = $candidate.To
                    Status = 'Failed'
                    Detail = "update returned status '$( $operation.Status )'"
                    RebootRequired = $rebootRequired
                }
            }
        }
        catch
        {
            [pscustomobject]@{
                Id = $candidate.Id
                Name = $candidate.Name
                'From' = $candidate.From
                To = $candidate.To
                Status = 'Failed'
                Detail = $_.Exception.Message
                RebootRequired = $null
            }
        }
    }
}

function Update-NpmCandidate
{
    param([object[]] $Candidate)

    Assert-UpdateCommand npm
    foreach ($candidate in $Candidate)
    {
        $specification = "$( $candidate.Id )@$( $candidate.To )"
        Write-Host -ForegroundColor Blue "Updating $specification..."
        try
        {
            # show npm's output instead of returning it as part of the results
            npm install -g $specification --no-fund --no-audit | Out-Host
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0)
            {
                [pscustomobject]@{
                    Id = $candidate.Id
                    Name = $candidate.Name
                    'From' = $candidate.From
                    To = $candidate.To
                    Status = 'Updated'
                    Detail = "updated $( $candidate.From ) -> $( $candidate.To )"
                }
            }
            else
            {
                [pscustomobject]@{
                    Id = $candidate.Id
                    Name = $candidate.Name
                    'From' = $candidate.From
                    To = $candidate.To
                    Status = 'Failed'
                    Detail = "npm install exited with code $exitCode"
                }
            }
        }
        catch
        {
            [pscustomobject]@{
                Id = $candidate.Id
                Name = $candidate.Name
                'From' = $candidate.From
                To = $candidate.To
                Status = 'Failed'
                Detail = $_.Exception.Message
            }
        }
    }
}

function Get-LazyLock
{
    param([string] $Path)

    if (!(Test-Path -LiteralPath $Path))
    {
        throw "lazy-lock file not found: $Path"
    }
    $lock = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    $commits = @{ }
    foreach ($name in $lock.Keys)
    {
        $commits[$name] = [string]$lock[$name].commit
    }
    $commits
}

function Invoke-NeovimUpdate
{
    param([string] $RepoRoot)

    Assert-UpdateCommand nvim
    $lockFile = Join-Path $RepoRoot 'nvim\lazy-lock.json'
    $before = Get-LazyLock $lockFile
    # show the progress instead of returning it as part of the result
    nvim --headless --cmd 'let g:prosession_on_startup=0' '+UpdateAll' '+qa!' | Out-Host
    $exitCode = $LASTEXITCODE
    $after = Get-LazyLock $lockFile

    $changes = foreach ($name in @($before.Keys + $after.Keys | Sort-Object -Unique))
    {
        $oldCommit = $before[$name]
        $newCommit = $after[$name]
        if (!$oldCommit)
        {
            $shortCommit = $newCommit.Substring(0,[Math]::Min(7, $newCommit.Length))
            [pscustomobject]@{
                Id = $name; Name = $name; 'From' = 'added'; To = $shortCommit; Status = 'Added'; Detail = "added $shortCommit"
            }
        }
        elseif (!$newCommit)
        {
            $shortCommit = $oldCommit.Substring(0,[Math]::Min(7, $oldCommit.Length))
            [pscustomobject]@{
                Id = $name; Name = $name; 'From' = $shortCommit; To = 'removed'; Status = 'Removed'; Detail = "removed $shortCommit"
            }
        }
        elseif ($oldCommit -ne $newCommit)
        {
            $from = $oldCommit.Substring(0,[Math]::Min(7, $oldCommit.Length))
            $to = $newCommit.Substring(0,[Math]::Min(7, $newCommit.Length))
            [pscustomobject]@{
                Id = $name; Name = $name; 'From' = $from; To = $to; Status = 'Updated'; Detail = "updated $from -> $to"
            }
        }
    }

    [pscustomobject]@{ ExitCode = $exitCode; Changes = @($changes) }
}

function Read-YesNo
{
    param([string] $Question)

    try
    {
        if ([Console]::IsInputRedirected)
        {
            return $false
        }
    }
    catch
    {
        return $false
    }

    Write-Host "$Question [Y/n] " -NoNewline
    (Read-Host) -notmatch '^(?i:n)$'
}
