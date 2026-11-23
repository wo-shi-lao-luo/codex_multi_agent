# Full installation orchestrator: pin the selected source before the offline payload transaction.
# The selected source contributes data only; this trusted entrypoint never runs its scripts.
# install-receipt.json remains owned by deploy-user.ps1; this wrapper never removes payload files.
# Pass -EnableTeamGuidance only with consent to add guidance to the selected Codex home.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$GitRef,
  [switch]$EnableTeamGuidance,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
# Child isolation prevents a transaction-engine exit from skipping orchestration checks.
# Parse only the final JSON object; ShouldProcess preview text is not part of the wire.
function Invoke-TrustedDeployment([string[]]$Arguments) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = (Get-Process -Id $PID).Path
  $info.UseShellExecute = $false
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($value in @('-NoLogo','-NoProfile','-NonInteractive','-File',
      (Join-Path $PSScriptRoot 'deploy-user.ps1')) + $Arguments) { $info.ArgumentList.Add($value) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    # The trusted offline engine performs finite inventory and filesystem work.
    # Large healthy transactions must finish rather than be killed by a universal deadline.
    $process.WaitForExit()
    $output = $stdout.GetAwaiter().GetResult()
    $errorText = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
      # Preserve named engine failure categories without exposing raw receipts or child output.
      $category = [regex]::Match($errorText, '\b[A-Z][A-Z_]{2,40}:').Value
      if (-not $category) { $category = 'DEPLOYMENT:' }
      throw "$category Trusted transaction failed; inspect selected source and installation status."
    }
    $starts = [regex]::Matches($output, '(?m)^\{')
    for ($index=$starts.Count-1; $index -ge 0; $index--) {
      try { return $output.Substring($starts[$index].Index) | ConvertFrom-Json -AsHashtable } catch { }
    }
    throw 'DEPLOYMENT: Invalid transaction response.'
  } finally { $process.Dispose() }
}

$committed = $false
try {
  # Preserve validation for the trusted checkout. Other selected sources are read as data.
  $trustedRoot = Split-Path -Parent $PSScriptRoot
  if (-not $GitRef -and [IO.Path]::GetFullPath($SourceRoot) -ceq $trustedRoot) {
    & (Join-Path $PSScriptRoot 'validate.ps1')
    if (-not $?) { throw 'PACKAGE: Trusted checkout validation failed.' }
  }
  $arguments = @('-Action','Deploy','-SourceRoot',$SourceRoot,'-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome)
  if ($GitRef) { $arguments += @('-GitRef',$GitRef) }
  if ($Force) { $arguments += '-Force' }
  $preview = Invoke-TrustedDeployment ($arguments + '-WhatIf')
  if ($EnableTeamGuidance) {
    if (-not ($preview.operations | Where-Object { $_.unit -ceq 'skills/team' -and $_.operation -cin @('install','replace') })) {
      throw 'TEAM_GUIDANCE_SKILL: The selected source does not install the Team skill.'
    }
    $guidanceScript = Join-Path $PSScriptRoot 'enable-team-guidance.ps1'
    $preview.teamGuidance = & $guidanceScript -CodexHome $CodexHome -AgentsHome $AgentsHome -WhatIf
  }
  if (-not $PSCmdlet.ShouldProcess($AgentsHome, 'Install the full Kit')) {
    $preview.installationComplete = $false
    $preview.filesCommitted = $false
    $preview | ConvertTo-Json -Depth 15
    exit 0
  }
  # A moving Git ref is resolved once; mutable directories also pin the complete source contract.
  if ($GitRef) {
    $arguments = @('-Action','Deploy','-SourceRoot',$SourceRoot,'-GitRef',$preview.source.commit,
      '-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome)
    if ($Force) { $arguments += '-Force' }
  }
  $deployment = Invoke-TrustedDeployment ($arguments + @(
    '-ExpectedPackageDigest',$preview.packageDigest,
    '-ExpectedSourceContractDigest',$preview.sourceContractDigest))
  if ($deployment.action -cne 'deployed') { throw 'DEPLOYMENT: Payload was not committed.' }
  $committed = $true
  $verified = Invoke-TrustedDeployment @('-Action','Verify','-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome)
  if ($verified.valid -cne $true) { throw 'DEPLOYMENT: Installed receipt verification failed.' }
  $deployment.installationComplete = $true
  $deployment.filesCommitted = $true
  if ($EnableTeamGuidance) {
    $deployment.teamGuidance = & $guidanceScript -CodexHome $CodexHome -AgentsHome $AgentsHome -Confirm:$false
  }
  $deployment | ConvertTo-Json -Depth 15
  try {
    . (Join-Path $PSScriptRoot 'optional-capabilities.ps1')
    Write-Information (Get-OptionalCapabilityGuidance) -InformationAction Continue
  } catch {
    # Optional advice cannot turn a verified committed installation into failure.
  }
} catch {
  @{action='failed'; installationComplete=$false; filesCommitted=$committed;
    reason=$_.Exception.Message} | ConvertTo-Json -Depth 15
  exit 1
}
