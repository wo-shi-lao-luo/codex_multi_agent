[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'install-user.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
  throw "Cannot update because the installer is missing: $installer"
}

$arguments = @{
  CodexHome = $CodexHome
  AgentsHome = $AgentsHome
}
if ($Force) { $arguments.Force = $true }
if ($WhatIfPreference) { $arguments.WhatIf = $true }

& $installer @arguments
if (-not $?) { throw 'Update failed before the installer completed.' }
