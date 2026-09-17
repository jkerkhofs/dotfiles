function New-Worktree {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [ValidateSet("feature", "bugfix")]
    [string]$Type,
    [Parameter(Position = 1)]
    [string]$Name,
    [Parameter(Position = 2)]
    [string]$User,
    [Parameter(Position = 3)]
    [string]$Base
  )

  # 1. Controleer of het huidige pad een Git repository is (Project-agnostisch)
  $gitRoot = (git rev-parse --show-toplevel 2>$null)
  if (-not $gitRoot) {
    Write-Error "Fout: Huidige map ($(Get-Location)) is geen Git-repository."
    return
  }

  # Bepaal project- en foldernamen dynamisch
  $projectName = Split-Path -Leaf $gitRoot
  $parentDir = Split-Path -Parent $gitRoot
  Write-Host "`n=== Git Worktree Creator ($projectName) ===" -ForegroundColor Cyan

  # 2. Vraag Type (Feature of Bugfix) indien niet opgegeven
  while (-not $Type) {
    Write-Host "Wat voor type branch wil je aanmaken?" -ForegroundColor Yellow
    Write-Host "  [1] feature (standaard)"
    Write-Host "  [2] bugfix"
    $choice = (Read-Host -Prompt "Keuze [1/2]").Trim()
    switch ($choice) {
      "2" { $Type = "bugfix" }
      "bugfix" { $Type = "bugfix" }
      default { $Type = "feature" }
    }
  }

  # 3. Bepaal developer identifier (bv. 'john')
  if (-not $User) {
    $defaultUser = (git config --get user.initials)
    if (-not $defaultUser) {
      $gitName = (git config --get user.name)
      if ($gitName) {
        $defaultUser = ($gitName -split " ")[0].ToLower()
      }
      else {
        $defaultUser = $env:USERNAME.ToLower()
      }
    }
    $userInput = (Read-Host -Prompt "Developer prefix / initialen (standaard: '$defaultUser')").Trim()
    $User = if ($userInput) { $userInput } else { $defaultUser }
  }

  # 4. Vraag Branch / Ticket naam (bv. mijn-nieuwe-feature)
  while (-not $Name) {
    $Name = (Read-Host -Prompt "Geef de naam/beschrijving van de branch (bv. mijn-nieuwe-feature)").Trim()
    if (-not $Name) {
      Write-Warning "Naam mag niet leeg zijn."
    }
  }

  # Stel de volledige branch- en doelmapnaam samen
  $branchName = "$Type/$User/$Name"
  $targetPath = Join-Path $parentDir "$projectName-$Name"

  # 5. Controleer of doelmap al bestaat
  if (Test-Path $targetPath) {
    Write-Error "Fout: De doelmap '$targetPath' bestaat al. Verwijder deze eerst of kies een andere naam."
    return
  }

  # 6. Fetch updates van remote
  Write-Host "`nOphalen laatste wijzigingen van remote..." -ForegroundColor Cyan
  git fetch origin 2>$null
  #
  # 7. Controleer of de branch al bestaat (lokaal of remote)
  git show-ref --verify --quiet "refs/heads/$branchName"
  $localExists = ($LASTEXITCODE -eq 0)
  git show-ref --verify --quiet "refs/remotes/origin/$branchName"
  $remoteExists = ($LASTEXITCODE -eq 0)
  $useExistingBranch = $false
  if ($localExists -or $remoteExists) {
    $locatie = if ($localExists -and $remoteExists) { "lokaal en op origin" } elseif ($localExists) { "lokaal" }
    else { "op origin" }
    Write-Host "`nBranch '$branchName' bestaat reeds ($locatie)." -ForegroundColor Yellow
    $useExistingAnswer = (Read-Host -Prompt "Wil je de bestaande branch gebruiken in de nieuwe worktree?
[J/n]").Trim().ToLower()
    if ($useExistingAnswer -eq "" -or $useExistingAnswer -eq "j" -or $useExistingAnswer -eq "ja" -or
      $useExistingAnswer -eq "y") {
      $useExistingBranch = $true
    }
    else {
      Write-Warning "Geannuleerd: kies een andere naam om conflicten te vermijden."
      return
    }
  }

  # 8. Bepaal Base branch indien het een nieuwe branch betreft
  if (-not $useExistingBranch -and -not $Base) {
    $defaultBase = "origin/main"
    $baseInput = (Read-Host -Prompt "Base commit/branch (standaard: '$defaultBase')").Trim()
    $Base = if ($baseInput) { $baseInput } else { $defaultBase }
  }

  # 9. Voer het git worktree add commando uit
  Write-Host "`nAanmaken worktree in: $targetPath" -ForegroundColor Cyan
  if ($useExistingBranch) {
    if ($localExists) {
      git worktree add $targetPath $branchName
    }
    else {
      git worktree add --track -b $branchName $targetPath "origin/$branchName"
    }
  }
  else {
    git worktree add -b $branchName $targetPath $Base
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Aanmaken van worktree is mislukt."
    return
  }

  # 10. Submodules detecteren en initialiseren indien aanwezig in het project
  $submodulesConfig = Join-Path $targetPath ".gitmodules"
  if (Test-Path $submodulesConfig) {
    Write-Host "`n.gitmodules gedetecteerd. Initialiseren van submodules..." -ForegroundColor Cyan
    git -C $targetPath submodule update --init --recursive
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Submodules succesvol geïnitialiseerd." -ForegroundColor Green
    }
    else {
      Write-Warning "Submodules konden niet volledig worden geïnitialiseerd."
    }
  }
  Write-Host "`nSucces: Worktree gereed in $targetPath (Branch: $branchName)" -ForegroundColor Green

  # 11. Optie om direct te navigeren naar de nieuwe werkmap
  $navAnswer = (Read-Host -Prompt "`nWil je direct overschakelen naar de nieuwe werkmap? [J/n]").Trim().ToLower()
  if ($navAnswer -eq "" -or $navAnswer -eq "j" -or $navAnswer -eq "ja" -or $navAnswer -eq "y") {
    Set-Location $targetPath
  }
}
