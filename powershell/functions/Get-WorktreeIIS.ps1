<#
.SYNOPSIS
  Geeft de actieve IIS worktree of main repository weer voor het huidige project.

.DESCRIPTION
  Get-WorktreeIIS inspecteert de actieve IIS-koppeling voor het huidige Git-project.
  Het leest de status uit de centrale .git-metadata (ingesteld door Switch-Worktree / Switch-WorktreeIIS).
  Indien nog geen expliciete switch is uitgevoerd, valt de functie terug op de hoofdrepository (main).

.PARAMETER Path
  Optioneel pad naar een map of worktree binnen het project (standaard: huidige directory).
  Accepteert invoer via de pipeline en de alias 'Target'.

.PARAMETER PassThru
  Indien opgegeven wordt alleen het pad als string geretourneerd (handig voor scripts en pipeline-integratie).

.OUTPUTS
  [System.String]
  Wanneer -PassThru is opgegeven, retourneert de functie het absolute pad naar de actieve worktree.

  [void]
  Wanneer -PassThru niet is opgegeven, wordt een visuele statusconsole-uitvoer getoond.

.EXAMPLE
  Get-WorktreeIIS
  Toont een overzichtelijke status van de worktree waarnaar IIS momenteel wijst.

.EXAMPLE
  iis-wt
  Verkorte alias om snel de actieve IIS worktree te inspecteren.

.EXAMPLE
  $iisPath = Get-WorktreeIIS -PassThru
  Haalt het fysieke pad op voor gebruik in scripts.

.EXAMPLE
  Get-WorktreeIIS -Path C:\Workspace\MijnProject-Feature1
  Inspecteert de IIS-configuratiestatus voor een specifieke projectmap.

.NOTES
  Ondersteunde aliassen: iis-wt, get-iis-wt
#>
function Get-WorktreeIIS {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Target")]
    [string]$Path = (Get-Location).Path,

    [Parameter()]
    [switch]$PassThru
  )

  process {
    # 1. Controleer Git-repository en bepaal projectcontext
    $revParseOutput = git --no-optional-locks -C $Path rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>$null
    if (-not $revParseOutput) {
      if (-not $PassThru) {
        Write-Error "Fout: Pad '$Path' bevindt zich niet in een Git-repository of worktree."
      }
      return $null
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

    # 2. Lees de IIS state uit de centrale Git metadata
    $stateFile = Join-Path $gitCommonDir "iis-worktree.json"
    $activePath = $null
    $stateData = $null

    if (Test-Path -LiteralPath $stateFile) {
      try {
        $stateData = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($stateData.activeWorktree) {
          $activePath = $stateData.activeWorktree
        }
      }
      catch { }
    }

    # Fallback: controleer iis-worktree.txt
    if (-not $activePath) {
      $txtFile = Join-Path $gitCommonDir "iis-worktree.txt"
      if (Test-Path -LiteralPath $txtFile) {
        $txtContent = (Get-Content -LiteralPath $txtFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($txtContent) { $activePath = $txtContent }
      }
    }

    # Fallback: standaard wijst IIS naar de hoofdrepository (main)
    if (-not $activePath) {
      $activePath = $mainRepoRoot
    }

    # Normaliseer pad indien het nog bestaat op schijf
    if (Test-Path -LiteralPath $activePath) {
      try {
        $activePath = [System.IO.Path]::GetFullPath($activePath)
      } catch {
        $activePath = (Resolve-Path -Path $activePath).Path
      }
    }

    if ($PassThru) {
      return $activePath
    }

    # 3. Toon visueel overzicht
    $isMain = ($activePath.TrimEnd('\', '/') -eq $mainRepoRoot.TrimEnd('\', '/'))
    $folderName = Split-Path -Leaf $activePath
    $typeLabel = if ($isMain) { "Main Repository" } else { "Feature Worktree" }

    Write-Host "`n=== IIS Worktree Status ($projectName) ===" -ForegroundColor Cyan
    Write-Host "  Actieve IIS worktree : " -NoNewline
    Write-Host "$folderName" -ForegroundColor Yellow -NoNewline
    Write-Host " ($typeLabel)" -ForegroundColor Gray

    Write-Host "  Fysiek pad           : " -NoNewline
    Write-Host "$activePath" -ForegroundColor Green

    if ($stateData.lastSwitched) {
      Write-Host "  Laatst gewijzigd     : $($stateData.lastSwitched)" -ForegroundColor Gray
    }
    Write-Host ""
  }
}

# Aliases voor snel typen
Set-Alias -Name iis-wt     -Value Get-WorktreeIIS
Set-Alias -Name get-iis-wt -Value Get-WorktreeIIS
