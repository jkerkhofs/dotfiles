<#
.SYNOPSIS
  Schakelt over naar een andere Git worktree, navigeert naar de doelmap en past IIS aan.

.DESCRIPTION
  Switch-Worktree detecteert alle geregistreerde worktrees binnen het huidige Git-project
  (inclusief de main repository). Na selectie navigeert de functie naar de doelmap en
  werkt optioneel de IIS physicalPath instellingen en gekoppelde Application Pools bij.
  Ondersteunt -WhatIf en -Confirm via CmdletBinding(SupportsShouldProcess = $true).

.PARAMETER Target
  Optionele naam, branch, mapnaam of trefwoord van de gewenste worktree (bijv. 'main', '12345').
  Accepteert invoer via de pipeline en ondersteunt aliassen 'Path' en 'Name'.
  Indien weggelaten toont de functie een interactief keuzemenu.

.PARAMETER SkipIIS
  Indien opgegeven wordt alleen naar de doelmap genavigeerd zonder IIS aan te passen.
  Ondersteunt alias 'NoIIS'.

.PARAMETER PassThru
  Indien opgegeven wordt het fysieke pad naar de doel-worktree geretourneerd als string.

.OUTPUTS
  [System.String]
  Wanneer -PassThru is opgegeven, retourneert de functie het absolute pad naar de doel-worktree.

  [void]
  Wanneer -PassThru niet is opgegeven, navigeert de functie en toont statusinformatie.

.EXAMPLE
  Switch-Worktree
  Toont een genummerde lijst van alle worktrees van het project om interactief te kiezen.

.EXAMPLE
  switch-wt main
  Navigeert direct terug naar de hoofdrepository en schakelt IIS terug naar main.

.EXAMPLE
  switch-wt 12345 -SkipIIS
  Navigeert naar de worktree met '12345' in de naam zonder IIS aan te passen.

.EXAMPLE
  switch-wt feature-123 -WhatIf
  Toont de overschakelingsactie zonder daadwerkelijk van map of IIS-configuratie te wisselen.

.NOTES
  Ondersteunde aliassen: switch-wt, sw-wt
#>
function Switch-Worktree {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Path", "Name")]
    [string]$Target,

    [Parameter()]
    [Alias("NoIIS")]
    [switch]$SkipIIS,

    [Parameter()]
    [switch]$PassThru
  )

  process {
    # 1. Controleer Git-repository en bepaal projectcontext
    $revParseOutput = git --no-optional-locks rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>$null
    if (-not $revParseOutput) {
      Write-Error "Fout: Huidige map ($(Get-Location)) bevindt zich niet in een Git-repository of worktree."
      return
    }
    if ($revParseOutput -is [array] -and $revParseOutput.Count -ge 2) {
      $currentRootRaw = $revParseOutput[0]
      $gitCommonDirRaw = $revParseOutput[1]
    }
    else {
      $currentRootRaw = $revParseOutput
      $gitCommonDirRaw = (git --no-optional-locks -C $currentRootRaw rev-parse --path-format=absolute --git-common-dir 2>$null)
    }
    $currentRoot = (Resolve-Path -Path $currentRootRaw).Path

    if (-not [System.IO.Path]::IsPathRooted($gitCommonDirRaw)) {
      $gitCommonDirRaw = Join-Path $currentRoot $gitCommonDirRaw
    }
    $gitCommonDir = (Resolve-Path -Path $gitCommonDirRaw).Path
    $mainRepoRoot = Split-Path -Parent $gitCommonDir
    $projectName = Split-Path -Leaf $mainRepoRoot

    # 2. Haal alle geregistreerde worktrees op via 'git worktree list --porcelain'
    $worktrees = @()
    $rawList = git --no-optional-locks worktree list --porcelain 2>$null
    $wtEntry = [ordered]@{}
    foreach ($line in $rawList) {
      if ($line -match '^worktree (.+)$') {
        if ($wtEntry.Path) { $worktrees += [PSCustomObject]$wtEntry }
        $resolvedWtPath = $null
        try { $resolvedWtPath = [System.IO.Path]::GetFullPath($matches[1]) } catch { $resolvedWtPath = $matches[1] }
        $wtEntry = [ordered]@{ Path = $resolvedWtPath; Branch = ''; IsMain = $false }
      }
      elseif ($line -match '^branch refs/heads/(.+)$') {
        $wtEntry.Branch = $matches[1]
      }
    }
    if ($wtEntry.Path) { $worktrees += [PSCustomObject]$wtEntry }

    if ($worktrees.Count -gt 0) {
      # De eerste worktree in de lijst is altijd de hoofdrepository
      $worktrees[0].IsMain = $true
    }

    if ($worktrees.Count -eq 0) {
      Write-Error "Fout: Geen geregistreerde worktrees gevonden voor $projectName."
      return
    }

    # Bepaal de actieve IIS worktree voor visualisatie (eerst snel via centrale metadata)
    $activeIisPath = $null
    $stateFile = Join-Path $gitCommonDir "iis-worktree.json"
    if (Test-Path -LiteralPath $stateFile) {
      try { $activeIisPath = (Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json).activeWorktree } catch { }
    }
    if (-not $activeIisPath -and (Get-Command Get-WorktreeIIS -ErrorAction SilentlyContinue)) {
      $activeIisPath = Get-WorktreeIIS -Path $currentRoot -PassThru
    }
    if (-not $activeIisPath) { $activeIisPath = $mainRepoRoot }

    # 3. Bepaal de doel-worktree (interactief of via parameter)
    $selectedWt = $null

    if ($Target) {
      # Controleer of Target expliciet verwijst naar main, master of projectnaam
      if ($Target -in @('main', 'master', $projectName)) {
        $selectedWt = $worktrees | Where-Object { $_.IsMain } | Select-Object -First 1
      }
      else {
        $selectedWt = $worktrees | Where-Object {
          $_.Path -eq $Target -or
          (Split-Path -Leaf $_.Path) -eq $Target -or
          $_.Branch -eq $Target -or
          (Split-Path -Leaf $_.Path) -like "*$Target*" -or
          $_.Branch -like "*$Target*"
        } | Select-Object -First 1
      }

      if (-not $selectedWt) {
        Write-Error "Fout: Geen actieve worktree gevonden die overeenkomt met '$Target'."
        return
      }
    }
    else {
      # Interactieve keuzelijst tonen
      Write-Host "`n=== Git Worktree Switch ($projectName) ===" -ForegroundColor Cyan
      if ($activeIisPath) {
        $iisFolder = Split-Path -Leaf $activeIisPath
        $iisType = if ($activeIisPath.TrimEnd('\', '/') -eq $mainRepoRoot.TrimEnd('\', '/')) { "Main" } else { "Feature" }
        Write-Host "IIS actieve worktree: $iisFolder ($iisType)" -ForegroundColor Magenta
      }
      Write-Host "Selecteer de worktree waarnaar je wilt overschakelen:" -ForegroundColor Yellow

      for ($i = 0; $i -lt $worktrees.Count; $i++) {
        $wt = $worktrees[$i]
        $folderName = Split-Path -Leaf $wt.Path
        $branchInfo = if ($wt.Branch) { "(Branch: $($wt.Branch))" } else { "(Detached HEAD)" }
        $isCurrent = ($wt.Path.TrimEnd('\', '/') -eq $currentRoot.TrimEnd('\', '/'))
        $isIis = ($activeIisPath -and ($wt.Path.TrimEnd('\', '/') -eq $activeIisPath.TrimEnd('\', '/')))
        $currentTag = if ($isCurrent) { " [Huidig]" } else { "" }
        $iisTag = if ($isIis) { " [IIS]" } else { "" }
        $mainTag = if ($wt.IsMain) { " [Main]" } else { "" }
        Write-Host "  [$($i + 1)] $folderName $branchInfo$mainTag$iisTag$currentTag"
      }

      while (-not $selectedWt) {
        $selection = (Read-Host -Prompt "Keuze [1-$($worktrees.Count)] of 'q' om te annuleren").Trim()
        if ($selection -eq 'q' -or $selection -eq 'exit') {
          Write-Host "Geannuleerd." -ForegroundColor Gray
          return
        }
        $index = $selection -as [int]
        if ($index -ge 1 -and $index -le $worktrees.Count) {
          $selectedWt = $worktrees[$index - 1]
        }
        else {
          Write-Warning "Ongeldige keuze, probeer opnieuw."
        }
      }
    }

    $targetPath = $selectedWt.Path
    $targetBranch = $selectedWt.Branch

    # Controleer ShouldProcess voor -WhatIf en -Confirm ondersteuning
    if (-not $PSCmdlet.ShouldProcess($targetPath, "Overschakelen naar worktree (Branch: $targetBranch)")) {
      if ($PassThru) { return $targetPath }
      return
    }

    # 4. Navigeer naar de gekozen worktree
    if ($targetPath.TrimEnd('\', '/') -eq $currentRoot.TrimEnd('\', '/')) {
      Write-Host "`nJe bevindt je al in $targetPath." -ForegroundColor Gray
    }
    else {
      Write-Host "`nNavigeren naar: $targetPath" -ForegroundColor Green
      if ($targetBranch) {
        Write-Host "Branch: $targetBranch" -ForegroundColor Cyan
      }
      Set-Location $targetPath
    }

    # 5. Schakel IIS om naar de doel-worktree (tenzij -SkipIIS is meegegeven)
    if (-not $SkipIIS) {
      if (Get-Command Switch-WorktreeIIS -ErrorAction SilentlyContinue) {
        Switch-WorktreeIIS -Path $targetPath
      }
      else {
        Write-Warning "Functie 'Switch-WorktreeIIS' is niet beschikbaar om IIS om te schakelen."
      }
    }

    if ($PassThru) {
      return $targetPath
    }
  }
}

# Aliases voor snel typen
Set-Alias -Name switch-wt -Value Switch-Worktree
Set-Alias -Name sw-wt     -Value Switch-Worktree
