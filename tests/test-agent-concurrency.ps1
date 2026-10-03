# Check the recommended agents ceiling without loading Codex or modifying user settings.
# The narrow reader supports this repository's plain section/integer fragment, not general TOML.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root 'config/recommended-config.toml'
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent ('codex-multi-agent-concurrency-test-' + [guid]::NewGuid().ToString('N'))

function Assert-Condition {
  # Abort when a configuration or cleanup expectation is not observed.
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}
function Get-RecommendedCeiling {
  # Read exactly one plain integer key in one [agents] table; reject ambiguity.
  # This does not resolve Codex defaults, merge configuration or establish host capacity.
  param([string]$Path)
  $section = ''; $tables = 0; $values = @()
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*\[([^\]]+)\]\s*(?:#.*)?$') {
      $section = $Matches[1].Trim()
      if ($section -eq 'agents') { $tables++ }
      continue
    }
    if ($section -eq 'agents' -and $line -match '^\s*max_concurrent_threads_per_session\s*=\s*(.*?)\s*(?:#.*)?$') {
      $value = $Matches[1].Trim()
      if ($value -notmatch '^[1-9][0-9]*$') { throw 'Ceiling must be a positive plain integer in the supported fragment.' }
      $values += [int]$value
    }
  }
  if ($tables -ne 1 -or $values.Count -ne 1) { throw 'Expected exactly one agents table and one concurrency ceiling.' }
  return $values[0]
}
function Assert-RejectedFragment {
  # Write one disposable unsupported/ambiguous fragment and require reader rejection.
  param([string]$Name, [string]$Content)
  $fixture = Join-Path $testRoot 'fixture.toml'
  Set-Content -LiteralPath $fixture -Value $Content -Encoding utf8
  $rejected = $false
  try { $null = Get-RecommendedCeiling $fixture } catch { $rejected = $true }
  Assert-Condition $rejected "Accepted $Name."
}
try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  $fixture = Join-Path $testRoot 'fixture.toml'
  # Scenario: other sections contain a decoy value and the agents key has a comment.
  # Expected: read the sole agents value 6, ignoring unrelated value 3 and commentary.
  Set-Content -LiteralPath $fixture -Value "[other]`nmax_concurrent_threads_per_session = 3`n[agents]`nmax_concurrent_threads_per_session = 6 # child agents only`n[other.child]`nmax_concurrent_threads_per_session = 9" -Encoding utf8
  Assert-Condition ((Get-RecommendedCeiling $fixture) -eq 6) 'Section-aware integer reading failed.'
  # Scenario: the old recommendation remains a supported plain integer.
  # Expected: read 3 as 3, so the later 6 assertion cannot pass by parser fabrication.
  Set-Content -LiteralPath $fixture -Value "[agents]`nmax_concurrent_threads_per_session = 3" -Encoding utf8
  Assert-Condition ((Get-RecommendedCeiling $fixture) -eq 3) 'Reader replaced the old value instead of observing it.'
  # Scenario: missing/duplicate tables or keys, zero, negative and quoted values.
  # Expected: each named ambiguity or unsupported value fails instead of silently defaulting to 6.
  foreach ($case in @(
    @('missing agents table', "[other]`nmax_concurrent_threads_per_session = 6"),
    @('missing key', "[agents]`nenabled = true"),
    @('duplicate key', "[agents]`nmax_concurrent_threads_per_session = 6`nmax_concurrent_threads_per_session = 3"),
    @('duplicate table', "[agents]`nmax_concurrent_threads_per_session = 6`n[agents]"),
    @('zero ceiling', "[agents]`nmax_concurrent_threads_per_session = 0"),
    @('negative ceiling', "[agents]`nmax_concurrent_threads_per_session = -1"),
    @('quoted ceiling', '[agents]' + "`n" + 'max_concurrent_threads_per_session = "6"')
  )) { Assert-RejectedFragment $case[0] $case[1] }
  # Scenario: the actual shipped recommended configuration is inspected read-only.
  # Expected: observe 6 and retain its exact hash; this does not prove six runtime slots.
  $before = (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
  $observed = Get-RecommendedCeiling $config
  Assert-Condition (((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash) -eq $before) 'Source configuration changed during inspection.'
  Assert-Condition ($observed -eq 6) "Recommended agents ceiling must be 6; observed $observed."
  Write-Host 'Agent concurrency configuration checks passed; runtime and policy compliance unverified.'
} finally {
  # Remove only the resolved, uniquely owned fixture directly inside the temp parent.
  $resolved = [IO.Path]::GetFullPath($testRoot)
  if ([IO.Path]::GetDirectoryName($resolved) -ne $temporaryParent.TrimEnd('\', '/') -or [IO.Path]::GetFileName($resolved) -notmatch '^codex-multi-agent-concurrency-test-[a-f0-9]{32}$') { throw 'Unsafe fixture cleanup target.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert-Condition (-not (Test-Path -LiteralPath $resolved)) 'Owned fixture remains after cleanup.'
  Write-Host 'Owned concurrency fixture removed.'
}
