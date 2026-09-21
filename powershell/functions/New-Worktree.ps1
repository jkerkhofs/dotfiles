<#
.SYNOPSIS
  Maakt een nieuwe Git worktree en feature/bugfix branch aan met automatische configuratie.

.DESCRIPTION
  New-Worktree biedt een gestandaardiseerde en project-agnostische manier om een nieuwe
  Git worktree op te zetten voor parallelle ontwikkeling. De functie:
  - Vraagt interactief (of accepteert via parameters) branchtype, developer prefix en feature naam.
  - Maakt een worktree aan buiten de hoofdrepository met de juiste upstream tracking branch.
  - Initialiseert automatisch eventuele Git submodules (.gitmodules).
  - Kopieert lokale secrets.json bestanden met behoud van directorystructuur (geprumede traversal).
  - Koppelt node_modules via een snelle NTFS Directory Junction of fysieke Robocopy-kloon.
  - Schakelt optioneel IIS direct om naar de nieuwe worktree (inclusief dotnet build).
  - Ondersteunt -WhatIf en -Confirm via CmdletBinding(SupportsShouldProcess = $true).
  - Navigeert direct naar de nieuwe werkmap (bij interactief gebruik).

.PARAMETER Type
  Het type branch: 'feature' (standaard) of 'bugfix'.

.PARAMETER Name
  De naam van de branch (bijv. 'mijn-nieuwe-feature' of '12345-ticket').

.PARAMETER User
  De developer prefix of initialen (standaard bepaald via git user.initials, user.name of Windows username).
  Ondersteunt aliassen 'Prefix' en 'Developer'.

.PARAMETER Base
  De basis branch of commit waarvan wordt afgetakt (standaard: 'origin/main').

.PARAMETER NodeModulesMode
  De wijze waarop node_modules mappen worden gekoppeld:
  - 'junction': Instant NTFS directory junction (0 sec, 0 MB extra schijfruimte, gedeeld).
  - 'copy': Volledige fysieke kopie via multithreaded Robocopy (volledige package-isolatie).
  - 'skip': Geen node_modules koppelen.
  Ondersteunt alias 'NodeModules'.

.PARAMETER SwitchIIS
  Indien opgegeven wordt IIS direct omgeschakeld naar deze nieuwe worktree.

.PARAMETER PassThru
  Indien opgegeven wordt het fysieke pad naar de nieuwe worktree geretourneerd als string.

.PARAMETER Force
  Forceert acties en slaat optionele interactieve bevestigingen over waar mogelijk.

.OUTPUTS
  [System.String]
  Wanneer -PassThru is opgegeven, retourneert de functie het absolute pad naar de nieuwe worktree.

  [void]
  Wanneer -PassThru niet is opgegeven, worden statusberichten naar de console geschreven.

.EXAMPLE
  New-Worktree
  Start de interactieve wizard die stapsgewijs alle benodigde instellingen vraagt.

.EXAMPLE
  New-Worktree -Type feature -Name mijn-nieuwe-feature
  Maakt direct de worktree aan voor de nieuwe feature met standaardinstellingen.

.EXAMPLE
  new-wt -Type bugfix -Name 67890-hotfix -SwitchIIS
  Maakt een bugfix worktree aan via de verkorte alias en schakelt IIS direct om.

.EXAMPLE
  New-Worktree -Type feature -Name test-feature -WhatIf
  Toont wat er zou gebeuren zonder werkelijk bestanden of Git worktrees aan te maken.

.NOTES
  Ondersteunde aliassen: new-wt, add-wt
#>
function New-Worktree {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Position = 0)]
    [ValidateSet("feature", "bugfix")]
    [ValidatePattern('^(feature|bugfix)$')]
    [string]$Type,

    [Parameter(Position = 1)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Position = 2)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [Alias("Prefix", "Developer")]
    [string]$User,

    [Parameter(Position = 3)]
    [string]$Base,

    [Parameter(Position = 4)]
    [ValidateSet("junction", "copy", "skip")]
    [Alias("NodeModules")]
    [string]$NodeModulesMode,

    [Parameter()]
    [switch]$SwitchIIS,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$Force
  )

  # Helper om bestanden te zoeken waarbij zware mappen (.git, node_modules, bin, obj, etc.) direct worden overgeslagen
  function Find-ProjectFilesPruned {
    param(
      [string]$RootPath,
      [string]$TargetFileName,
      [string[]]$SkipDirNames = @('.git', 'bin', 'obj', 'node_modules', '.vs', '.idea', 'dist')
    )
    if (-not (Test-Path -LiteralPath $RootPath)) { return @() }

    $results = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $queue = [System.Collections.Generic.Queue[string]]::new()
    $queue.Enqueue($RootPath)

    while ($queue.Count -gt 0) {
      $dir = $queue.Dequeue()
      try {
        $dirInfo = [System.IO.DirectoryInfo]::new($dir)
        foreach ($file in $dirInfo.EnumerateFiles($TargetFileName)) {
          $results.Add($file)
        }
        foreach ($subDir in $dirInfo.EnumerateDirectories()) {
          if ($SkipDirNames -notcontains $subDir.Name -and -not $subDir.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $queue.Enqueue($subDir.FullName)
          }
        }
      }
      catch { }
    }
    return $results
  }

  # 1. Controleer Git-repository en bepaal projectcontext
  $revParseOutput = git --no-optional-locks rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>$null
  if (-not $revParseOutput) {
    Write-Error "Fout: Huidige map ($(Get-Location)) is geen Git-repository of worktree."
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
  $parentDir = Split-Path -Parent $mainRepoRoot

  Write-Host "`n=== Git Worktree Creator ($projectName) ===" -ForegroundColor Cyan

  # 2. Vraag branchtype (feature / bugfix) indien niet opgegeven
  while (-not $Type) {
    if ($Force) {
      $Type = "feature"
      break
    }
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
    $defaultUser = (git --no-optional-locks config --get user.initials)
    if (-not $defaultUser) {
      $gitName = (git --no-optional-locks config --get user.name)
      if ($gitName) {
        $defaultUser = ($gitName -split " ")[0].ToLower()
      }
      else {
        $defaultUser = $env:USERNAME.ToLower()
      }
    }
    $defaultUser = ($defaultUser -replace '[^a-zA-Z0-9._-]', '')

    while (-not $User) {
      if ($Force) {
        $User = $defaultUser
        break
      }
      $userInput = (Read-Host -Prompt "Developer prefix / initialen (standaard: '$defaultUser')").Trim()
      $candidateUser = if ($userInput) { $userInput } else { $defaultUser }
      if ($candidateUser -match '^[a-zA-Z0-9._-]+$') {
        $User = $candidateUser
      }
      else {
        Write-Warning "Developer prefix bevat ongeldige tekens. Gebruik alleen letters, cijfers, '.', '_' of '-'."
      }
    }
  }

  # 4. Vraag branch- / ticketnaam (bv. mijn-nieuwe-feature)
  while (-not $Name) {
    $inputName = (Read-Host -Prompt "Geef de naam/beschrijving van de branch (bv. mijn-nieuwe-feature)").Trim()
    if (-not $inputName) {
      Write-Warning "Naam mag niet leeg zijn."
    }
    elseif ($inputName -notmatch '^[a-zA-Z0-9._-]+$') {
      Write-Warning "Naam bevat ongeldige tekens. Gebruik alleen letters, cijfers, '.', '_' of '-'."
    }
    else {
      $Name = $inputName
    }
  }

  # Stel de volledige branch- en doelmapnaam samen
  $branchName = "$Type/$User/$Name"
  $targetPath = Join-Path $parentDir "$projectName-$Name"

  # 5. Controleer of de doelmap al bestaat
  if (Test-Path -LiteralPath $targetPath) {
    Write-Error "Fout: De doelmap '$targetPath' bestaat al. Verwijder deze eerst of kies een andere naam."
    return
  }

  # 6. Haal laatste wijzigingen op van remote (fetch)
  Write-Host "`nOphalen laatste wijzigingen van remote..." -ForegroundColor Cyan
  git fetch origin 2>$null

  # 7. Controleer of de branch al bestaat (lokaal of remote)
  git --no-optional-locks show-ref --verify --quiet "refs/heads/$branchName"
  $localExists = ($LASTEXITCODE -eq 0)

  git --no-optional-locks show-ref --verify --quiet "refs/remotes/origin/$branchName"
  $remoteExists = ($LASTEXITCODE -eq 0)

  $useExistingBranch = $false

  if ($localExists -or $remoteExists) {
    $locatie = if ($localExists -and $remoteExists) { "lokaal en op origin" } elseif ($localExists) { "lokaal" } else { "op origin" }
    Write-Host "`nBranch '$branchName' bestaat reeds ($locatie)." -ForegroundColor Yellow
    $useExistingAnswer = if ($Force) { "j" } else { (Read-Host -Prompt "Wil je de bestaande branch gebruiken in de nieuwe worktree? [J/n]").Trim().ToLower() }
    if ($Force -or $useExistingAnswer -eq "" -or $useExistingAnswer -eq "j" -or $useExistingAnswer -eq "ja" -or $useExistingAnswer -eq "y") {
      $useExistingBranch = $true
    }
    else {
      Write-Warning "Geannuleerd: kies een andere naam om conflicten te vermijden."
      return
    }
  }

  # 8. Bepaal basiscommit / startbranch
  if (-not $useExistingBranch -and -not $Base) {
    $defaultBase = "origin/main"
    $baseInput = if ($Force) { $defaultBase } else { (Read-Host -Prompt "Base commit/branch (standaard: '$defaultBase')").Trim() }
    $Base = if ($baseInput) { $baseInput } else { $defaultBase }
  }

  # Controleer ShouldProcess voor -WhatIf en -Confirm ondersteuning
  if (-not $PSCmdlet.ShouldProcess($targetPath, "Nieuwe Git worktree aanmaken ($branchName)")) {
    if ($PassThru) { return $targetPath }
    return
  }

  # 9. Maak de Git worktree aan en stel upstream tracking in
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
    git worktree add --no-track -b $branchName $targetPath $Base
  }

  if ($LASTEXITCODE -ne 0) {
    Write-Error "Aanmaken van worktree is mislukt."
    return
  }

  # Zorg dat de upstream tracking branch altijd direct gekoppeld is aan origin/<branchName>
  git -C $targetPath config "branch.$branchName.remote" "origin"
  git -C $targetPath config "branch.$branchName.merge" "refs/heads/$branchName"

  # 10. Submodules detecteren en initialiseren (.gitmodules)
  $submodulesConfig = Join-Path $targetPath ".gitmodules"
  if (Test-Path -LiteralPath $submodulesConfig) {
    Write-Host "`n.gitmodules gedetecteerd. Initialiseren van submodules..." -ForegroundColor Cyan
    git -C $targetPath submodule update --init --recursive
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Submodules succesvol geïnitialiseerd." -ForegroundColor Green
    }
    else {
      Write-Warning "Submodules konden niet volledig worden geïnitialiseerd."
    }
  }

  # 11. Lokale secrets.json bestanden overnemen (met gepruimde mapdoorzoeking)
  Write-Host "`nZoeken naar lokale secrets.json bestanden..." -ForegroundColor Cyan
  $sourceForAssets = $currentRoot
  $secretsFiles = Find-ProjectFilesPruned -RootPath $sourceForAssets -TargetFileName "secrets.json"

  # Fallback naar de hoofdrepository indien de huidige worktree geen secrets bevat
  if (($null -eq $secretsFiles -or $secretsFiles.Count -eq 0) -and ($currentRoot -ne $mainRepoRoot) -and (Test-Path -LiteralPath $mainRepoRoot)) {
    $sourceForAssets = $mainRepoRoot
    $secretsFiles = Find-ProjectFilesPruned -RootPath $sourceForAssets -TargetFileName "secrets.json"
  }

  if ($secretsFiles -and $secretsFiles.Count -gt 0) {
    Write-Host "Kopiëren van secrets.json bestanden naar de nieuwe worktree..." -ForegroundColor Cyan
    foreach ($sec in $secretsFiles) {
      $relPath = $sec.FullName.Substring($sourceForAssets.Length).TrimStart('\', '/')
      $destPath = Join-Path $targetPath $relPath
      $destDir = Split-Path -Parent $destPath

      if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
      }

      Copy-Item -LiteralPath $sec.FullName -Destination $destPath -Force
      Write-Host "  -> Gekopieerd: $relPath" -ForegroundColor Green
    }
  }

  # 12. node_modules mappen koppelen (Junction of Robocopy)
  $sourceForNode = $currentRoot
  $packageFiles = Find-ProjectFilesPruned -RootPath $sourceForNode -TargetFileName "package.json"

  # Fallback naar de hoofdrepository indien de huidige worktree geen package.json met node_modules bevat
  $hasNodeModules = $false
  if ($packageFiles -and $packageFiles.Count -gt 0) {
    foreach ($pkg in $packageFiles) {
      if (Test-Path -LiteralPath (Join-Path $pkg.DirectoryName "node_modules")) {
        $hasNodeModules = $true
        break
      }
    }
  }

  if (-not $hasNodeModules -and ($currentRoot -ne $mainRepoRoot) -and (Test-Path -LiteralPath $mainRepoRoot)) {
    $sourceForNode = $mainRepoRoot
    $packageFiles = Find-ProjectFilesPruned -RootPath $sourceForNode -TargetFileName "package.json"
  }

  $nodeModuleDirs = @()
  if ($packageFiles -and $packageFiles.Count -gt 0) {
    foreach ($pkg in $packageFiles) {
      $nm = Join-Path $pkg.DirectoryName "node_modules"
      if (Test-Path -LiteralPath $nm) {
        $nodeModuleDirs += $nm
      }
    }
  }

  if ($nodeModuleDirs -and $nodeModuleDirs.Count -gt 0) {
    Write-Host "`nnode_modules mappen gedetecteerd in bronproject." -ForegroundColor Cyan
    
    if (-not $NodeModulesMode) {
      if ($Force) {
        $NodeModulesMode = "junction"
      }
      else {
        Write-Host "Hoe wil je node_modules koppelen in de nieuwe worktree?" -ForegroundColor Yellow
        Write-Host "  [1] Junction link (Aanbevolen: 0 sec, deelt schijfruimte)"
        Write-Host "  [2] Fysiek kopiëren via Robocopy (~20 sec, ~850 MB, volledige isolatie)"
        Write-Host "  [3] Overslaan"
        $nmChoice = (Read-Host -Prompt "Keuze [1/2/3] (standaard: 1)").Trim()
        switch ($nmChoice) {
          "2"      { $NodeModulesMode = "copy" }
          "copy"   { $NodeModulesMode = "copy" }
          "3"      { $NodeModulesMode = "skip" }
          "skip"   { $NodeModulesMode = "skip" }
          default  { $NodeModulesMode = "junction" }
        }
      }
    }

    if ($NodeModulesMode -ne "skip") {
      foreach ($srcNm in $nodeModuleDirs) {
        $relPath    = $srcNm.Substring($sourceForNode.Length).TrimStart('\', '/')
        $destNm     = Join-Path $targetPath $relPath
        $destParent = Split-Path -Parent $destNm

        if (-not (Test-Path -LiteralPath $destParent)) {
          New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        if ($NodeModulesMode -eq "junction") {
          Write-Host "  -> Junction koppelen: $relPath..." -ForegroundColor Cyan
          New-Item -ItemType Junction -Path $destNm -Value $srcNm -Force | Out-Null
          Write-Host "     Klaar (instant)." -ForegroundColor Green
        } elseif ($NodeModulesMode -eq "copy") {
          Write-Host "  -> Fysiek kopiëren via Robocopy: $relPath (kan 15-25 sec duren)..." -ForegroundColor Cyan
          robocopy $srcNm $destNm /E /MT:16 /NFL /NDL /NJH /NJS /NC /NS *>$null
          Write-Host "     Kopiëren voltooid." -ForegroundColor Green
        }
      }
    }
  }

  # 13. Optioneel: Solution bouwen en IIS omschakelen
  if (-not $SwitchIIS) {
    if (Get-Command Switch-WorktreeIIS -ErrorAction SilentlyContinue) {
      $currentIisInfo = ""
      if (Get-Command Get-WorktreeIIS -ErrorAction SilentlyContinue) {
        $activeIisPath = Get-WorktreeIIS -Path $currentRoot -PassThru
        if ($activeIisPath) {
          $currentIisInfo = " (IIS wijst momenteel naar: $(Split-Path -Leaf $activeIisPath))"
        }
      }
      Write-Host ""
      $iisPrompt = if ($Force) { "n" } else { (Read-Host -Prompt "Wil je IIS direct omschakelen naar deze nieuwe worktree?$currentIisInfo [j/N]").Trim().ToLower() }
      if (-not $Force -and ($iisPrompt -eq "j" -or $iisPrompt -eq "ja" -or $iisPrompt -eq "y")) {
        $SwitchIIS = $true
      }
    }
  }

  if ($SwitchIIS) {
    if (Get-Command Switch-WorktreeIIS -ErrorAction SilentlyContinue) {
      # Zoek een .slnx of .sln bestand om desgewenst vooraf te compileren (voorkomt HTTP 500)
      $slnFile = Get-ChildItem -Path $targetPath -Filter "*.slnx" -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $slnFile) {
        $slnFile = Get-ChildItem -Path $targetPath -Filter "*.sln" -File -ErrorAction SilentlyContinue | Select-Object -First 1
      }

      if ($slnFile) {
        Write-Host "`nLet op: IIS vereist gecompileerde binaries in 'bin\Debug' om op te starten." -ForegroundColor Yellow
        $buildPrompt = if ($Force) { "j" } else { (Read-Host -Prompt "Wil je '$($slnFile.Name)' nu eerst bouwen via 'dotnet build'? [J/n]").Trim().ToLower() }
        if ($Force -or $buildPrompt -eq "" -or $buildPrompt -eq "j" -or $buildPrompt -eq "ja" -or $buildPrompt -eq "y") {
          Write-Host "Bezig met bouwen van $($slnFile.Name)..." -ForegroundColor Cyan
          dotnet build $slnFile.FullName
          if ($LASTEXITCODE -ne 0) {
            Write-Warning "Build heeft waarschuwingen of fouten gegenereerd."
          }
        }
      }

      Switch-WorktreeIIS -Path $targetPath -Force:$Force
    } else {
      Write-Warning "Functie 'Switch-WorktreeIIS' is niet geladen in deze PowerShell-sessie."
    }
  }

  Write-Host "`nSucces: Worktree gereed in $targetPath (Branch: $branchName -> Upstream: origin/$branchName)" -ForegroundColor Green

  if ($PassThru) {
    return $targetPath
  }

  # 14. Navigeer naar de nieuwe worktree
  $navAnswer = if ($Force) { "j" } else { (Read-Host -Prompt "`nWil je direct overschakelen naar de nieuwe werkmap? [J/n]").Trim().ToLower() }
  if ($Force -or $navAnswer -eq "" -or $navAnswer -eq "j" -or $navAnswer -eq "ja" -or $navAnswer -eq "y") {
    Set-Location $targetPath
  }
}

# Aliases voor snel typen
Set-Alias -Name new-wt -Value New-Worktree
Set-Alias -Name add-wt -Value New-Worktree
