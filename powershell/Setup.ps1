$phaseNames = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$statusColors = @{ OK = 'Green'; SKIP = 'DarkGray'; WARN = 'Yellow'; FAIL = 'Red' }

function New-SetupPhase([string] $Name, [scriptblock] $Action, [switch] $StopOnFail)
{
    [pscustomobject]@{ Name = $Name; Action = $Action; StopOnFail = [bool]$StopOnFail }
}

function Invoke-SetupPhase([string] $Title, [object[]] $Phase)
{
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($phaseDefinition in $Phase)
    {
        Start-Phase $phaseDefinition.Name $Phase.Count
        try
        {
            & $phaseDefinition.Action | Out-Host
        }
        catch
        {
            Write-Result WARN $phaseDefinition.Name $_.Exception.Message
        }

        $phaseFailed = @($results | Where-Object {
            $_.Phase -eq $phaseDefinition.Name -and $_.Status -eq 'FAIL'
        }).Count -gt 0
        if ($phaseDefinition.StopOnFail -and $phaseFailed)
        {
            break
        }
    }

    Write-Summary $Title $stopwatch.Elapsed
    return -not ($results.Status -contains 'FAIL')
}

function Start-Phase($Name, $Total)
{
    $phaseNames.Add($Name)
    Write-Host ""
    Write-Host ("==> [{0}/{1}] {2}" -f $phaseNames.Count, $Total, $Name) -ForegroundColor Cyan
}

function Write-Result($Status, $Item, $Detail, [switch]$Updated)
{
    $results.Add([pscustomobject]@{ Phase = $phaseNames[-1]; Status = $Status; Item = $Item; Detail = $Detail; Updated = [bool]$Updated })
    Write-Host ("    {0,-4}  " -f $Status) -ForegroundColor $statusColors[$Status] -NoNewline
    if ($Detail)
    {
        Write-Host "$Item " -NoNewline
        Write-Host "- $Detail" -ForegroundColor DarkGray
    }
    else
    {
        Write-Host $Item
    }
}

function Write-Summary([string] $Title, [timespan] $Elapsed)
{
    Write-Host ""
    Write-Host "==> Summary" -ForegroundColor Cyan
    foreach ($phaseName in $phaseNames)
    {
        $phaseResults = @($results | Where-Object Phase -eq $phaseName)
        $counts = foreach ($status in 'OK', 'SKIP', 'WARN', 'FAIL')
        {
            $count = @($phaseResults | Where-Object Status -eq $status).Count
            if ($count)
            {
                "$count $status"
            }
        }
        $worst = 'FAIL', 'WARN', 'OK', 'SKIP' | Where-Object { $_ -in $phaseResults.Status } | Select-Object -First 1
        Write-Host ("    {0,-30}" -f $phaseName) -NoNewline
        Write-Host ($counts -join ', ') -ForegroundColor $statusColors[$worst ?? 'SKIP']
    }

    $updates = @($results | Where-Object Updated)
    if ($updates)
    {
        Write-Host ""
        Write-Host "    Updated:"
        foreach ($update in $updates)
        {
            $detail = $update.Detail -replace '^updated\s+', ''
            Write-Host ("        [{0}] {1} {2}" -f $update.Phase, $update.Item, $detail)
        }
    }

    $issues = @($results | Where-Object Status -in 'WARN', 'FAIL')
    if ($issues)
    {
        Write-Host ""
        Write-Host "    Needs attention:"
        foreach ($issue in $issues)
        {
            Write-Host ("    {0,-4}  " -f $issue.Status) -ForegroundColor $statusColors[$issue.Status] -NoNewline
            Write-Host "[$( $issue.Phase )] $( $issue.Item ) - $( $issue.Detail )"
        }
    }

    $count = @{ }
    foreach ($status in 'OK', 'SKIP', 'WARN', 'FAIL')
    {
        $count[$status] = @($results | Where-Object Status -eq $status).Count
    }
    $result = if ($count.FAIL)
    {
        'FAILED'
    }
    elseif ($count.WARN)
    {
        'FINISHED WITH WARNINGS'
    }
    else
    {
        'SUCCEEDED'
    }
    Write-Host ""
    Write-Host (("{0} {1} in {2:mm\:ss} ({3} OK, {4} SKIP, {5} WARN, {6} FAIL)" -f
    $Title, $result, $Elapsed, $count.OK, $count.SKIP, $count.WARN, $count.FAIL)) `
    -ForegroundColor ($count.FAIL ? 'Red' : $count.WARN ? 'Yellow' : 'Green')
}

function Get-DisplayPath($Path)
{
    $Path -replace "^$([regex]::Escape($HOME) )", '~'
}

function Get-ModuleVersion($Name)
{
    Get-InstalledPSResource -Name $Name -Scope CurrentUser -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty Version
}

# script scope: read by the module phases in install.ps1 and UpdatePhases.ps1
$script:powerShellModules = 'PSReadLine', 'PSFzf', 'PoshColor', 'Microsoft.WinGet.Client'
