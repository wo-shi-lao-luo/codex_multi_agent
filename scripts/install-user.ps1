# Validate current source, then use the precise transaction engine for upgrade/downgrade.
# install-receipt.json is managed by deploy-user.ps1; this wrapper never removes files itself.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate.ps1')
if (-not $?) { throw 'Source validation failed; installation was not started.' }
$arguments = @{ Action='Deploy'; SourceRoot=$root; CodexHome=$CodexHome; AgentsHome=$AgentsHome }
if ($Force) { $arguments.Force=$true }
if ($WhatIfPreference) { $arguments.WhatIf=$true }
& (Join-Path $PSScriptRoot 'deploy-user.ps1') @arguments
if (-not $?) { throw 'Deployment failed.' }
