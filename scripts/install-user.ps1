[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [switch]$Force
)

$root = Split-Path -Parent $PSScriptRoot
$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate.ps1'
& $validator
if (-not $?) { throw 'Source validation failed; installation was not started.' }

$versionPath = Join-Path $root 'VERSION'
$kitVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()
$agentDestination = Join-Path $CodexHome 'agents'
$skillDestination = Join-Path $AgentsHome 'skills'
$receiptDirectory = Join-Path $AgentsHome 'codex-multi-agent'
$receiptPath = Join-Path $receiptDirectory 'install-receipt.json'
$backupSession = Join-Path (Join-Path $receiptDirectory 'backups') ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

function Get-FileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-OperationFiles {
  param([Parameter(Mandatory = $true)]$Operation)

  if ($Operation.Kind -eq 'agent') {
    return @(Get-Item -LiteralPath $Operation.Destination -ErrorAction Stop)
  }

  return @(Get-ChildItem -LiteralPath $Operation.Destination -File -Recurse -ErrorAction Stop)
}

function Test-ManagedDestination {
  param(
    [Parameter(Mandatory = $true)]$Operation,
    [Parameter(Mandatory = $true)][hashtable]$ReceiptEntries
  )

  $destinationItem = Get-Item -LiteralPath $Operation.Destination -Force
  if (($Operation.Kind -eq 'agent' -and $destinationItem.PSIsContainer) -or
      ($Operation.Kind -eq 'skill' -and -not $destinationItem.PSIsContainer)) {
    return $false
  }

  $files = @(Get-OperationFiles -Operation $Operation)
  if ($files.Count -eq 0) { return $false }

  foreach ($file in $files) {
    $entry = $ReceiptEntries[$file.FullName]
    if ($null -eq $entry -or (Get-FileSha256 -Path $file.FullName) -ne $entry) {
      return $false
    }
  }

  return $true
}

$operations = New-Object System.Collections.Generic.List[object]
Get-ChildItem -Path (Join-Path $root 'agents') -Filter '*.toml' -File | ForEach-Object {
  $operations.Add([PSCustomObject]@{
      Kind = 'agent'; Name = $_.Name; Source = $_.FullName
      Destination = Join-Path $agentDestination $_.Name; BackupRelative = Join-Path 'agents' $_.Name
    })
}
Get-ChildItem -Path (Join-Path $root 'skills') -Directory | ForEach-Object {
  $operations.Add([PSCustomObject]@{
      Kind = 'skill'; Name = $_.Name; Source = $_.FullName
      Destination = Join-Path $skillDestination $_.Name; BackupRelative = Join-Path 'skills' $_.Name
    })
}

$receiptEntries = @{}
if (Test-Path -LiteralPath $receiptPath) {
  try {
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -ErrorAction Stop
    foreach ($entry in @($receipt.files)) { $receiptEntries[$entry.path] = $entry.sha256 }
  } catch {
    Write-Warning "Could not read the existing installation receipt at $receiptPath. Existing files will be treated as conflicts."
  }
}

$conflicts = New-Object System.Collections.Generic.List[string]
foreach ($operation in $operations) {
  if (-not (Test-Path -LiteralPath $operation.Destination)) {
    Write-Host "[Create] $($operation.Kind) $($operation.Name)"
  } elseif (Test-ManagedDestination -Operation $operation -ReceiptEntries $receiptEntries) {
    Write-Host "[Update managed] $($operation.Kind) $($operation.Name)"
  } else {
    $conflicts.Add($operation.Destination)
    Write-Host "[Conflict] $($operation.Destination)"
  }
}

if ($conflicts.Count -gt 0 -and -not $Force) {
  throw "Installation stopped. Existing files are not owned by an unchanged Codex Team Kit installation. Review the listed conflicts, use -WhatIf to preview, or rerun with -Force to back them up before replacement."
}

foreach ($operation in $operations) {
  $destinationExists = Test-Path -LiteralPath $operation.Destination
  $action = if ($destinationExists) { 'Replace and back up' } else { 'Install' }
  if (-not $PSCmdlet.ShouldProcess($operation.Destination, "$action $($operation.Kind) $($operation.Name)")) { continue }

  $backupPath = $null
  if ($destinationExists) {
    $backupPath = Join-Path $backupSession $operation.BackupRelative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
    Move-Item -LiteralPath $operation.Destination -Destination $backupPath -ErrorAction Stop
  }

  try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $operation.Destination) | Out-Null
    Copy-Item -LiteralPath $operation.Source -Destination $operation.Destination -Recurse -Force -ErrorAction Stop
  } catch {
    if (Test-Path -LiteralPath $operation.Destination) {
      Remove-Item -LiteralPath $operation.Destination -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $backupPath -and (Test-Path -LiteralPath $backupPath)) {
      Move-Item -LiteralPath $backupPath -Destination $operation.Destination -ErrorAction SilentlyContinue
    }
    throw
  }
}

if ($WhatIfPreference) { return }

$installedFiles = New-Object System.Collections.Generic.List[object]
foreach ($operation in $operations) {
  if ($operation.Kind -eq 'agent') {
    $installedFiles.Add([PSCustomObject]@{ path = $operation.Destination; sha256 = Get-FileSha256 -Path $operation.Destination })
    continue
  }

  Get-ChildItem -LiteralPath $operation.Source -File -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($operation.Source.Length).TrimStart('\', '/')
    $destinationFile = Join-Path $operation.Destination $relativePath
    $installedFiles.Add([PSCustomObject]@{ path = $destinationFile; sha256 = Get-FileSha256 -Path $destinationFile })
  }
}

$receipt = [ordered]@{
  schemaVersion = 1
  kitVersion = $kitVersion
  installedAt = (Get-Date).ToUniversalTime().ToString('o')
  codexHome = $CodexHome
  agentsHome = $AgentsHome
  files = $installedFiles.ToArray()
}

if ($PSCmdlet.ShouldProcess($receiptPath, 'Write installation receipt')) {
  New-Item -ItemType Directory -Force -Path $receiptDirectory | Out-Null
  $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $receiptPath -Encoding utf8
}

Write-Host "Installed Codex Team Kit agents to $agentDestination"
Write-Host "Installed Skills to $skillDestination"
Write-Host "Installation receipt: $receiptPath"
if (Test-Path -LiteralPath $backupSession) { Write-Host "Backup: $backupSession" }
Write-Host "Optional: merge config\recommended-config.toml into $CodexHome\config.toml manually."
