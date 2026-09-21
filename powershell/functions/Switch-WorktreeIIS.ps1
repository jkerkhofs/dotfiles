<#
.SYNOPSIS
  Past de fysieke paden in IIS aan naar de opgegeven worktree en herstart Application Pools.

.DESCRIPTION
  Switch-WorktreeIIS is een project-agnostische helper die IIS-applicaties koppelt aan een
  Git worktree. De functie:
  - Vraagt indien nodig automatisch administrator-verhoging via UAC (inline via sudo of verborgen transcript).
  - Detecteert webprojecten automatisch via launchSettings.json (applicationUrl matching).
  - Valt terug op padtransformatie voor bestaande IIS-applicaties die naar het project wijzen.
  - Past het physicalPath aan via de WebAdministration module.
  - Recyclet uitsluitend de specifiek gekoppelde Application Pools.
  - Ondersteunt -WhatIf en -Confirm via CmdletBinding(SupportsShouldProcess = $true).

.PARAMETER Path
  Het pad naar de werkmap van de worktree (standaard: huidige directory).
  Accepteert invoer via de pipeline en de alias 'Target'.

.PARAMETER Force
  Forceert de IIS switch zonder eventuele waarschuwingen.

.PARAMETER PassThru
  Indien opgegeven wordt het doelpad geretourneerd als string.

.OUTPUTS
  [System.String]
  Wanneer -PassThru is opgegeven, retourneert de functie het absolute pad van de geconfigureerde worktree.

  [void]
  Wanneer -PassThru niet is opgegeven, worden statusberichten naar de console geschreven.

.EXAMPLE
  Switch-WorktreeIIS
  Past IIS aan voor de worktree waarin de terminal zich momenteel bevindt.

.EXAMPLE
  switch-iis C:\Workspace\MijnProject-12345-feature
  Past IIS aan voor het expliciet opgegeven worktree-pad.

.EXAMPLE
  Switch-WorktreeIIS -WhatIf
  Toont welke IIS-paden en Application Pools gewijzigd zouden worden zonder dit daadwerkelijk uit te voeren.

.NOTES
  Ondersteunde aliassen: switch-iis, switch-iis-wt, set-iis-wt
  Vereist: IIS Management Scripts and Tools (WebAdministration module)
#>
function Switch-WorktreeIIS {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("Target")]
    [string]$Path = (Get-Location).Path,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$PassThru
  )

  process {
    # 1. Controleer administrator-rechten; handel verhoging inline af indien nodig
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
      $resolvedPath = (Resolve-Path $Path).Path

      # Controleer ShouldProcess vóór UAC verhoging
      if (-not $PSCmdlet.ShouldProcess($resolvedPath, "IIS physicalPath en Application Pools bijwerken via verhoogd proces")) {
        if ($PassThru) { return $resolvedPath }
        return
      }

      if (-not $Force) {
        Write-Host "`nAdministrator-rechten vereist voor IIS-aanpassingen." -ForegroundColor Yellow
        Write-Host "UAC-prompt wordt geopend voor goedkeuring..." -ForegroundColor Cyan
      }

      $psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
      if (-not (Test-Path $psExe)) {
        $psExe = (Get-Process -Id $PID).Path
      }

      $funcDef = (Get-Command Switch-WorktreeIIS).Definition
      $encodedPath = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($resolvedPath))
      $forceLiteral = $Force.IsPresent.ToString()

      # Controleer of Windows 11 'sudo' inline ondersteunt
      $useSudoInline = $false
      if (Get-Command sudo.exe -ErrorAction SilentlyContinue) {
        $sudoConfig = (sudo config 2>$null) -join " "
        if ($sudoConfig -notmatch "Force New Window") {
          $useSudoInline = $true
        }
      }

      # Methode A: Windows 11 Sudo inline
      if ($useSudoInline) {
        $tempScript = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "Switch-WorktreeIIS-$([System.Guid]::NewGuid().ToString('N')).ps1")
        $scriptBlock = @"
`$ErrorActionPreference = 'Stop'
function Switch-WorktreeIIS {
$funcDef
}
`$targetPath = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$encodedPath'))
`$forceEnabled = [System.Boolean]::Parse('$forceLiteral')
Switch-WorktreeIIS -Path `$targetPath -Force:`$forceEnabled
"@
        try {
          [System.IO.File]::WriteAllText($tempScript, $scriptBlock, [System.Text.Encoding]::UTF8)
          sudo.exe --inline $psExe -NoProfile -ExecutionPolicy Bypass -File $tempScript
          if ($LASTEXITCODE -eq 0) {
            try {
              $gitCommonDirRaw = (git --no-optional-locks -C $resolvedPath rev-parse --path-format=absolute --git-common-dir 2>$null)
              if ($gitCommonDirRaw) {
                $state = [ordered]@{
                  activeWorktree = $resolvedPath
                  folderName     = Split-Path -Leaf $resolvedPath
                  projectName    = (Split-Path -Leaf (Split-Path -Parent $gitCommonDirRaw))
                  lastSwitched   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                  switchedBy     = $env:USERNAME
                }
                $state | ConvertTo-Json | Set-Content -Path (Join-Path $gitCommonDirRaw "iis-worktree.json") -Force -ErrorAction SilentlyContinue
              }
            }
            catch { }
          }
        }
        catch {
          Write-Warning "UAC-toestemming geannuleerd of sudo-fout: $_"
        }
        finally {
          if (Test-Path -LiteralPath $tempScript) { Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue }
        }
        if ($PassThru) { return $resolvedPath }
        return
      }

      # Methode B: Verborgen elevated proces met uitvoer-opvang in tijdelijk logbestand
      $tempLog = [System.IO.Path]::GetTempFileName()
      $tempScript = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "Switch-WorktreeIIS-$([System.Guid]::NewGuid().ToString('N')).ps1")
      $encodedLog = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($tempLog))
      $elevatedScript = @"
`$ErrorActionPreference = 'Stop'
function Switch-WorktreeIIS {
$funcDef
}
`$targetPath = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$encodedPath'))
`$targetLog = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$encodedLog'))
`$forceEnabled = [System.Boolean]::Parse('$forceLiteral')
try {
    Start-Transcript -Path `$targetLog -Force | Out-Null
    Switch-WorktreeIIS -Path `$targetPath -Force:`$forceEnabled
    Stop-Transcript | Out-Null
    exit 0
} catch {
    `$err = "`n[FOUT] `$(`$_.Exception.Message)"
    Write-Output `$err
    Add-Content -Path `$targetLog -Value `$err
    Stop-Transcript | Out-Null
    exit 1
}
"@
      try {
        [System.IO.File]::WriteAllText($tempScript, $elevatedScript, [System.Text.Encoding]::UTF8)
        $process = Start-Process -FilePath $psExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`"" -Verb RunAs -PassThru -Wait

        if (Test-Path -LiteralPath $tempLog) {
          $lines = Get-Content -LiteralPath $tempLog -ErrorAction SilentlyContinue |
          Where-Object {
            $_ -notmatch '^(\*{10,}|Windows PowerShell transcript|Start time:|Username:|RunAs User:|Configuration Name:|Machine:|Host Application:|Process ID:|PSVersion:|PSEdition:|OS:|CLRVersion:|BuildVersion:|WSManStackVersion:|PSCompatibleVersions:|SerializationVersion:|End time:)'
          }

          $lines | ForEach-Object {
            if ($_ -match '\[FOUT\]') {
              Write-Host $_ -ForegroundColor Red
            }
            elseif ($_ -match '^===|Doelmap:') {
              Write-Host $_ -ForegroundColor Cyan
            }
            elseif ($_ -match 'Match gevonden|Bestaande IIS app|Herstarten') {
              Write-Host $_ -ForegroundColor Yellow
            }
            elseif ($_ -match 'Succes:|Nieuw pad:') {
              Write-Host $_ -ForegroundColor Green
            }
            elseif ($_.Trim()) {
              Write-Host $_
            }
          }
          Remove-Item -LiteralPath $tempLog -Force -ErrorAction SilentlyContinue
        }

        if ($process.ExitCode -eq 0) {
          try {
            $gitCommonDirRaw = (git --no-optional-locks -C $resolvedPath rev-parse --path-format=absolute --git-common-dir 2>$null)
            if ($gitCommonDirRaw) {
              $state = [ordered]@{
                activeWorktree = $resolvedPath
                folderName     = Split-Path -Leaf $resolvedPath
                projectName    = (Split-Path -Leaf (Split-Path -Parent $gitCommonDirRaw))
                lastSwitched   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                switchedBy     = $env:USERNAME
              }
              $state | ConvertTo-Json | Set-Content -Path (Join-Path $gitCommonDirRaw "iis-worktree.json") -Force -ErrorAction SilentlyContinue
            }
          }
          catch { }
          Write-Host "IIS-paden en Application Pools zijn succesvol bijgewerkt." -ForegroundColor Green
        }
        else {
          Write-Error "Aanpassen van IIS is mislukt in het verhoogde proces."
        }
      }
      catch {
        Write-Warning "UAC-toestemming geannuleerd door gebruiker."
        if (Test-Path -LiteralPath $tempLog) { Remove-Item -LiteralPath $tempLog -Force -ErrorAction SilentlyContinue }
      }
      finally {
        if (Test-Path -LiteralPath $tempScript) { Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue }
      }
      if ($PassThru) { return $resolvedPath }
      return
    }

    # 2. Laad de IIS WebAdministration module
    if (-not (Get-Module -Name WebAdministration -ListAvailable)) {
      throw "De PowerShell-module 'WebAdministration' is niet gevonden. Installeer 'IIS Management Scripts and Tools' via: Enable-WindowsOptionalFeature -Online -FeatureName IIS-ManagementScriptingTools"
    }
    Import-Module WebAdministration -ErrorAction Stop

    # 3. Bepaal de huidige worktree root en de hoofdrepository root via Git
    $revParseOutput = git --no-optional-locks -C $Path rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>$null
    if (-not $revParseOutput) {
      throw "Pad '$Path' bevindt zich niet in een Git-repository of worktree."
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

    Write-Host "`n=== Switch IIS naar Worktree: $(Split-Path -Leaf $currentRoot) ($projectName) ===" -ForegroundColor Cyan
    Write-Host "Doelmap: $currentRoot"

    # Helper om het exacte IIS PowerShell-itempad op te bouwen
    function Get-IisItemPath {
      param($app)
      $siteName = $app.ItemXPath.Split("`'")[1]
      $subPath = $app.Path.Trim('/').Replace('/', '\')
      if ($subPath) { "IIS:\Sites\$siteName\$subPath" } else { "IIS:\Sites\$siteName" }
    }

    # 4. Verzamel actieve IIS-applicaties en match doelpaden
    $iisApps = Get-WebApplication
    if (-not $iisApps) {
      Write-Warning "Geen IIS-webapplicaties gevonden op deze machine."
      return
    }

    $affectedAppPools = [System.Collections.Generic.HashSet[string]]::new()
    $updatedCount = 0

    # STRATEGIE A: Zoek webprojecten via launchSettings.json
    $launchSettingsFiles = Get-ChildItem -Path $currentRoot -Filter "launchSettings.json" -Recurse -Depth 4 -ErrorAction SilentlyContinue

    foreach ($file in $launchSettingsFiles) {
      try {
        $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
        $appUrl = $json.iisSettings.iis.applicationUrl
        if ($appUrl) {
          $uri = [System.Uri]$appUrl
          $expectedPath = $uri.AbsolutePath.TrimEnd('/')
          if (-not $expectedPath.StartsWith("/")) {
            $expectedPath = "/$expectedPath"
          }

          $projectDir = Split-Path -Parent (Split-Path -Parent $file.FullName)
          $matchedApp = $iisApps | Where-Object { $_.Path -eq $expectedPath }

          if ($matchedApp) {
            Write-Host "`nMatch gevonden via launchSettings.json voor '$expectedPath':" -ForegroundColor Yellow
            Write-Host "  Oud pad  : $($matchedApp.PhysicalPath)"
            Write-Host "  Nieuw pad: $projectDir" -ForegroundColor Green

            if ($PSCmdlet.ShouldProcess("IIS App '$expectedPath'", "PhysicalPath wijzigen naar '$projectDir'")) {
              $iisPath = Get-IisItemPath $matchedApp
              Set-ItemProperty $iisPath -Name physicalPath -Value $projectDir

              if ($matchedApp.applicationPool) {
                $null = $affectedAppPools.Add($matchedApp.applicationPool)
              }
              $updatedCount++
            }
          }
        }
      }
      catch { }
    }

    # STRATEGIE B: Bestaande IIS-applicaties matchen op hoofdprojectpad
    if ($updatedCount -eq 0) {
      Write-Host "`nGeen matches via launchSettings.json, scannen op bestaande IIS paden..." -ForegroundColor Cyan

      foreach ($app in $iisApps) {
        $currentAppPath = $app.PhysicalPath
        $parentOfApp = Split-Path -Parent $mainRepoRoot
        $repoPrefixPattern = "^" + [regex]::Escape($parentOfApp) + "[\\/]" + [regex]::Escape($projectName) + "(-[^\\/]+)?(?=[\\/]|$)"
        if ($currentAppPath -match $repoPrefixPattern) {
          $matchedWorktreeRoot = $Matches[0]
          $relativeSubPath = $currentAppPath.Substring($matchedWorktreeRoot.Length).TrimStart('\', '/')
          $newPhysicalPath = Join-Path $currentRoot $relativeSubPath
          if (Test-Path $newPhysicalPath) {
            Write-Host "`nBestaande IIS app '$($app.Path)' gekoppeld:" -ForegroundColor Yellow
            Write-Host "  Oud pad  : $currentAppPath"
            Write-Host "  Nieuw pad: $newPhysicalPath" -ForegroundColor Green

            if ($PSCmdlet.ShouldProcess("IIS App '$($app.Path)'", "PhysicalPath wijzigen naar '$newPhysicalPath'")) {
              $iisPath = Get-IisItemPath $app
              Set-ItemProperty $iisPath -Name physicalPath -Value $newPhysicalPath

              if ($app.applicationPool) {
                $null = $affectedAppPools.Add($app.applicationPool)
              }
              $updatedCount++
            }
          }
        }
      }
    }

    # 5. Herstart specifiek gekoppelde Application Pools
    if ($affectedAppPools.Count -gt 0) {
      Write-Host "`nRecyclen van gekoppelde Application Pools..." -ForegroundColor Cyan
      foreach ($pool in $affectedAppPools) {
        if ($PSCmdlet.ShouldProcess("Application Pool '$pool'", "Herstarten")) {
          Write-Host "  Herstarten Application Pool: $pool" -ForegroundColor Yellow
          Restart-WebAppPool -Name $pool -ErrorAction SilentlyContinue
        }
      }
    }

    if ($updatedCount -gt 0) {
      if ($PSCmdlet.ShouldProcess("Metadata iis-worktree.json", "Bijwerken naar '$currentRoot'")) {
        try {
          $state = [ordered]@{
            activeWorktree = $currentRoot
            folderName     = Split-Path -Leaf $currentRoot
            projectName    = $projectName
            lastSwitched   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            switchedBy     = $env:USERNAME
          }
          $state | ConvertTo-Json | Set-Content -Path (Join-Path $gitCommonDir "iis-worktree.json") -Force -ErrorAction SilentlyContinue
        } catch { }
      }

      Write-Host "`nSucces: $updatedCount IIS-applicatie(s) succesvol omgezet naar deze worktree!" -ForegroundColor Green
    } else {
      throw "Geen overeenkomende IIS-toepassingen gevonden voor dit project in $currentRoot."
    }

    if ($PassThru) {
      return $currentRoot
    }
  }
}

# Aliases voor snel typen
Set-Alias -Name switch-iis    -Value Switch-WorktreeIIS
Set-Alias -Name switch-iis-wt -Value Switch-WorktreeIIS
Set-Alias -Name set-iis-wt    -Value Switch-WorktreeIIS
