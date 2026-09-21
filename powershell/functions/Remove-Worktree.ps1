<#
.SYNOPSIS
  Ruimt een Git worktree veilig op, verwijdert optioneel de lokale branch en herstelt IIS.

.DESCRIPTION
  Remove-Worktree biedt een veilige en geautomatiseerde lifecycle-cleanup voor Git worktrees:
  - Toont interactief een keuzelijst van opruimbare worktrees (de hoofdrepository is beschermd).
  - Voorkomt directory locks door automatisch eerst terug te navigeren naar de hoofdrepository.
  - Schakelt IIS vooraf terug naar de hoofdrepository als deze worktree actief is in IIS om bestandvergrendelingen (w3wp locks) op te heffen.
  - Controleert op niet-gecommitte wijzigingen om dataverlies te voorkomen.
  - Ontkoppelt veilig eventuele Directory Junctions (zoals node_modules) via .NET zonder brondata te wissen.
  - Verwijdert de Git worktree registratie en ruimt achtergebleven untracked bestanden (bin, obj, secrets) op.
  - Biedt de optie om de lokale Git-branch direct te verwijderen (-DeleteBranch).
  - Biedt de optie om IIS direct vooraf terug te schakelen naar de hoofdrepository (-SwitchIIS).
  - Ondersteunt -WhatIf en -Confirm via CmdletBinding(SupportsShouldProcess = $true).

.PARAMETER Target
  Optionele naam, branch, mapnaam of trefwoord van de te verwijderen worktree.
  Accepteert invoer via de pipeline en ondersteunt aliassen 'Path' en 'Name'.
  Indien weggelaten toont de functie een interactief keuzemenu.

.PARAMETER DeleteBranch
  Indien opgegeven wordt de bijbehorende lokale branch direct verwijderd zonder extra prompt.
  Ondersteunt aliassen 'Branch' en 'Delete'.

.PARAMETER SwitchIIS
  Indien opgegeven wordt IIS direct teruggeschakeld naar de hoofdrepository.
  Ondersteunt alias 'IIS'.

.PARAMETER Force
  Forceert verwijdering zelfs als er nog niet-gecommitte wijzigingen aanwezig zijn.

.PARAMETER PassThru
  Indien opgegeven wordt het pad van de verwijderde worktree geretourneerd als string.

.OUTPUTS
  [System.String]
  Wanneer -PassThru is opgegeven, retourneert de functie het absolute pad van de opgeruimde worktree.

  [void]
  Wanneer -PassThru niet is opgegeven, worden status- en voortgangsberichten getoond.

.EXAMPLE
  Remove-Worktree
  Start het interactieve menu om een worktree te selecteren en op te ruimen.

.EXAMPLE
  remove-wt mijn-nieuwe-feature -DeleteBranch
  Ruimt worktree 'mijn-nieuwe-feature' direct op en verwijdert de lokale branch.

.EXAMPLE
  remove-wt mijn-nieuwe-feature -DeleteBranch -SwitchIIS -Force
  Volledig geautomatiseerde opruiming inclusief branch-cleanup en IIS-herstel naar main.

.EXAMPLE
  remove-wt mijn-nieuwe-feature -WhatIf
  Toont wat er opgeruimd zou worden zonder daadwerkelijk bestanden of branches te wissen.

.NOTES
  Ondersteunde aliassen: remove-wt, rm-wt, delete-wt
#>
function Remove-Worktree {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Path", "Name")]
    [string]$Target,

    [Parameter()]
    [Alias("Branch", "Delete")]
    [switch]$DeleteBranch,

    [Parameter()]
    [Alias("IIS")]
    [switch]$SwitchIIS,

    [Parameter()]
    [switch]$Force,

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

    Write-Host "`n=== Git Worktree Cleanup ($projectName) ===" -ForegroundColor Cyan

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

    # Filter enkel de secundaire worktrees (hoofdrepository mag NOOIT verwijderd worden)
    $candidateWorktrees = $worktrees | Where-Object { -not $_.IsMain }

    if ($candidateWorktrees.Count -eq 0) {
      Write-Host "Er zijn geen actieve secundaire worktrees gevonden voor $projectName." -ForegroundColor Green
      return
    }

    # Bepaal de actieve IIS worktree voor visualisatie en waarschuwingen (eerst via centrale .git metadata)
    $activeIisPath = $null
    $stateFile = Join-Path $gitCommonDir "iis-worktree.json"
    if (Test-Path -LiteralPath $stateFile) {
      try {
        $json = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($json.activeWorktree) { $activeIisPath = $json.activeWorktree }
      } catch { }
    }
    if (-not $activeIisPath -and (Get-Command Get-WorktreeIIS -ErrorAction SilentlyContinue)) {
      $activeIisPath = Get-WorktreeIIS -Path $currentRoot -PassThru
    }

    # 3. Bepaal welke worktree verwijderd moet worden (interactief of via parameter)
    $selectedWt = $null

    if ($Target) {
      $selectedWt = $candidateWorktrees | Where-Object {
        $_.Path -eq $Target -or
        (Split-Path -Leaf $_.Path) -eq $Target -or
        $_.Branch -eq $Target -or
        (Split-Path -Leaf $_.Path) -like "*$Target*" -or
        $_.Branch -like "*$Target*"
      } | Select-Object -First 1

      if (-not $selectedWt) {
        Write-Error "Fout: Geen actieve worktree gevonden die overeenkomt met '$Target'."
        return
      }
    }
    else {
      # Interactieve keuzelijst tonen
      Write-Host "Selecteer de worktree die je wilt opruimen:" -ForegroundColor Yellow
      for ($i = 0; $i -lt $candidateWorktrees.Count; $i++) {
        $wt = $candidateWorktrees[$i]
        $folderName = Split-Path -Leaf $wt.Path
        $branchInfo = if ($wt.Branch) { "(Branch: $($wt.Branch))" } else { "(Detached HEAD)" }
        $isIis = ($activeIisPath -and ($wt.Path.TrimEnd('\', '/') -eq $activeIisPath.TrimEnd('\', '/')))
        $iisTag = if ($isIis) { " [IIS]" } else { "" }
        Write-Host "  [$($i + 1)] $folderName $branchInfo$iisTag"
      }

      while (-not $selectedWt) {
        $selection = (Read-Host -Prompt "Keuze [1-$($candidateWorktrees.Count)] of 'q' om te annuleren").Trim()
        if ($selection -eq 'q' -or $selection -eq 'exit') {
          Write-Host "Geannuleerd." -ForegroundColor Gray
          return
        }
        $index = $selection -as [int]
        if ($index -ge 1 -and $index -le $candidateWorktrees.Count) {
          $selectedWt = $candidateWorktrees[$index - 1]
        }
        else {
          Write-Warning "Ongeldige keuze, probeer opnieuw."
        }
      }
    }

    $targetPath = $selectedWt.Path
    $targetBranch = $selectedWt.Branch
    $isTargetIis = ($activeIisPath -and ($targetPath.TrimEnd('\', '/') -eq $activeIisPath.TrimEnd('\', '/')))

    Write-Host "`nGeselecteerde worktree: $targetPath" -ForegroundColor Cyan
    if ($targetBranch) {
      Write-Host "Bijbehorende branch : $targetBranch"
    }
    if ($isTargetIis) {
      Write-Host "IIS Status          : [IIS ACTIEF OP DEZE WORKTREE]" -ForegroundColor Magenta
    }

    # Controleer ShouldProcess voor -WhatIf en -Confirm ondersteuning
    if (-not $PSCmdlet.ShouldProcess($targetPath, "Git worktree en bijbehorende bestanden verwijderen")) {
      if ($PassThru) { return $targetPath }
      return
    }

    # 4. Voorkom directory locks (navigeer naar main indien sessie in doelmap staat)
    $currentLocation = (Get-Location).Path
    if ($currentLocation.StartsWith($targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "`nJe bevindt je momenteel in de te verwijderen worktree." -ForegroundColor Yellow
      Write-Host "Navigeren naar hoofdrepository: $mainRepoRoot..." -ForegroundColor Cyan
      Set-Location $mainRepoRoot
    }

    # 5. Controleer op niet-gecommitte wijzigingen
    if (Test-Path -LiteralPath $targetPath) {
      $dirtyStatus = (git --no-optional-locks -C $targetPath status --porcelain 2>$null)
      if ($dirtyStatus -and -not $Force) {
        Write-Warning "`nLET OP: Er zijn nog niet-gecommitte wijzigingen in deze worktree:"
        $dirtyStatus | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        if ($dirtyStatus.Count -gt 5) { Write-Host "  ... en nog $($dirtyStatus.Count - 5) andere bestanden." }

        $confirmDirty = (Read-Host -Prompt "Weet je zeker dat je deze worktree wilt forceren en wijzigingen wilt weggooien? [j/N]").Trim().ToLower()
        if ($confirmDirty -ne "j" -and $confirmDirty -ne "ja" -and $confirmDirty -ne "y") {
          Write-Host "Geannuleerd om dataverlies te voorkomen." -ForegroundColor Yellow
          return
        }
        $Force = $true
      }
    }

    # 6. IIS vooraf terugschakelen naar de hoofdrepository (uitsluitend wanneer IIS gekoppeld is aan deze worktree)
    $shouldSwitchIIS = $false
    if ($isTargetIis) {
      if ($SwitchIIS) {
        $shouldSwitchIIS = $true
      }
      elseif (Get-Command Switch-WorktreeIIS -ErrorAction SilentlyContinue) {
        Write-Host "`nIIS is momenteel actief gekoppeld aan deze worktree." -ForegroundColor Yellow
        $iisPrompt = (Read-Host -Prompt "Wil je IIS nu eerst terugschakelen naar de hoofdrepository ($projectName)? [J/n]").Trim().ToLower()
        if ($iisPrompt -eq "" -or $iisPrompt -eq "j" -or $iisPrompt -eq "ja" -or $iisPrompt -eq "y") {
          $shouldSwitchIIS = $true
        }
      }
    }
    elseif ($SwitchIIS) {
      # Expliciet geforceerd via parameter
      $shouldSwitchIIS = $true
    }

    if ($shouldSwitchIIS) {
      if (Get-Command Switch-WorktreeIIS -ErrorAction SilentlyContinue) {
        Write-Host "`nIIS vooraf terugschakelen naar de hoofdrepository ($projectName)..." -ForegroundColor Cyan
        Switch-WorktreeIIS -Path $mainRepoRoot
      } else {
        Write-Warning "Functie 'Switch-WorktreeIIS' is niet geladen in deze PowerShell-sessie."
      }
    }

    # 7. Veilige ontkoppeling van eventuele Directory Junctions (zoals node_modules) via .NET
    if (Test-Path -LiteralPath $targetPath) {
      $junctions = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
      $queue = [System.Collections.Generic.Queue[string]]::new()
      $queue.Enqueue($targetPath)
      $skipDirs = @('.git', 'bin', 'obj', '.vs', '.idea')

      while ($queue.Count -gt 0) {
        $dir = $queue.Dequeue()
        try {
          $dirInfo = [System.IO.DirectoryInfo]::new($dir)
          foreach ($subDir in $dirInfo.EnumerateDirectories()) {
            if ($subDir.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
              $junctions.Add($subDir)
            }
            elseif ($skipDirs -notcontains $subDir.Name) {
              $queue.Enqueue($subDir.FullName)
            }
          }
        }
        catch { }
      }

      foreach ($j in $junctions) {
        Write-Host "Ontkoppelen van Junction: $($j.FullName)..." -ForegroundColor Cyan
        try {
          [System.IO.Directory]::Delete($j.FullName, $false)
        }
        catch {
          Write-Warning "Kon junction '$($j.FullName)' niet ontkoppelen: $_"
        }
      }
    }

    # 8. Verwijder de Git worktree en ruim achtergebleven bestanden op
    Write-Host "`nVerwijderen van worktree via Git..." -ForegroundColor Cyan
    $gitArgs = if ($Force) { @('worktree', 'remove', '--force', $targetPath) } else { @('worktree', 'remove', $targetPath) }
    $gitResult = & git --no-optional-locks -C $mainRepoRoot @gitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
      $errStr = ($gitResult | Out-String).Trim()
      if ($errStr -match 'containing submodules cannot be moved or removed') {
        Write-Host "Git-beveiliging: worktree bevat submodules. Lokale map en Git-administratie worden nu direct opgeruimd..." -ForegroundColor Yellow
      }
      elseif ($errStr) {
        Write-Warning "git worktree remove melding: $errStr"
      }
    }

    # Eventuele achtergebleven untracked bestanden (zoals secrets.json, bin, obj) definitief opruimen
    if (Test-Path -LiteralPath $targetPath) {
      Write-Host "Verwijderen van achtergebleven lokale bestanden (bin, obj, secrets)..." -ForegroundColor Cyan
      try {
        Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
      }
      catch {
        Start-Sleep -Milliseconds 300
        try {
          Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
        }
        catch {
          Write-Warning "Map '$targetPath' kon niet volledig worden gewist. Mogelijk heeft een applicatie (zoals JetBrains Rider of Visual Studio) nog een bestand vergrendeld."
        }
      }
    }

    # Prune administratieve Git metadata
    git --no-optional-locks -C $mainRepoRoot worktree prune

    if (-not (Test-Path -LiteralPath $targetPath)) {
      Write-Host "Worktree map succesvol opgeruimd!" -ForegroundColor Green
    }
    else {
      Write-Warning "Worktree map '$targetPath' is nog deels aanwezig op schijf."
    }

    # 9. Optioneel: Lokale Git-branch verwijderen
    if ($targetBranch) {
      $doDeleteBranch = $DeleteBranch
      if (-not $doDeleteBranch) {
        $branchAnswer = (Read-Host -Prompt "`nWil je ook de lokale branch '$targetBranch' verwijderen? [J/n]").Trim().ToLower()
        if ($branchAnswer -eq "" -or $branchAnswer -eq "j" -or $branchAnswer -eq "ja" -or $branchAnswer -eq "y") {
          $doDeleteBranch = $true
        }
      }

      if ($doDeleteBranch) {
        Write-Host "Verwijderen van lokale branch '$targetBranch'..." -ForegroundColor Cyan
        git -C $mainRepoRoot branch -d $targetBranch 2>$null
        if ($LASTEXITCODE -ne 0) {
          Write-Warning "Branch '$targetBranch' is nog niet gemerged in de huidige checkout."
          $forceBranch = (Read-Host -Prompt "Geforceerd verwijderen (git branch -D)? [j/N]").Trim().ToLower()
          if ($forceBranch -eq "j" -or $forceBranch -eq "ja" -or $forceBranch -eq "y") {
            git -C $mainRepoRoot branch -D $targetBranch
            Write-Host "Branch '$targetBranch' geforceerd verwijderd." -ForegroundColor Green
          }
        } else {
          Write-Host "Lokale branch '$targetBranch' succesvol verwijderd." -ForegroundColor Green
        }
      }
    }

    Write-Host "`nCleanup voltooid! Huidige locatie: $(Get-Location)" -ForegroundColor Green

    if ($PassThru) {
      return $targetPath
    }
  }
}

# Aliases voor snel typen
Set-Alias -Name remove-wt -Value Remove-Worktree
Set-Alias -Name rm-wt     -Value Remove-Worktree
Set-Alias -Name delete-wt -Value Remove-Worktree
