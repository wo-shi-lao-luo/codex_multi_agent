# Smoke only the explicit runner/preflight surfaces; never launch the Board suite under unsupported Node.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$prefix = 'codex-task-board-runner-'
$temporary = Join-Path (Get-TestTemporaryParent) ($prefix + [Guid]::NewGuid().ToString('N'))
$shell = Get-TestPowerShell
try {
  [IO.Directory]::CreateDirectory($temporary) | Out-Null
  # Scenario: real-payload approval is missing, malformed or disagrees with the candidate bytes.
  # Expected: fail before deployment or even fixture creation; never infer approval from actual hashes.
  $fixtureParent = Join-Path $repo '_work/task-board/test-fixtures'
  $before = @(if (Test-Path -LiteralPath $fixtureParent) {
    Get-ChildItem -LiteralPath $fixtureParent -Directory -Filter 'p4-package-*' |
      Select-Object -ExpandProperty FullName | Sort-Object
  })
  foreach ($case in @(
    @{ Args = @(); Code = 'CANDIDATE_HASH_REQUIRED' },
    @{ Args = @('-ExpectedManifestSha256', 'invalid', '-ExpectedAppSha256', ('0' * 64));
      Code = 'CANDIDATE_HASH_REQUIRED' },
    @{ Args = @('-ExpectedManifestSha256', ('0' * 64), '-ExpectedAppSha256', ('0' * 64));
      Code = 'CANDIDATE_HASH_MISMATCH' }
  )) {
    $guard = Invoke-TestProcess -FilePath $shell -ArgumentList (@('-NoProfile', '-File',
      (Join-Path $repo 'tests/test-task-board-package.ps1'), '-CurrentPayload') + $case.Args)
    if ($guard.Exit -eq 0 -or -not ($guard.Out + $guard.Error).Contains($case.Code)) {
      throw "Candidate approval guard failed: $($guard.Out) $($guard.Error)"
    }
    $after = @(if (Test-Path -LiteralPath $fixtureParent) {
      Get-ChildItem -LiteralPath $fixtureParent -Directory -Filter 'p4-package-*' |
        Select-Object -ExpandProperty FullName | Sort-Object
    })
    if (($before -join "`n") -cne ($after -join "`n")) {
      throw 'Rejected candidate approval created a package fixture or fake deployment homes.'
    }
  }
  $node = Join-Path $temporary 'missing-node.exe'
  # Scenario: explicitly selected Board suite receives an explicitly missing selected executable.
  # Expected: routed preflight reports NODE_MISSING, never a parameter-binding/unknown-suite error.
  $selected = Invoke-TestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    (Join-Path $repo 'scripts/test.ps1'), '-Suite', 'task-board', '-TaskBoardNodePath', $node)
  if ($selected.Exit -eq 0 -or -not ($selected.Out + $selected.Error).Contains('NODE_MISSING')) {
    throw "Opt-in runtime preflight was not honored: $($selected.Out) $($selected.Error)"
  }
  # Scenario: optional setup dependency indication sees a missing selected executable.
  # Expected: informational success JSON, no Codex-home/platform/install precondition and no files created.
  $missing = Join-Path $temporary 'missing-node.exe'
  $setup = Invoke-TestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    (Join-Path $repo 'scripts/setup-user.ps1'), '-Action', 'BoardDoctor', '-Json', '-BoardNodePath', $missing)
  $report = $setup.Out | ConvertFrom-Json
  if ($setup.Exit -ne 0 -or $report.available -ne $false -or
      $report.reasonCode -ne 'NODE_MISSING') {
    throw "Missing optional dependency indication failed: $($setup.Out) $($setup.Error)"
  }
  # Scenario: an existing selected documentation-independent suite runs with no Board runtime request.
  # Expected: unchanged selected registry semantics, exactly that suite recorded (no opt-in expansion).
  $resultPath = Join-Path $temporary 'selected-results.json'
  $existing = Invoke-TestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    (Join-Path $repo 'scripts/test.ps1'), '-Suite', 'stage-verification', '-ResultPath', $resultPath)
  if ($existing.Exit -ne 0) { throw "Existing selected suite failed: $($existing.Out) $($existing.Error)" }
  $results = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
  if (@($results.checks).Count -ne 1 -or $results.checks[0].Suite -ne 'stage-verification') {
    throw 'Explicit old-suite selection unexpectedly expanded into Board tests.'
  }
  Write-Output 'Task-board registry/preflight smoke passed; no Board tests ran under unavailable runtime.'
} finally { Remove-TestSandbox -Path $temporary -Prefix $prefix }
