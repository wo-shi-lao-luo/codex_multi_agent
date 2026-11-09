# Exercise the real validator's Markdown source boundary using a complete disposable package copy.
# Local snapshots never become documentation sources; official and near-match paths stay checked.
#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$sourceRoot = Split-Path -Parent $PSScriptRoot
$prefix = 'codex-validation-links-'
$testRoot = Join-Path (Get-TestTemporaryParent) ($prefix + [Guid]::NewGuid().ToString('N'))
$validator = Join-Path $testRoot 'scripts/validate.ps1'
$script:validationRuns = 0

function Assert-LinkCondition {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

# Copy current versionable working bytes, including the actual bound Node payload/source and attrs.
# Git is read only at the source: no .git directory, clone, index or global configuration is copied.
function Copy-VersionableValidationFixture {
  $listed = Invoke-TestProcess -FilePath 'git' -ArgumentList @(
    '-C', $sourceRoot, '-c', 'core.quotepath=false', 'ls-files',
    '--cached', '--others', '--exclude-standard'
  )
  Assert-LinkCondition ($listed.Exit -eq 0) "Cannot enumerate current versionable source: $($listed.Error)"
  $files = @($listed.Out -split '\r?\n' | Where-Object { $_ })
  Assert-LinkCondition ($files.Count -gt 0) 'Versionable package inventory is empty.'
  foreach ($relative in $files) {
    $from = Resolve-TeamContainedPath $sourceRoot $relative
    $to = Resolve-TeamContainedPath $testRoot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to)) | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Force
  }
  foreach ($required in @('.gitattributes', 'packages/task-board/package.json',
    'scripts/build-task-board.mjs', 'skills/team-core/runtime/task-board/manifest.json')) {
    Assert-LinkCondition (Test-Path -LiteralPath (Join-Path $testRoot $required) -PathType Leaf) `
      "Complete current package fixture omitted $required"
  }
}

# Write an ordinary Markdown link fixture; restoring it uses a real versioned target, not a dummy file.
function Set-LinkProbe {
  param([string]$Relative, [string]$MissingTarget)
  $path = Resolve-TeamContainedPath $testRoot $Relative
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
  $target = if ($MissingTarget) { $MissingTarget } else {
    [IO.Path]::GetRelativePath([IO.Path]::GetDirectoryName($path), (Join-Path $testRoot 'VERSION')).Replace('\', '/')
  }
  [IO.File]::WriteAllText($path, "[Boundary probe]($target)`n", [Text.UTF8Encoding]::new($false))
}

# Invoke the actual full validator in a noGit child context, retaining diagnostics for precise oracles.
function Invoke-LinkValidator {
  $script:validationRuns++
  if ($script:validationRuns -gt 5) { throw 'Link-boundary suite exceeded its five-call contract.' }
  return Invoke-TestProcess -FilePath (Get-TestPowerShell) -ArgumentList @(
    '-NoLogo', '-NoProfile', '-File', $validator
  ) -Environment @{ GIT_CEILING_DIRECTORIES = (Get-TestTemporaryParent) }
}

try {
  [IO.Directory]::CreateDirectory($testRoot) | Out-Null
  Copy-VersionableValidationFixture
  # Scenario 1: every exact repository-local artifact/metadata tree contains a stale link.
  # Expected: baseline passes without Git or weakening the remaining public Markdown link checks.
  foreach ($scope in @('_work', 'backlog', 'docs/superpowers', 'docs/verification',
    'docs/governance/reviews', 'openspec/.team-recovery', '.git', '.hg', '.svn')) {
    Set-LinkProbe "$scope/nested/stale.md" 'missing-local-snapshot-target.md'
  }
  $baseline = Invoke-LinkValidator
  Assert-LinkCondition ($baseline.Exit -eq 0) `
    "Local-only Markdown must not become validator input. $($baseline.Out) $($baseline.Error)"

  # Scenario 2: an ordinary public document contains a broken link.
  # Expected: the full validator fails and names that exact missing destination.
  Set-LinkProbe 'docs/validation-public-probe.md' 'missing-public-target.md'
  $public = Invoke-LinkValidator
  Assert-LinkCondition ($public.Exit -ne 0 -and ($public.Out + $public.Error).Contains('missing-public-target.md')) `
    'Public Markdown broken link was not rejected with the named target.'
  Set-LinkProbe 'docs/validation-public-probe.md'

  # Scenario 3: normal governance policy remains an official source outside the reviews subtree.
  # Expected: pruning local review artifacts cannot hide a broken governance policy link.
  Set-LinkProbe 'docs/governance/validation-policy-probe.md' 'missing-policy-target.md'
  $governance = Invoke-LinkValidator
  Assert-LinkCondition ($governance.Exit -ne 0 -and ($governance.Out + $governance.Error).Contains('missing-policy-target.md')) `
    'Official governance Markdown was incorrectly excluded.'
  Set-LinkProbe 'docs/governance/validation-policy-probe.md'

  # Scenario 4: lexical near matches and nested lookalikes are not root-relative excluded scopes.
  # Expected: each remains validated and its missing destination is named in the same failure run.
  $nearMatches = @(
    @{ Path = 'docs/verification-guide/probe.md'; Target = 'missing-verification-guide-target.md' },
    @{ Path = 'docs/governance/reviews-guide/probe.md'; Target = 'missing-reviews-guide-target.md' },
    @{ Path = 'docs/example/_work/probe.md'; Target = 'missing-nested-work-target.md' },
    @{ Path = 'backlog-guide/probe.md'; Target = 'missing-backlog-guide-target.md' }
  )
  foreach ($probe in $nearMatches) { Set-LinkProbe $probe.Path $probe.Target }
  $near = Invoke-LinkValidator
  Assert-LinkCondition ($near.Exit -ne 0) 'Near-match source directories were incorrectly excluded.'
  foreach ($probe in $nearMatches) {
    Assert-LinkCondition (($near.Out + $near.Error).Contains($probe.Target)) `
      "Near-match broken link target was not reported: $($probe.Target)"
    Set-LinkProbe $probe.Path
  }
  # Scenario 5: all official probes point to a real target while ignored stale snapshots remain.
  # Expected: full validation returns to green, proving no unrelated package invariant was relaxed.
  $restored = Invoke-LinkValidator
  Assert-LinkCondition ($restored.Exit -eq 0) "Restored official links still fail validation. $($restored.Out) $($restored.Error)"
  Assert-LinkCondition ($script:validationRuns -eq 5) 'Expected exactly five full-validator calls.'
  Write-Output 'Validation link-boundary tests passed: five real full-validator scenarios.'
} finally {
  Remove-TestSandbox -Path $testRoot -Prefix $prefix
}
