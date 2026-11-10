# Verify real concurrent feedback writers against an isolated store, never user homes.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$repository = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $repository 'skills/team-core/scripts/feedback-runtime.ps1'
$parent = Get-TestTemporaryParent
$fixture = Join-Path $parent ('codex-feedback-concurrency-' + [guid]::NewGuid().ToString('N'))
$children = [Collections.Generic.List[object]]::new()
try {
  $null = New-Item -ItemType Directory -Path $fixture
  $store = Join-Path $fixture 'store'
  $inputPath = Join-Path $fixture 'input.json'
  $startPath = Join-Path $fixture 'start'
  @{
    schemaVersion = 1; workflow = 'team-review'; objective = 'Concurrent fixture'
    projectPathDigest = 'isolated-fixture'; acceptanceChecks = @(); verification = @()
    status = 'completed_with_risk'; rework = @{count = 0; reasons = @()}
    remainingRisks = @('Fixture risk')
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inputPath
  $seed = & $runtime -Action Record -InputPath $inputPath -FeedbackHome $store -Confirm:$false |
    Out-String | ConvertFrom-Json
  $candidateFile = @(Get-ChildItem -LiteralPath (Join-Path $store 'feedback/candidates') -File)[0]
  $candidateId = (Get-Content -LiteralPath $candidateFile.FullName -Raw | ConvertFrom-Json).id

  # Scenario: six independent sessions record the same candidate simultaneously.
  # Expected: all 48 operations finish and every run is retained exactly once in aggregation.
  for ($index = 0; $index -lt 6; $index++) {
    $scriptText = @'
$ErrorActionPreference = 'Stop'
$arguments = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__INPUT__')) | ConvertFrom-Json
$deadline = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path -LiteralPath $arguments.start)) {
  if ($deadline.Elapsed.TotalSeconds -gt 30) { throw 'Fixture start barrier timed out.' }
  Start-Sleep -Milliseconds 10
}
1..8 | ForEach-Object {
  & $arguments.runtime -Action Record -InputPath $arguments.input -FeedbackHome $arguments.store -Confirm:$false | Out-Null
}
'@
    $argumentsJson = @{runtime=$runtime;input=$inputPath;store=$store;start=$startPath} | ConvertTo-Json -Compress
    $scriptText = $scriptText.Replace('__INPUT__', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($argumentsJson)))
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Get-TestPowerShell
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile', '-NonInteractive', '-EncodedCommand',
      [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) {
      $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    $null = $process.Start()
    $children.Add(@{process=$process;output=$process.StandardOutput.ReadToEndAsync();errors=$process.StandardError.ReadToEndAsync()})
  }
  [IO.File]::WriteAllText($startPath, 'start')
  foreach ($child in $children) {
    if (-not $child.process.WaitForExit(60000)) { throw 'Owned feedback fixture child timed out.' }
    $null = $child.output.GetAwaiter().GetResult()
    $errors = $child.errors.GetAwaiter().GetResult()
    if ($child.process.ExitCode -ne 0) { throw "Concurrent writer failed: $errors" }
  }
  $runs = @(Get-ChildItem -LiteralPath (Join-Path $store 'runs') -File -Filter '*.json')
  $candidate = Get-Content -LiteralPath $candidateFile.FullName -Raw | ConvertFrom-Json
  if ($runs.Count -ne 49 -or $candidate.count -ne 49 -or
      @($candidate.runIds).Count -ne 49 -or @($candidate.runIds | Sort-Object -Unique).Count -ne 49) {
    throw "Concurrent observations lost: runs=$($runs.Count), count=$($candidate.count), linked=$(@($candidate.runIds).Count)."
  }
  $recordIds = @($runs | ForEach-Object { (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json).id })
  if (@(Compare-Object $recordIds @($candidate.runIds)).Count) { throw 'Candidate references differ from retained runs.' }

  # Scenario: a user confirms a candidate, then later workflows record more evidence.
  # Expected: the explicit state survives aggregation, and maintenance shares the same safe store.
  & $runtime -Action SetCandidateState -FeedbackHome $store -CandidateId $candidateId -CandidateState confirmed -Confirm:$false | Out-Null
  & $runtime -Action Record -InputPath $inputPath -FeedbackHome $store -Confirm:$false | Out-Null
  & $runtime -Action Maintain -FeedbackHome $store -Confirm:$false | Out-Null
  $candidate = Get-Content -LiteralPath $candidateFile.FullName -Raw | ConvertFrom-Json
  if ($candidate.state -ne 'confirmed' -or $candidate.count -ne 50) { throw 'Confirmation state or follow-up observation lost.' }

  # Scenario: malformed existing candidate data makes a locked action fail.
  # Expected: failure is reported, the handle is released, and a later repaired store works.
  $savedCandidate = [IO.File]::ReadAllBytes($candidateFile.FullName)
  [IO.File]::WriteAllText($candidateFile.FullName, '{invalid-json')
  $rejected = $false
  try {
    & $runtime -Action Record -InputPath $inputPath -FeedbackHome $store -Confirm:$false | Out-Null
  } catch { $rejected = $true }
  if (-not $rejected) { throw 'Corrupt candidate was silently accepted.' }
  [IO.File]::WriteAllBytes($candidateFile.FullName, $savedCandidate)
  & $runtime -Action Record -InputPath $inputPath -FeedbackHome $store -Confirm:$false | Out-Null
  $candidate = Get-Content -LiteralPath $candidateFile.FullName -Raw | ConvertFrom-Json
  if ($candidate.state -ne 'confirmed' -or $candidate.count -ne 51) { throw 'Failed action leaked its lock or changed explicit state.' }
  Write-Host 'Feedback concurrency tests passed: 48 concurrent writes, exact run links, retained confirmation.'
} finally {
  foreach ($child in $children) {
    if (-not $child.process.HasExited) { $child.process.Kill($true); $child.process.WaitForExit() }
    $child.process.Dispose()
  }
  $absolute = [IO.Path]::GetFullPath($fixture)
  if ([IO.Path]::GetDirectoryName($absolute) -ne $parent -or
      -not ([IO.Path]::GetFileName($absolute).StartsWith('codex-feedback-concurrency-'))) {
    throw 'Refusing unexpected fixture cleanup path.'
  }
  if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
  if (Test-Path -LiteralPath $absolute) { throw 'Feedback fixture cleanup failed.' }
  Write-Host 'Isolated feedback concurrency fixture removed.'
}
