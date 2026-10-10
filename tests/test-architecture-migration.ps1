# Exercise migration-guidance distribution and direct discovery at the public CLI.
# Isolated package mutations do not establish semantic or native workflow quality.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$root = Split-Path -Parent $PSScriptRoot
$shell = (Get-Process -Id $PID).Path
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent (
  'codex-multi-agent-architecture-migration-test-' + [guid]::NewGuid().ToString('N')
)
$reference = 'skills/team-core/references/architecture-migration.md'
$routes = @(
  foreach ($skill in @(
    'team-core', 'team-dev', 'team-plan', 'team-review', 'code-review',
    'testing-engineering', 'ai-engineering', 'backend-engineering'
  )) {
    @{
      path = "skills/$skill/SKILL.md"
      target = if ($skill -eq 'team-core') {
        'references/architecture-migration.md'
      } else { '../team-core/references/architecture-migration.md' }
    }
  }
  foreach ($name in @(
    'execution-contract', 'project-blueprint', 'test-acceptance-contract',
    'handoff-format', 'ai-capability-contract'
  )) {
    @{
      path = "skills/team-core/references/$name.md"
      target = 'architecture-migration.md'
    }
  }
)

function Assert-Condition {
  # Report the violated observable expectation without repairing test inputs.
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Get-Fingerprint {
  # Include relative paths and bytes so additions, removals and edits are observed.
  param([string]$Directory)
  return Get-TestFingerprint -Root $Directory
}

function Invoke-Validation {
  # Observe the copied CLI exit and retain both output streams for diagnostics.
  $before = Get-Fingerprint $testRoot
  $result = Invoke-TestProcess -FilePath $shell -ArgumentList @(
    '-NoProfile', '-File', (Join-Path $testRoot 'scripts/validate.ps1')
  )
  Assert-Condition ((Get-Fingerprint $testRoot) -eq $before) 'Validator mutated fixture.'
  return [pscustomobject]@{
    Passed = ($result.Exit -eq 0)
    Output = ($result.Out + $result.Error)
  }
}

$sourceFiles = @{}
try {
  Copy-TestPackage -SourceRoot $root -DestinationRoot $testRoot `
    -Profile PublicDocs -IncludeConfig $true
  # Preserve the independent final source-byte proof for the distributable roots.
  foreach ($directory in @('agents', 'skills', 'scripts', 'config')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root $directory) -File -Recurse) {
      $sourceFiles[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName).Hash
    }
  }

  # AM-01: finalized guidance and every intended direct route exist before mutation.
  # Expected: admit the complete copied package with no file changes.
  $referencePath = Join-Path $testRoot $reference
  Assert-Condition (Test-Path -LiteralPath $referencePath -PathType Leaf) (
    'Missing finalized migration reference; setup failure is not intended TDD Red.'
  )
  $referenceText = [Text.UTF8Encoding]::new($false, $true).GetString(
    [IO.File]::ReadAllBytes($referencePath)
  )
  Assert-Condition (-not [string]::IsNullOrWhiteSpace($referenceText)) (
    'Finalized migration reference must contain UTF-8 guidance before mutation.'
  )
  foreach ($route in $routes) {
    $content = Get-Content -LiteralPath (Join-Path $testRoot $route.path) -Raw
    Assert-Condition ($content.Contains("]($($route.target))")) (
      "Missing finalized route: $($route.path); setup failure is not intended TDD Red."
    )
  }
  $originalFingerprint = Get-Fingerprint $testRoot
  $baseline = Invoke-Validation
  Assert-Condition $baseline.Passed "Complete migration source rejected: $($baseline.Output)"

  # AM-03: intended migration guidance is replaced by another valid existing link.
  # Expected: reject every lost direct route with its own specific diagnostic.
  foreach ($route in $routes) {
    $path = Join-Path $testRoot $route.path
    $original = [IO.File]::ReadAllBytes($path)
    try {
      $replacement = if ($route.path -eq 'skills/team-core/SKILL.md') {
        'references/code-comments.md'
      } elseif ($route.path.EndsWith('/SKILL.md')) {
        '../team-core/references/code-comments.md'
      } else { 'code-comments.md' }
      $content = Get-Content -LiteralPath $path -Raw
      [IO.File]::WriteAllText($path, $content.Replace(
        "]($($route.target))", "]($replacement)"
      ))
      $result = Invoke-Validation
      Assert-Condition (-not $result.Passed) (
        "Validator accepted lost migration route: $($route.path)"
      )
      $diagnostic = "$($route.path) must link to $($route.target)"
      Assert-Condition ($result.Output.Contains($diagnostic)) (
        "Lost-route diagnostic missing: $diagnostic; $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($path, $original)
    }
    Write-Host "Rejected lost migration route: $($route.path)"
  }

  # AM-02: the packaged shared reference is missing or contains only whitespace.
  # Expected: both states fail with the dedicated resource diagnostic, not just links.
  $referenceBytes = [IO.File]::ReadAllBytes($referencePath)
  foreach ($state in @('missing', 'empty')) {
    try {
      if ($state -eq 'missing') {
        Remove-Item -LiteralPath $referencePath
        $diagnostic = "Missing architecture migration resource: $reference"
      } else {
        [IO.File]::WriteAllText($referencePath, " `r`n")
        $diagnostic = "Empty architecture migration resource: $reference"
      }
      $result = Invoke-Validation
      Assert-Condition (-not $result.Passed) "Validator accepted $state migration reference."
      Assert-Condition ($result.Output.Contains($diagnostic)) (
        "Resource diagnostic missing: $diagnostic; $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($referencePath, $referenceBytes)
    }
    Write-Host "Rejected $state migration reference."
  }

  # AM-04: every rejected fixture mutation is restored byte-exactly.
  # Expected: the restored valid package passes and source package bytes stay intact.
  $restored = Invoke-Validation
  Assert-Condition $restored.Passed "Restored migration source rejected: $($restored.Output)"
  Assert-Condition ((Get-Fingerprint $testRoot) -eq $originalFingerprint) (
    'Fixture was not byte-exactly restored.'
  )
  Write-Host 'Architecture migration package/discovery tests passed; native behavior untested.'
} finally {
  # AM-04: success and failure must preserve source and remove only the owned fixture.
  # Expected: unchanged source hashes and validated exact OS-temp child removed.
  $sourceChanged = @($sourceFiles.Keys | Where-Object {
    -not (Test-Path -LiteralPath $_ -PathType Leaf) -or
      (Get-FileHash -LiteralPath $_).Hash -ne $sourceFiles[$_]
  })
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  try {
    Remove-TestSandbox -Path $testRoot -Prefix 'codex-multi-agent-architecture-migration-test-'
  } catch {
    throw "Refusing cleanup outside owned fixture: $resolvedRoot. $($_.Exception.Message)"
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedRoot)) 'Fixture cleanup failed.'
  Assert-Condition ($sourceChanged.Count -eq 0) (
    "Source package changed during isolated tests: $($sourceChanged -join ', ')"
  )
  Write-Host 'Owned migration fixture removed; source package preserved.'
}
