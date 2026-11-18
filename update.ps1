#Requires -Version 7.4
param([switch] $FromProfile)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
. "$repoRoot\powershell\Setup.ps1"
. "$repoRoot\powershell\Updates.ps1"
. "$repoRoot\powershell\UpdatePhases.ps1"

Write-Host "Updating dotfiles tooling from '$repoRoot'" -ForegroundColor Cyan
$success = Invoke-SetupPhase 'Update' $updatePhases
if ($FromProfile)
{
    $global:LASTEXITCODE = $success ? 0 : 1
}
elseif (!$success)
{
    exit 1
}
