# Exercise repository-only bilingual validation at its real command boundary.
# Every fixture lives in one owned temporary root; no installed payload is changed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $root 'scripts/validate-docs.ps1'
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent ('codex-multi-agent-bilingual-test-' + [guid]::NewGuid().ToString('N'))
$shell = (Get-Process -Id $PID).Path

function Assert-Condition {
  # Fail the suite when an observable validation or cleanup expectation is false.
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}
function Invoke-Validation {
  # Run the public CLI in a separate process, returning its real exit status.
  param([string]$Project)
  $output = & $shell -NoProfile -File $validator -ProjectRoot $Project 2>&1
  return [pscustomobject]@{ Passed = ($LASTEXITCODE -eq 0); Output = ($output -join "`n") }
}
function Reset-Fixture {
  # Restore two equivalent releases, optionally preceded by pending change items.
  param([switch]$IncludeUnreleased)
  Set-Content -LiteralPath (Join-Path $testRoot 'VERSION') -Value '0.9.3'
  $readme = @'
# Kit

[中文](README.zh-CN.md)

Current release: `0.9.3`.

| Role | Model | Reasoning effort |
| --- | --- | --- |
| Architect | `gpt-6.1-sol` | xhigh |
| Tester | `gpt-6.1-sol` | medium |

```powershell
.\scripts\install-user.ps1 -WhatIf
```

See [guide](docs/guide.md) and [history](CHANGELOG.md).
'@
  $chinese = $readme.Replace('[中文](README.zh-CN.md)', '[English](README.md)').Replace('Current release:', '当前版本:').Replace('See [guide]', '参阅 [指南]').Replace('[history](CHANGELOG.md)', '[历史](CHANGELOG.zh-CN.md)').Replace('| Role | Model | Reasoning effort |', '| 角色 | 模型 | 推理强度 |').Replace('| Architect |', '| 架构师 |').Replace('| Tester |', '| 测试员 |')
  $changes = @'
# Changelog

[中文](CHANGELOG.zh-CN.md)

## [0.9.3] - 2026-10-02
- Added `scripts/validate-docs.ps1`.
- Keep `[manual pending]` honest.

## [0.9.2] - 2026-09-30
- Earlier release.
'@
  $changesChinese = $changes.Replace('[中文](CHANGELOG.zh-CN.md)', '[English](CHANGELOG.md)').Replace('Added ', '新增 ').Replace('Keep ', '保持 ').Replace('honest.', '真实。').Replace('Earlier release.', '之前的版本。')
  if ($IncludeUnreleased) {
    $pending = "## [Unreleased]`n`n### Added`n`n- Pending documentation update.`n`n"
    $changes = $changes.Replace('## [0.9.3]', $pending + '## [0.9.3]')
    $changesChinese = $changesChinese.Replace('## [0.9.3]', $pending.Replace('### Added', '### 新增').Replace('Pending documentation update.', '待发布的文档更新。') + '## [0.9.3]')
  }
  foreach ($pair in @(@('README.md', $readme), @('README.zh-CN.md', $chinese), @('CHANGELOG.md', $changes), @('CHANGELOG.zh-CN.md', $changesChinese))) {
    Set-Content -LiteralPath (Join-Path $testRoot $pair[0]) -Value $pair[1] -Encoding utf8
  }
}
function Assert-RejectedMutation {
  # Apply one clearly identified drift and require nonzero exit at the CLI boundary.
  param([string]$Name, [string]$File, [string]$Before, [string]$After, [switch]$IncludeUnreleased)
  Reset-Fixture -IncludeUnreleased:$IncludeUnreleased
  $path = Join-Path $testRoot $File
  $text = Get-Content -LiteralPath $path -Raw
  Assert-Condition ($text.Contains($Before)) "Mutation fixture anchor missing: $Name"
  Set-Content -LiteralPath $path -Value ($text.Replace($Before, $After)) -Encoding utf8
  Assert-Condition (-not (Invoke-Validation $testRoot).Passed) "Validator accepted $Name."
  Write-Host "Rejected: $Name"
}
try {
  # Scenario: the required validator is unavailable before implementation.
  # Expected: an explicit failing Red rather than a false pass from an unexecuted command.
  Assert-Condition (Test-Path -LiteralPath $validator -PathType Leaf) 'Bilingual validator entrypoint does not exist.'
  New-Item -ItemType Directory -Path (Join-Path $testRoot 'docs') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testRoot 'docs/guide.md') -Value '# Guide'
  New-Item -ItemType Directory -Path (Join-Path $testRoot 'scripts') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testRoot 'scripts/install-user.ps1') -Value '# Fixture command only; never executed.'
  Reset-Fixture
  # Scenario: prose/header translations differ but all technical facts match.
  # Expected: accept idiomatic translated prose and translated model-role labels.
  $baseline = Invoke-Validation $testRoot
  Assert-Condition $baseline.Passed "Equivalent bilingual fixture rejected: $($baseline.Output)"
  # Scenario: both changelogs have an optional pending section before real releases.
  # Expected: accept translated categories/items without changing authoritative VERSION.
  Reset-Fixture -IncludeUnreleased
  $pendingBaseline = Invoke-Validation $testRoot
  Assert-Condition $pendingBaseline.Passed "Equivalent Unreleased fixture rejected: $($pendingBaseline.Output)"
  Reset-Fixture
  # Scenario: translated prose has extra blank lines outside executable code.
  # Expected: harmless layout differences pass rather than requiring line-for-line translation.
  $layoutPath = Join-Path $testRoot 'README.zh-CN.md'
  $layoutText = Get-Content -LiteralPath $layoutPath -Raw
  Set-Content -LiteralPath $layoutPath -Value ("`n" + $layoutText.Replace('参阅 [指南]', "`n参阅 [指南]")) -Encoding utf8
  Assert-Condition (Invoke-Validation $testRoot).Passed 'Accepted prose whitespace should not require exact translation layout.'
  # Scenario: any required member is missing, or is an empty malformed document.
  # Expected: reject each absent/empty pair member independently.
  foreach ($file in @('README.md', 'README.zh-CN.md', 'CHANGELOG.md', 'CHANGELOG.zh-CN.md', 'VERSION')) {
    Reset-Fixture
    Remove-Item -LiteralPath (Join-Path $testRoot $file)
    Assert-Condition (-not (Invoke-Validation $testRoot).Passed) "Accepted missing $file."
    Reset-Fixture
    Set-Content -LiteralPath (Join-Path $testRoot $file) -Value ''
    Assert-Condition (-not (Invoke-Validation $testRoot).Passed) "Accepted empty $file."
  }
  # Scenario: independent technical drifts in commands, flags, literals, version, model or effort.
  # Expected: reject every row; changing prose alone is not one of these failures.
  foreach ($case in @(
    @('command drift', 'README.zh-CN.md', 'install-user.ps1', 'update-user.ps1'),
    @('flag drift', 'README.zh-CN.md', '-WhatIf', '-Force'),
    @('inline literal drift', 'README.zh-CN.md', 'gpt-6.1-sol', 'gpt-6-luna'),
    @('effort drift', 'README.zh-CN.md', '| medium |', '| high |'),
    @('README version drift', 'README.zh-CN.md', '`0.9.3`', '`0.9.2`'),
    @('old current release with correct historical mention', 'README.zh-CN.md', '当前版本: `0.9.3`.', "当前版本: ``0.9.2``.`n历史记录 ``0.9.3``。"),
    @('link target drift', 'README.zh-CN.md', 'docs/guide.md', 'docs/other.md'),
    @('missing language navigation', 'README.zh-CN.md', '[English](README.md)', 'English'),
    @('changelog navigation', 'CHANGELOG.zh-CN.md', '[English](CHANGELOG.md)', 'English'),
    @('release date drift', 'CHANGELOG.zh-CN.md', '2026-09-30', '2026-09-29'),
    @('release version drift', 'CHANGELOG.zh-CN.md', '[0.9.2]', '[0.9.1]'),
    @('release item omission', 'CHANGELOG.zh-CN.md', '- 之前的版本。', ''),
    @('changelog technical drift', 'CHANGELOG.zh-CN.md', '`scripts/validate-docs.ps1`', '`scripts/validate.ps1`'),
    @('malformed code fence', 'README.zh-CN.md', '```powershell', '``powershell')
  )) { Assert-RejectedMutation $case[0] $case[1] $case[2] $case[3] }
  # Scenario: only one pending section loses its heading, category or change item.
  # Expected: reject each structural drift just like published release drift.
  foreach ($case in @(
    @('missing Unreleased counterpart', "## [Unreleased]`n`n### 新增`n`n- 待发布的文档更新。`n`n", ''),
    @('Unreleased category drift', '### 新增', '### 修复'),
    @('Unreleased item omission', '- 待发布的文档更新。', '')
  )) { Assert-RejectedMutation $case[0] 'CHANGELOG.zh-CN.md' $case[1] $case[2] -IncludeUnreleased }
  # Scenario: both translations share an invalid pending layout, hiding pair drift.
  # Expected: reject dated, duplicate, misplaced, empty, or release-only-missing layouts.
  foreach ($case in @('dated', 'duplicate', 'misplaced', 'empty', 'no published release')) {
    Reset-Fixture -IncludeUnreleased
    foreach ($file in @('CHANGELOG.md', 'CHANGELOG.zh-CN.md')) {
      $path = Join-Path $testRoot $file
      $text = Get-Content -LiteralPath $path -Raw
      switch ($case) {
        'dated' { $text = $text.Replace('## [Unreleased]', '## [Unreleased] - 2026-10-10') }
        'duplicate' { $text = $text.Replace('## [Unreleased]', "## [Unreleased]`n- Duplicate pending item.`n`n## [Unreleased]") }
        'misplaced' {
          $pendingBlock = [regex]::Match($text, '(?s)## \[Unreleased\].*?(?=## \[0\.9\.3\])').Value
          $text = $text.Replace($pendingBlock, '') + "`n" + $pendingBlock
        }
        'empty' { $text = [regex]::Replace($text, '(?s)(## \[Unreleased\]).*?(?=## \[0\.9\.3\])', '$1' + "`n`n") }
        'no published release' { $text = [regex]::Replace($text, '(?s)## \[0\.9\.3\].*$', '') }
      }
      Set-Content -LiteralPath $path -Value $text -Encoding utf8
    }
    Assert-Condition (-not (Invoke-Validation $testRoot).Passed) "Accepted shared invalid Unreleased layout: $case."
    Write-Host "Rejected: Unreleased $case"
  }
  # Scenario: both translations agree on a release absent from authoritative VERSION.
  # Expected: reject shared version drift rather than comparing only the two languages.
  Reset-Fixture
  Set-Content -LiteralPath (Join-Path $testRoot 'VERSION') -Value '0.9.4'
  Assert-Condition (-not (Invoke-Validation $testRoot).Passed) 'Accepted shared release drift against VERSION.'
  # Scenario: the validator reads an intact repository and isolated fixture.
  # Expected: final fixture passes and no source documents are modified by validation.
  Reset-Fixture
  $beforeHashes = @(Get-ChildItem -LiteralPath $testRoot -File -Recurse | Get-FileHash | Sort-Object Path | ForEach-Object Hash) -join ','
  Assert-Condition (Invoke-Validation $testRoot).Passed 'Restored fixture failed.'
  $afterHashes = @(Get-ChildItem -LiteralPath $testRoot -File -Recurse | Get-FileHash | Sort-Object Path | ForEach-Object Hash) -join ','
  Assert-Condition ($beforeHashes -eq $afterHashes) 'Read-only validator modified its target.'
  Write-Host 'Bilingual documentation tests passed.'
} finally {
  $resolved = [IO.Path]::GetFullPath($testRoot)
  $parent = [IO.Path]::GetFullPath((Split-Path -Parent $resolved)).TrimEnd([char]'\', [char]'/')
  Assert-Condition ($parent -eq $temporaryParent.TrimEnd([char]'\', [char]'/') -and [IO.Path]::GetFileName($resolved).StartsWith('codex-multi-agent-bilingual-test-')) 'Refusing cleanup outside the owned temporary fixture.'
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert-Condition (-not (Test-Path -LiteralPath $resolved)) 'Temporary bilingual fixture remains.'
  Write-Host 'Isolated bilingual fixture removed.'
}
