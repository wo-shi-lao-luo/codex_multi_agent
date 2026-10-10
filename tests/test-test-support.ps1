# Verify shared test mechanisms with controlled child scripts and synthetic package trees.
# These checks establish transport/filesystem contracts, not native Agent behavior.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $PSScriptRoot 'helpers/package-test.ps1'

# TS00: consumers need an actual shared helper before any fixture can exercise its API.
# Expected: genuine missing-source failure before implementation, never a synthetic pass.
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
  throw 'TS00: missing shared helper tests/helpers/package-test.ps1'
}
. $helper

$parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$prefix = 'codex-test-support-test-'
$sandbox = Join-Path $parent ($prefix + [guid]::NewGuid().ToString('N'))
$cleanupRoot = Join-Path $parent ($prefix + [guid]::NewGuid().ToString('N'))
$junction = Join-Path $parent ($prefix + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$script:checks = 0

function Assert-Support([bool]$Condition, [string]$Message) {
  # Retain the scenario diagnostic and stop immediately on an observable mismatch.
  if (-not $Condition) { throw $Message }
  $script:checks++
}

function Assert-SupportRejects([scriptblock]$Run, [string]$Scenario) {
  # Negative helper calls must throw; no production diagnostic wording is invented here.
  $rejected = $false
  try { & $Run | Out-Null } catch { $rejected = $true }
  Assert-Support $rejected "$Scenario accepted an invalid operation."
}

function Write-SupportFixture([string]$Root, [string]$Relative, [string]$Body) {
  # Generate only owned synthetic data, preserving exact UTF-8 input bytes.
  $target = Join-Path $Root $Relative
  [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
  [IO.File]::WriteAllText($target, $Body, $utf8)
}

function Assert-SupportFiles([string]$Root, [string[]]$Expected, [string]$Scenario) {
  # Exact path lists detect both accidental extra copies and missing approved files.
  $actual = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | ForEach-Object {
    [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
  } | Sort-Object)
  Assert-Support (($actual -join ';') -ceq (($Expected | Sort-Object) -join ';')) (
    "$Scenario copied paths differ: $($actual -join ', ')."
  )
}

try {
  [IO.Directory]::CreateDirectory($sandbox) | Out-Null
  $shell = (Get-Process -Id $PID).Path

  # TS01: executable-looking strings, spaces, quotes and Unicode are literal argv.
  # Expected: exact JSON argument array, explicit child environment and exit 17;
  # simultaneous large stdout/stderr complete without parent-environment changes.
  $child = Join-Path $sandbox 'child with spaces.ps1'
  $childBody = @'
$observed = @{ arguments = @($args); probe = $env:CODEX_TEST_SUPPORT_PROBE }
[Console]::Out.WriteLine(($observed | ConvertTo-Json -Compress -Depth 5))
[Console]::Out.Write(('o' * 131072))
[Console]::Error.Write(('e' * 131072) + '错误😀')
exit 17
'@
  [IO.File]::WriteAllText($child, $childBody, $utf8)
  $literal = @('space value', '"quoted"', '$() ; & | > literal', '中文😀', '')
  $prior = [Environment]::GetEnvironmentVariable('CODEX_TEST_SUPPORT_PROBE')
  $result = Invoke-TestProcess -FilePath $shell -ArgumentList (
    @('-NoProfile', '-File', $child) + $literal
  ) -Environment @{ CODEX_TEST_SUPPORT_PROBE = 'child-only-value' }
  $lineEnd = $result.Out.IndexOf("`n")
  Assert-Support ($lineEnd -ge 0) 'TS01 child JSON line missing.'
  $observed = $result.Out.Substring(0, $lineEnd).TrimEnd("`r") | ConvertFrom-Json
  Assert-Support (($observed.arguments | ConvertTo-Json -Compress) -ceq
    ($literal | ConvertTo-Json -Compress)) 'TS01 literal argv changed.'
  Assert-Support ($observed.probe -ceq 'child-only-value') 'TS01 explicit child env missing.'
  Assert-Support ($result.Exit -eq 17) 'TS01 nonzero child exit lost.'
  Assert-Support ($result.Out.Substring($lineEnd + 1) -ceq ('o' * 131072)) (
    'TS01 stdout was truncated, mixed or changed.'
  )
  Assert-Support ($result.Error -ceq (('e' * 131072) + '错误😀')) (
    'TS01 stderr was truncated, mixed or changed.'
  )
  Assert-Support ([Environment]::GetEnvironmentVariable('CODEX_TEST_SUPPORT_PROBE') -ceq $prior) (
    'TS01 parent environment changed.'
  )
  # TS01 control: omitted environment uses normal inheritance and successful exit.
  # Expected: default empty map works without an environment policy or shell evaluation.
  $success = Invoke-TestProcess -FilePath $shell -ArgumentList @(
    '-NoProfile', '-Command', '[Console]::Out.Write("success"); exit 0'
  )
  Assert-Support ($success.Exit -eq 0 -and $success.Out -ceq 'success' -and
    $success.Error -ceq '') 'TS01 successful/default-env child result changed.'
  Write-Output 'TS01 process argv/env/stdout/stderr/exit passed.'

  # TS02: narrow and public profiles have intentionally different source boundaries.
  # Expected: exact selected bytes/config/root docs; private governance/history and
  # unrelated root work are never copied. Copying must leave synthetic source intact.
  $source = Join-Path $sandbox 'source'
  $bodies = [ordered]@{
    'agents/fixture.toml' = 'name = "fixture"'
    'skills/fixture/SKILL.md' = '# Fixture'
    'skills/fixture/bom.txt' = "A`r`n"
    'scripts/fixture.ps1' = '# Inert script'
    'config/fragment.toml' = '# Optional config'
    'VERSION' = '0.0.0'
    'CHANGELOG.md' = '# Changelog'
    'CHANGELOG.zh-CN.md' = '# 更新'
    'README.md' = '# Public root'
    'AGENTS.md' = '# Public root instruction bytes'
    'docs/formatter-tool.md' = '# Exact linked formatter guide'
    'docs/verification/active/formatter-tool.md' = '# Exact linked packet'
    'docs/public/nested.md' = '# Public nested'
    'docs/governance/private.md' = '# Private runtime'
    'docs/superpowers/private.md' = '# Private history'
    '_work/private.md' = '# Foreign work'
    'unrelated.txt' = 'unrelated'
  }
  foreach ($relative in $bodies.Keys) { Write-SupportFixture $source $relative $bodies[$relative] }
  # TS02 representation edge: BOM and CRLF must survive, not merely decoded text.
  # Expected: the original EF BB BF 41 0D 0A bytes propagate through every profile.
  $bomRelative = 'skills/fixture/bom.txt'
  $bomBytes = [byte[]]@(0xEF, 0xBB, 0xBF, 0x41, 0x0D, 0x0A)
  [IO.File]::WriteAllBytes((Join-Path $source $bomRelative), $bomBytes)
  $sourceBeforeCopies = Get-TestFingerprint -Root $source
  $sourceHashes = @{}
  foreach ($relative in $bodies.Keys) {
    $sourceHashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $source $relative)).Hash
  }
  $narrow = @('agents/fixture.toml', 'skills/fixture/SKILL.md', $bomRelative, 'scripts/fixture.ps1',
    'VERSION', 'CHANGELOG.md', 'CHANGELOG.zh-CN.md', 'docs/formatter-tool.md',
    'docs/verification/active/formatter-tool.md')
  $public = $narrow + @('README.md', 'AGENTS.md', 'docs/public/nested.md')
  foreach ($profile in @('Narrow', 'PublicDocs')) {
    foreach ($includeConfig in @($false, $true)) {
      $destination = Join-Path $sandbox "$profile-$includeConfig"
      Copy-TestPackage -SourceRoot $source -DestinationRoot $destination `
        -Profile $profile -IncludeConfig $includeConfig
      $expected = if ($profile -eq 'Narrow') { $narrow } else { $public }
      if ($includeConfig) { $expected += 'config/fragment.toml' }
      Assert-SupportFiles $destination $expected "TS02 $profile config=$includeConfig"
      foreach ($relative in $expected) {
        $copiedHash = (Get-FileHash -LiteralPath (Join-Path $destination $relative)).Hash
        Assert-Support ($copiedHash -ceq $sourceHashes[$relative]) (
          "TS02 changed copied bytes: $relative"
        )
      }
      $copiedBom = [IO.File]::ReadAllBytes((Join-Path $destination $bomRelative))
      Assert-Support ([Convert]::ToHexString($copiedBom) -ceq 'EFBBBF410D0A') (
        'TS02 BOM/CRLF bytes changed during copy.'
      )
    }
  }
  Assert-Support ((Get-TestFingerprint -Root $source) -ceq $sourceBeforeCopies) (
    'TS02 copy operation changed original source paths or bytes.'
  )
  # TS02 overlap edges: equality, destination under source, source under destination.
  # Expected: all reject before creating directories or changing either existing tree.
  $sourceBefore = Get-TestFingerprint -Root $source
  foreach ($destination in @($source, (Join-Path $source 'must-not-create'), $sandbox)) {
    Assert-SupportRejects {
      Copy-TestPackage -SourceRoot $source -DestinationRoot $destination `
        -Profile Narrow -IncludeConfig $true
    } 'TS02 overlap'
  }
  Assert-Support (-not (Test-Path -LiteralPath (Join-Path $source 'must-not-create'))) (
    'TS02 overlapping destination was created before rejection.'
  )
  Assert-Support ((Get-TestFingerprint -Root $source) -ceq $sourceBefore) (
    'TS02 overlap rejection changed source.'
  )
  foreach ($relative in $bodies.Keys) {
    Assert-Support ((Get-FileHash -LiteralPath (Join-Path $source $relative)).Hash -ceq
      $sourceHashes[$relative]) "TS02 source changed: $relative"
  }
  Write-Output 'TS02 narrow/public copy profiles, exact source and overlap rejection passed.'

  # TS03: path additions/removals, byte edits and hidden files affect complete identity.
  # Expected: repeated fingerprints are stable/read-only; each independent edit differs.
  $tree = Join-Path $sandbox 'identity'
  Write-SupportFixture $tree 'alpha.txt' 'alpha'
  $alphaHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes('alpha')))
  $identity = Get-TestFingerprint -Root $tree
  Assert-Support ($identity -ceq "alpha.txt`t$alphaHash") 'TS03 canonical path/hash changed.'
  Assert-Support ((Get-TestFingerprint -Root $tree) -ceq $identity) 'TS03 unstable identity.'
  Write-SupportFixture $tree 'alpha.txt' 'edited'
  Assert-Support ((Get-TestFingerprint -Root $tree) -cne $identity) 'TS03 byte edit missed.'
  Write-SupportFixture $tree 'alpha.txt' 'alpha'
  Write-SupportFixture $tree '.hidden' 'hidden bytes'
  $hidden = Join-Path $tree '.hidden'
  if ($IsWindows) { [IO.File]::SetAttributes($hidden, [IO.FileAttributes]::Hidden) }
  $added = Get-TestFingerprint -Root $tree
  Assert-Support ($added -cne $identity -and $added.Contains(".hidden`t")) (
    'TS03 hidden added file missed.'
  )
  Remove-Item -LiteralPath $hidden -Force
  Assert-Support ((Get-TestFingerprint -Root $tree) -ceq $identity) 'TS03 removal/restoration missed.'
  # TS03 ordering edge: ordinal uppercase Z precedes lowercase a regardless of locale.
  # Expected: canonical identity retains exact path case and a stable ordinal sequence.
  Write-SupportFixture $tree 'Zulu.txt' 'zulu'
  $zuluHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes('zulu')))
  Assert-Support ((Get-TestFingerprint -Root $tree) -ceq
    ("Zulu.txt`t$zuluHash`n" + $identity)) 'TS03 ordinal manifest order changed.'
  # TS03 hidden-directory edge: control files beneath a hidden directory matter too.
  # Expected: recursive identity includes its nested index-like file and detects edits.
  Write-SupportFixture $tree '.control/index' 'initial index bytes'
  $control = Join-Path $tree '.control'
  if ($IsWindows) { [IO.File]::SetAttributes($control, [IO.FileAttributes]::Hidden) }
  $nestedIdentity = Get-TestFingerprint -Root $tree
  $nestedRelative = Join-Path '.control' 'index'
  Assert-Support ($nestedIdentity.Contains("$nestedRelative`t")) (
    'TS03 hidden directory contents missed.'
  )
  Write-SupportFixture $tree '.control/index' 'edited index bytes'
  Assert-Support ((Get-TestFingerprint -Root $tree) -cne $nestedIdentity) (
    'TS03 hidden nested byte edit missed.'
  )
  Assert-Support ([IO.File]::ReadAllText((Join-Path $tree 'alpha.txt')) -ceq 'alpha') (
    'TS03 fingerprint wrote source bytes.'
  )
  Write-Output 'TS03 complete byte/path/hidden-file fingerprint passed.'

  # TS04: only the exact caller prefix plus lowercase GUID directly under OS temp is owned.
  # Expected: valid root is removed, repeat absent cleanup is safe; wrong prefix,
  # invalid absent name and nested valid-looking roots reject without touching sentinels.
  Write-SupportFixture $cleanupRoot 'sentinel.txt' 'owned cleanup'
  Remove-TestSandbox -Path $cleanupRoot -Prefix $prefix
  Assert-Support (-not (Test-Path -LiteralPath $cleanupRoot)) 'TS04 owned root remains.'
  Remove-TestSandbox -Path $cleanupRoot -Prefix $prefix
  $sentinel = Join-Path $sandbox 'sentinel.txt'
  [IO.File]::WriteAllText($sentinel, 'foreign-to-cleanup', $utf8)
  $nested = Join-Path $sandbox ($prefix + [guid]::NewGuid().ToString('N'))
  Write-SupportFixture $nested 'sentinel.txt' 'nested must survive'
  foreach ($invalid in @(
    @{ path = $sandbox; prefix = 'wrong-prefix-' },
    @{ path = $sandbox; prefix = 'codex-test-support-test-.*' },
    @{ path = $nested; prefix = $prefix },
    @{ path = (Join-Path $parent ($prefix + 'not-a-guid')); prefix = $prefix },
    @{ path = (Join-Path $parent ($prefix + ('A' * 32))); prefix = $prefix }
  )) {
    Assert-SupportRejects {
      Remove-TestSandbox -Path $invalid.path -Prefix $invalid.prefix
    } 'TS04 invalid cleanup'
  }
  Assert-Support ([IO.File]::ReadAllText($sentinel) -ceq 'foreign-to-cleanup' -and
    [IO.File]::ReadAllText((Join-Path $nested 'sentinel.txt')) -ceq 'nested must survive') (
    'TS04 rejected cleanup changed unrelated bytes.'
  )
  # TS04 platform edge: non-Windows parents are case-sensitive ownership boundaries.
  # Expected: an absent valid-looking root under a case-swapped parent rejects;
  # never create the swapped directory or submit an existing external deletion target.
  if (-not $IsWindows) {
    $swappedParent = $parent.ToUpperInvariant()
    if ($swappedParent -ceq $parent) { $swappedParent = $parent.ToLowerInvariant() }
    if ($swappedParent -cne $parent) {
      $absent = Join-Path $swappedParent ($prefix + [guid]::NewGuid().ToString('N'))
      Assert-Support (-not (Test-Path -LiteralPath $absent)) 'TS04 absent control exists.'
      Assert-SupportRejects { Remove-TestSandbox -Path $absent -Prefix $prefix } (
        'TS04 case-swapped non-Windows parent'
      )
      Assert-Support (-not (Test-Path -LiteralPath $absent)) 'TS04 absent control was created.'
    } else { Write-Output 'TS04 case-swapped parent not applicable: no caseful letters.' }
  } else { Write-Output 'TS04 non-Windows case-sensitive parent check not applicable on Windows.' }
  # TS04 reparse edge: a valid-looking direct temp child links to this test's owned tree.
  # Expected: reject the junction and preserve its target; remove only the link afterward.
  if ($IsWindows) {
    New-Item -ItemType Junction -Path $junction -Target $nested | Out-Null
    try {
      Assert-SupportRejects { Remove-TestSandbox -Path $junction -Prefix $prefix } 'TS04 reparse'
      Assert-Support ([IO.File]::ReadAllText((Join-Path $nested 'sentinel.txt')) -ceq
        'nested must survive') 'TS04 reparse target changed.'
    } finally {
      if ($null -ne (Get-Item -LiteralPath $junction -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $junction -Force
      }
    }
  } else { Write-Output 'TS04 Windows junction check not applicable on this platform.' }
  Write-Output "TS01-04 shared test support passed: $script:checks assertions."
} finally {
  # Independent cleanup avoids relying on the helper under test after an assertion fails.
  # Validate each exact generated temp root, remove a junction link without recursion first.
  if ($null -ne (Get-Item -LiteralPath $junction -Force -ErrorAction SilentlyContinue)) {
    Remove-Item -LiteralPath $junction -Force
  }
  foreach ($owned in @($sandbox, $cleanupRoot)) {
    $resolved = [IO.Path]::GetFullPath($owned)
    if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\', '/') -ne $parent -or
        [IO.Path]::GetFileName($resolved) -cnotmatch '^codex-test-support-test-[a-f0-9]{32}$') {
      throw 'Unsafe support-test cleanup target.'
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    if (Test-Path -LiteralPath $resolved) { throw 'Support-test fixture cleanup failed.' }
  }
}
