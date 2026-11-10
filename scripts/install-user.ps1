# Full installation orchestrator: prepare verified dependencies before the offline payload transaction.
# The selected source contributes data only; this trusted entrypoint never runs its scripts.
# install-receipt.json remains owned by deploy-user.ps1; this wrapper never removes payload files.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$GitRef,
  [string]$RuntimeArchivePath,
  [switch]$Offline,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/team-core/scripts/board-runtime.ps1')

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

# Compare recursively with exact scalar values and key sets, independent of JSON property order.
function Test-RuntimePin($Selected, $Trusted) {
  if ($Selected -is [Collections.IDictionary] -and $Trusted -is [Collections.IDictionary]) {
    if ($Selected.Count -ne $Trusted.Count) { return $false }
    foreach ($key in $Trusted.Keys) {
      if (-not $Selected.Contains($key) -or -not (Test-RuntimePin $Selected[$key] $Trusted[$key])) { return $false }
    }
    return $true
  }
  return $Selected -ceq $Trusted
}

$committed = $false
$dependency = $null
try {
  $arguments = @('-Action','Deploy','-SourceRoot',$SourceRoot,'-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome)
  if ($GitRef) { $arguments += @('-GitRef',$GitRef) }
  if ($Force) { $arguments += '-Force' }
  $preview = Invoke-TrustedDeployment ($arguments + '-WhatIf')
  if ($preview.boardRequired -and -not (Test-RuntimePin $preview.runtimeSelection (Get-BoardRuntimeLock))) {
    throw 'RUNTIME_LOCK: Selected Board package has no supported pinned runtime contract; use payload-only Deploy for historical packages.'
  }
  if (-not $PSCmdlet.ShouldProcess($AgentsHome, 'Prepare dependencies and install the full Kit')) {
    $preview.dependency = @{required=$preview.boardRequired; action='resolve-or-provision'; networkAllowed=(-not $Offline)}
    $preview.installationComplete = $false
    $preview.filesCommitted = $false
    $preview | ConvertTo-Json -Depth 15
    exit 0
  }
  if ($preview.boardRequired) {
    $dependency = Ensure-BoardRuntime -AgentsHome $AgentsHome `
      -RuntimeArchivePath $RuntimeArchivePath -Offline:$Offline
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
  if ($preview.boardRequired) {
    $launcher = Join-Path $AgentsHome 'skills/team-core/scripts/task-board.ps1'
    $reply = Invoke-BoardRuntimeProcess (Get-Process -Id $PID).Path @('-NoProfile','-File',
      $launcher,'-AgentsHome',$AgentsHome,'runtime-doctor')
    if (($reply.schemaVersion -isnot [long] -and $reply.schemaVersion -isnot [int]) -or
        $reply.schemaVersion -ne 1 -or $reply.operation -cne 'runtime-doctor' -or
        $reply.ok -isnot [bool] -or $reply.ok -cne $true) {
      throw 'RUNTIME_PROTOCOL: Installed launcher returned an invalid response.'
    }
    Assert-BoardRuntimeVersions $reply.result
    $dependency.diagnostic = $reply.result
  }
  $deployment.installationComplete = $true
  $deployment.filesCommitted = $true
  $deployment.dependency = $dependency
  $deployment | ConvertTo-Json -Depth 15
  try {
    . (Join-Path $PSScriptRoot 'optional-capabilities.ps1')
    Write-Information (Get-OptionalCapabilityGuidance) -InformationAction Continue
  } catch {
    # Optional advice cannot turn a verified committed installation into failure.
  }
} catch {
  @{action='failed'; installationComplete=$false; filesCommitted=$committed; dependency=$dependency;
    reason=$_.Exception.Message} | ConvertTo-Json -Depth 15
  exit 1
}
