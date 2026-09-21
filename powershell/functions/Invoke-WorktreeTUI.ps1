<#
.SYNOPSIS
  Interactieve TUI voor het snel beheren en navigeren tussen Git worktrees.

.DESCRIPTION
  Invoke-WorktreeTUI toont een snelle en compacte fzf-interface met dynamisch uitgelijnde kolommen
  inclusief Git-wijzigingsstatus (Merged, unmerged commits, dirty status ten opzichte van main).
  Biedt interactieve sneltoetsen voor snelle navigatie (Enter), IIS-switch (Alt-Enter, Ctrl-S),
  in-place refresh van de worktree-lijst en statussen (Ctrl-R, F5), creatie (Ctrl-N) en veilige verwijdering (Ctrl-D)
  van worktrees binnen het huidige Git-project.

.PARAMETER SwitchIIS
  Indien opgegeven wordt bij het selecteren met Enter ook direct de IIS-omgeving omgeschakeld.
  Ondersteunt aliassen 'IIS' en 'WithIIS'.

.PARAMETER SkipIIS
  Indien opgegeven wordt uitsluitend genavigeerd naar de doelmap zonder IIS aan te passen (standaardgedrag).
  Ondersteunt alias 'NoIIS'.

.PARAMETER ListOnly
  Genereert en streamt uitsluitend de geformatteerde lijst met worktrees en statussen naar de output (gebruikt voor fzf reload).

.OUTPUTS
  [void]
  Start een interactieve TUI en navigeert of muteert worktrees via gebruikersinteractie.

.EXAMPLE
  Invoke-WorktreeTUI
  Opent de interactieve worktree-kiezer; Enter navigeert direct naar de geselecteerde worktree.

.EXAMPLE
  worktree
  Sneltoets-alias voor Invoke-WorktreeTUI.

.EXAMPLE
  worktree -IIS
  Opent de interactieve worktree-kiezer waarbij Enter direct ook de IIS-omgeving overschakelt.

.NOTES
  Ondersteunde aliassen: worktree
  Vereist: fzf (geïnstalleerd en beschikbaar in PATH)
#>

$script:thisScriptPath = $PSCommandPath

function Get-WorktreeTUIList {
  [CmdletBinding()]
  param()

  # 1. Controleer Git-repository en bepaal projectcontext
  $revParseOutput = git --no-optional-locks rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>$null
  if (-not $revParseOutput) {
    Write-Error "Fout: Huidige map ($(Get-Location)) bevindt zich niet in een Git-repository of worktree."
    return @()
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

  # 2. Haal actieve worktrees op
  $worktrees = @()
  $rawList = git --no-optional-locks worktree list --porcelain 2>$null
  $wtEntry = [ordered]@{}
  foreach ($line in $rawList) {
    $trimmedLine = $line.Trim()
    if ($trimmedLine -match '^worktree (.+)$') {
      if ($wtEntry.Path) { $worktrees += [PSCustomObject]$wtEntry }
      $resolvedWtPath = $null
      $rawPath = $matches[1].Trim()
      try { $resolvedWtPath = [System.IO.Path]::GetFullPath($rawPath) } catch { $resolvedWtPath = $rawPath }
      $wtEntry = [ordered]@{ Path = $resolvedWtPath; Branch = ''; IsMain = $false }
    }
    elseif ($trimmedLine -match '^branch refs/heads/(.+)$') {
      $wtEntry.Branch = $matches[1].Trim()
    }
  }
  if ($wtEntry.Path) { $worktrees += [PSCustomObject]$wtEntry }

  if ($worktrees.Count -gt 0) {
    $worktrees[0].IsMain = $true
  }

  # Bepaal hoofdbranch van de repository (main/master of root worktree branch)
  $mainBranch = if ($worktrees.Count -gt 0 -and $worktrees[0].Branch) {
    $worktrees[0].Branch
  }
  else {
    git --no-optional-locks show-ref --verify --quiet refs/heads/main
    if ($LASTEXITCODE -eq 0) { "main" } else { "master" }
  }

  $candidateMains = @()
  $candidateTrees = @{}
  $mergedBranches = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  if ($mainBranch) {
    $candidateMains += $mainBranch
    $mergedLocal = git --no-optional-locks -C $currentRoot branch --merged $mainBranch 2>$null
    if ($mergedLocal) {
      foreach ($b in $mergedLocal) {
        $cleanB = ($b -replace '^[\s*+]+', '').Trim()
        if ($cleanB -and -not ($cleanB -like '*(HEAD detached*')) {
          [void]$mergedBranches.Add($cleanB)
        }
      }
    }

    git --no-optional-locks -C $currentRoot show-ref --verify --quiet "refs/remotes/origin/$mainBranch"
    if ($LASTEXITCODE -eq 0) {
      $candidateMains += "origin/$mainBranch"
      $mergedRemote = git --no-optional-locks -C $currentRoot branch -r --merged "origin/$mainBranch" 2>$null
      if ($mergedRemote) {
        foreach ($b in $mergedRemote) {
          $cleanB = ($b -replace '^[\s*+]+', '').Trim()
          if ($cleanB -and $cleanB -notmatch '->') {
            $branchOnly = $cleanB -replace '^origin/', ''
            [void]$mergedBranches.Add($branchOnly)
          }
        }
      }
    }

    foreach ($cand in $candidateMains) {
      $candTree = (git --no-optional-locks -C $currentRoot rev-parse "$cand^{tree}" 2>$null)
      if ($candTree) {
        $candidateTrees[$cand] = $candTree.Trim()
      }
    }
  }

  # Bereken Git status en unmerged commits per worktree gelijktijdig via RunspacePool
  $e = [char]27
  $reset = "$e[0m"
  $green = "$e[32m"
  $yellow = "$e[33m"
  $red = "$e[31m"

  $mergedBranchArray = [string[]]($mergedBranches)

  $workerScript = {
    param($wtPath, $wtBranch, $wtIsMain, $mainBranch, $candidateMains, $candidateTrees, $mergedBranchArray)

    $mergedSet = [System.Collections.Generic.HashSet[string]]::new($mergedBranchArray, [System.StringComparer]::OrdinalIgnoreCase)

    $isDirty = $false
    if ([System.IO.Directory]::Exists($wtPath)) {
      $isDirty = [bool](git --no-optional-locks -C $wtPath status --porcelain 2>$null)
    }

    $aheadCount = 0
    if ($wtIsMain -or ($mainBranch -and $wtBranch -eq $mainBranch)) {
      $aheadCount = 0
    }
    elseif ($wtBranch -and $mergedSet.Contains($wtBranch)) {
      $aheadCount = 0
    }
    else {
      $branchRef = if ($wtBranch) { $wtBranch } else { (git --no-optional-locks -C $wtPath rev-parse HEAD 2>$null) }
      if ($branchRef) {
        $minAhead = [int]::MaxValue
        foreach ($candidate in $candidateMains) {
          $revCount = (git --no-optional-locks -C $wtPath rev-list --count "$candidate..$branchRef" 2>$null)
          $count = if ($revCount -match '^\d+$') { [int]$revCount } else { [int]::MaxValue }
          if ($count -eq 0) {
            $minAhead = 0
            break
          }

          # Controleer op squash merge / identieke tree via merge-tree met behulp van gecachte candidate tree
          $mergedTree = (git --no-optional-locks -C $wtPath merge-tree --write-tree "$candidate" "$branchRef" 2>$null)
          $candTree = $candidateTrees[$candidate]
          if (-not $candTree) {
            $candTree = (git --no-optional-locks -C $wtPath rev-parse "$candidate^{tree}" 2>$null)
          }
          if ($mergedTree -and $candTree -and $mergedTree.Trim() -eq $candTree.Trim()) {
            $minAhead = 0
            break
          }

          if ($count -lt $minAhead) {
            $minAhead = $count
          }
        }
        $aheadCount = if ($minAhead -ne [int]::MaxValue) { $minAhead } else { 0 }
      }
    }

    return [PSCustomObject]@{
      Path       = $wtPath
      IsDirty    = $isDirty
      AheadCount = $aheadCount
    }
  }

  if ($worktrees.Count -gt 0) {
    $maxThreads = [Math]::Min($worktrees.Count, [Math]::Max(2, [Environment]::ProcessorCount))
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads)
    $runspacePool.Open()

    $tasks = [System.Collections.Generic.List[object]]::new()
    try {
      foreach ($wt in $worktrees) {
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.RunspacePool = $runspacePool
        [void]$ps.AddScript($workerScript)
        [void]$ps.AddArgument($wt.Path)
        [void]$ps.AddArgument($wt.Branch)
        [void]$ps.AddArgument($wt.IsMain)
        [void]$ps.AddArgument($mainBranch)
        [void]$ps.AddArgument($candidateMains)
        [void]$ps.AddArgument($candidateTrees)
        [void]$ps.AddArgument($mergedBranchArray)
        $asyncResult = $ps.BeginInvoke()
        $tasks.Add([PSCustomObject]@{
            PowerShell  = $ps
            AsyncResult = $asyncResult
            Worktree    = $wt
          })
      }

      foreach ($task in $tasks) {
        try {
          $res = $task.PowerShell.EndInvoke($task.AsyncResult)
          $resultObj = if ($res -and $res.Count -gt 0) { $res[0] } else { $null }
          $wt = $task.Worktree
          $isDirty = if ($resultObj) { [bool]$resultObj.IsDirty } else { $false }
          $aheadCount = if ($resultObj) { [int]$resultObj.AheadCount } else { 0 }

          $statusText = ""
          $statusDisplay = ""

          if ($wt.IsMain -or ($mainBranch -and $wt.Branch -eq $mainBranch)) {
            if ($isDirty) {
              $statusText = "* Dirty"
              $statusDisplay = "${yellow}* Dirty${reset}"
            }
            else {
              $statusText = "Clean"
              $statusDisplay = "${green}Clean${reset}"
            }
          }
          elseif ($aheadCount -eq 0 -and -not $isDirty) {
            $statusText = "Merged"
            $statusDisplay = "${green}Merged${reset}"
          }
          elseif ($aheadCount -gt 0 -and -not $isDirty) {
            $statusText = "+$aheadCount commits"
            $statusDisplay = "${yellow}+$aheadCount commits${reset}"
          }
          elseif ($aheadCount -eq 0 -and $isDirty) {
            $statusText = "* Dirty"
            $statusDisplay = "${yellow}* Dirty${reset}"
          }
          else {
            $statusText = "+$aheadCount commits, * Dirty"
            $statusDisplay = "${red}+$aheadCount commits, * Dirty${reset}"
          }

          Add-Member -InputObject $wt -NotePropertyName "StatusText" -NotePropertyValue $statusText -Force
          Add-Member -InputObject $wt -NotePropertyName "StatusDisplay" -NotePropertyValue $statusDisplay -Force
        }
        finally {
          $task.PowerShell.Dispose()
        }
      }
    }
    finally {
      $runspacePool.Close()
      $runspacePool.Dispose()
    }
  }

  # 3. Bepaal actieve IIS worktree (eerst snel via centrale .git metadata, fallback via Get-WorktreeIIS)
  $activeIisPath = $null
  if ($gitCommonDir) {
    $stateFile = Join-Path $gitCommonDir "iis-worktree.json"
    if (Test-Path -LiteralPath $stateFile) {
      try {
        $json = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($json.activeWorktree) { $activeIisPath = $json.activeWorktree }
      }
      catch { }
    }
  }
  if (-not $activeIisPath -and (Get-Command Get-WorktreeIIS -ErrorAction SilentlyContinue)) {
    $activeIisPath = Get-WorktreeIIS -Path $currentRoot -PassThru
  }

  # 4. Bouw geformatteerde regels op voor de TUI
  $maxFolder = 20
  $maxBranch = 20
  $maxStatus = 10
  $maxTag = 14
  foreach ($wt in $worktrees) {
    $folderName = Split-Path -Leaf $wt.Path
    if ($folderName.Length -gt $maxFolder) { $maxFolder = $folderName.Length }
    if ($wt.Branch -and $wt.Branch.Length -gt $maxBranch) { $maxBranch = $wt.Branch.Length }
    if ($wt.StatusText -and $wt.StatusText.Length -gt $maxStatus) { $maxStatus = $wt.StatusText.Length }
  }

  $lines = foreach ($wt in $worktrees) {
    $folder = Split-Path -Leaf $wt.Path
    $isCurrent = ($wt.Path.TrimEnd('\', '/') -eq $currentRoot.TrimEnd('\', '/'))
    $isIis = ($activeIisPath -and ($wt.Path.TrimEnd('\', '/') -eq $activeIisPath.TrimEnd('\', '/')))
    $tags = @()
    if ($isIis) { $tags += "[IIS]" }
    if ($isCurrent) { $tags += "[Huidig]" }
    $tagStr = if ($tags.Count -gt 0) { $tags -join " " } else { "" }

    $statusLen = if ($wt.StatusText) { $wt.StatusText.Length } else { 0 }
    $padCount = [Math]::Max(0, $maxStatus - $statusLen)
    $padSpaces = " " * $padCount
    $paddedStatus = "$($wt.StatusDisplay)$padSpaces"

    "{0,-$maxFolder} | {1,-$maxBranch} | {2} | {3,-$maxTag} |{4}" -f $folder, $wt.Branch, $paddedStatus, $tagStr, $wt.Path
  }

  return $lines
}

function Invoke-WorktreeTUI {
  [CmdletBinding()]
  param(
    [Parameter()]
    [Alias("IIS", "WithIIS")]
    [switch]$SwitchIIS,

    [Parameter()]
    [Alias("NoIIS")]
    [switch]$SkipIIS,

    [Parameter()]
    [switch]$ListOnly
  )

  if ($ListOnly) {
    Get-WorktreeTUIList
    return
  }

  $scriptFile = $script:thisScriptPath
  if (-not $scriptFile -or -not (Test-Path $scriptFile)) {
    $scriptFile = (Get-Command Invoke-WorktreeTUI -ErrorAction SilentlyContinue).ScriptBlock.File
  }
  if (-not $scriptFile -or -not (Test-Path $scriptFile)) {
    $scriptFile = $PSCommandPath
  }
  if (-not $scriptFile -or -not (Test-Path $scriptFile)) {
    $scriptFile = Join-Path $HOME "Documents\PowerShell\functions\Invoke-WorktreeTUI.ps1"
  }

  $codeToRun = "`$ProgressPreference = 'SilentlyContinue'; . '$scriptFile'; Invoke-WorktreeTUI -ListOnly"
  $bytes = [System.Text.Encoding]::Unicode.GetBytes($codeToRun)
  $encodedCmd = [System.Convert]::ToBase64String($bytes)

  $psCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
  $reloadCmd = "$psCmd -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCmd"

  :tuiLoop while ($true) {
    $lines = Get-WorktreeTUIList
    if (-not $lines -or $lines.Count -eq 0) {
      return
    }

    $header = "Enter: Navigeer | Alt-Enter / Ctrl-S: Switch (IIS) | Ctrl-R / F5: Refresh | Ctrl-N: Nieuw | Ctrl-D: Verwijderen | Esc: Sluiten"

    # Start fzf met in-place reload binding
    $selected = $lines | fzf `
      --ansi `
      --header=$header `
      --prompt="Worktrees> " `
      --delimiter="|" `
      --with-nth="1,2,3,4" `
      --expect="ctrl-n,ctrl-d,ctrl-s,alt-enter" `
      --bind="ctrl-r:reload($reloadCmd),f5:reload($reloadCmd)"

    if (-not $selected -or $selected.Count -eq 0 -or ($selected.Count -eq 1 -and [string]::IsNullOrWhiteSpace($selected[0]))) {
      return
    }

    $key = $selected[0]
    $line = if ($selected.Count -gt 1) { $selected[1] } else { $null }
    $targetPath = if ($line) { ($line -split "\|")[4].Trim() } else { $null }

    # Voer actie uit op basis van interactie
    switch ($key) {
      "ctrl-n" {
        New-Worktree
        continue tuiLoop
      }
      "ctrl-d" {
        if ($targetPath) {
          Remove-Worktree -Target $targetPath
        }
        continue tuiLoop
      }
      { $_ -in @("ctrl-s", "alt-enter") } {
        if ($targetPath) {
          Switch-Worktree -Target $targetPath
        }
        continue tuiLoop
      }
      default {
        if ($targetPath) {
          if ($SwitchIIS -and -not $SkipIIS) {
            Switch-Worktree -Target $targetPath
          }
          else {
            Switch-Worktree -Target $targetPath -SkipIIS
          }
        }
        return
      }
    }
  }
}

# Aliases voor maximale efficiëntie
Set-Alias -Name worktree     -Value Invoke-WorktreeTUI
