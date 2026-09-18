[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'scripts\install-user.ps1'
$updater = Join-Path $root 'scripts\update-user.ps1'
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = "codex-multi-agent-install-test-" + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName
$codexHome = Join-Path $testRoot 'codex'
$agentsHome = Join-Path $testRoot 'agents-home'

function Assert-Condition {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Get-TreeFingerprint {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  return ((Get-ChildItem -LiteralPath $Path -File -Recurse | ForEach-Object {
      $relative = $_.FullName.Substring($Path.Length).TrimStart([char]'\', [char]'/' )
      "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
    } | Sort-Object) -join "`n")
}

function Get-PackageFileMap {
  $files = @{}
  Get-ChildItem -LiteralPath (Join-Path $root 'agents') -Filter '*.toml' -File | ForEach-Object {
    $files["codex/agents/$($_.Name)"] = $_.FullName
  }
  Get-ChildItem -LiteralPath (Join-Path $root 'skills') -File -Recurse | ForEach-Object {
    $skillsRoot = Join-Path $root 'skills'
    $relative = $_.FullName.Substring($skillsRoot.Length).TrimStart([char]'\', [char]'/' ) -replace '\\', '/'
    $files["agents-home/skills/$relative"] = $_.FullName
  }
  return $files
}

function Get-InstalledPath {
  param([Parameter(Mandatory = $true)][string]$PackageRelativePath)
  return Join-Path $testRoot ($PackageRelativePath.Replace([char]'/', [System.IO.Path]::DirectorySeparatorChar))
}

try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  & $installer -CodexHome $codexHome -AgentsHome $agentsHome

  $receiptPath = Join-Path $agentsHome 'codex-multi-agent\\install-receipt.json'
  Assert-Condition (Test-Path -LiteralPath $receiptPath) 'Initial installation did not create a receipt.'

  $packageFiles = Get-PackageFileMap
  foreach ($packageRelativePath in $packageFiles.Keys) {
    $sourcePath = $packageFiles[$packageRelativePath]
    $installedPath = Get-InstalledPath -PackageRelativePath $packageRelativePath
    Assert-Condition (Test-Path -LiteralPath $installedPath) "Initial installation did not include $packageRelativePath."
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $installedHash = (Get-FileHash -LiteralPath $installedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Condition ($sourceHash -eq $installedHash) "Installed file does not match source: $packageRelativePath."
  }

  $expectedSkillNames = @(Get-ChildItem -LiteralPath (Join-Path $root 'skills') -Directory | Select-Object -ExpandProperty Name | Sort-Object)
  $installedSkillNames = @(Get-ChildItem -LiteralPath (Join-Path $agentsHome 'skills') -Directory | Select-Object -ExpandProperty Name | Sort-Object)
  Assert-Condition (($expectedSkillNames -join '|') -eq ($installedSkillNames -join '|')) 'Installed Skill directories do not exactly match the source package.'
  foreach ($retiredSkillName in 'sql-safety', 'test-strategy') {
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $agentsHome "skills\\$retiredSkillName"))) "Initial installation unexpectedly included retired skill $retiredSkillName."
  }

  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -ErrorAction Stop
  Assert-Condition ($receipt.schemaVersion -eq 1) 'Installation receipt has an unexpected schema version.'
  Assert-Condition ($receipt.kitVersion -eq (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()) 'Installation receipt has an unexpected kit version.'
  Assert-Condition (@($receipt.files).Count -eq $packageFiles.Count) 'Installation receipt does not cover every packaged file exactly once.'
  foreach ($packageRelativePath in $packageFiles.Keys) {
    $installedPath = Get-InstalledPath -PackageRelativePath $packageRelativePath
    $receiptEntry = @($receipt.files | Where-Object { $_.path -eq $installedPath })
    Assert-Condition ($receiptEntry.Count -eq 1) "Installation receipt does not contain exactly one entry for $packageRelativePath."
    $installedHash = (Get-FileHash -LiteralPath $installedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Condition ($receiptEntry[0].sha256 -eq $installedHash) "Installation receipt hash is incorrect for $packageRelativePath."
  }

  $treeBeforeWhatIf = Get-TreeFingerprint -Path $testRoot
  & $updater -CodexHome $codexHome -AgentsHome $agentsHome -WhatIf | Out-Null
  $treeAfterWhatIf = Get-TreeFingerprint -Path $testRoot
  Assert-Condition ($treeBeforeWhatIf -eq $treeAfterWhatIf) 'Update -WhatIf changed files in the isolated installation.'

  & $updater -CodexHome $codexHome -AgentsHome $agentsHome
  $receiptAfterManagedUpdate = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -ErrorAction Stop
  Assert-Condition (@($receiptAfterManagedUpdate.files).Count -eq $packageFiles.Count) 'Managed update did not preserve a complete installation receipt.'

  $agentPath = Join-Path $codexHome 'agents\\team-architect.toml'
  Set-Content -LiteralPath $agentPath -Value '# user customization' -Encoding utf8
  $conflictDetected = $false
  try { & $updater -CodexHome $codexHome -AgentsHome $agentsHome -ErrorAction Stop } catch { $conflictDetected = $true }
  Assert-Condition $conflictDetected 'Modified installed file was not detected as a conflict.'
  Assert-Condition ((Get-Content -LiteralPath $agentPath -Raw) -match 'user customization') 'Conflict handling changed the user-modified file.'

  & $updater -CodexHome $codexHome -AgentsHome $agentsHome -Force
  $expectedAgent = Get-Content -LiteralPath (Join-Path $root 'agents\\team-architect.toml') -Raw
  Assert-Condition ((Get-Content -LiteralPath $agentPath -Raw) -eq $expectedAgent) '-Force did not replace the conflicting agent.'
  $customizedBackups = @(Get-ChildItem -LiteralPath (Join-Path $agentsHome 'codex-multi-agent\\backups') -Filter 'team-architect.toml' -File -Recurse | Where-Object {
      (Get-Content -LiteralPath $_.FullName -Raw) -match 'user customization'
    })
  Assert-Condition ($customizedBackups.Count -gt 0) '-Force did not preserve a backup of the conflicting agent.'

  Write-Host 'Install-user tests passed.'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedTestRoot)).TrimEnd([char]'\', [char]'/' )
  $normalizedTemporaryParent = $temporaryParent.TrimEnd([char]'\', [char]'/' )
  if ($resolvedParent -ne $normalizedTemporaryParent -or -not ([System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('codex-multi-agent-install-test-'))) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedTestRoot)) "Test cleanup left an unexpected directory: $resolvedTestRoot"
  Write-Host 'Isolated test directory removed.'
}
