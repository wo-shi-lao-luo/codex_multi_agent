# Verify distributed AI development guidance and intended discovery routes in an
# isolated package. These checks cannot prove native agent adherence or improvement.
[CmdletBinding()]
param([switch]$SourceOnly)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guides = @('ai-workflow-design.md', 'ai-instruction-design.md',
  'ai-context-design.md', 'ai-tool-design.md')
$resources = @($guides | ForEach-Object { "skills/team-core/references/$_" })
$routes = @(
  foreach ($guide in $guides) {
    @{ Path = 'skills/team-core/SKILL.md'; Target = "references/$guide" }
    @{ Path = 'skills/ai-engineering/SKILL.md'; Target = "../team-core/references/$guide" }
    @{ Path = 'skills/ai-testing-engineering/SKILL.md'; Target = "../team-core/references/$guide" }
  }
  foreach ($skill in @('team-dev', 'team-plan', 'code-review', 'team-review')) {
    @{ Path = "skills/$skill/SKILL.md"; Target = '../ai-engineering/SKILL.md' }
  }
  @{ Path = 'skills/ai-testing-engineering/SKILL.md'; Target = '../team-core/references/ai-evaluation.md' }
)

function Assert-Condition([bool]$Condition, [string]$Message) {
  # Fail at the observed contract without repairing package contents.
  if (-not $Condition) { throw $Message }
}

function Test-GuidancePackage([string]$PackageRoot) {
  # Validate required payload and intended direct Markdown routes; return no output
  # on success and throw a resource/route diagnostic on a violated contract.
  foreach ($relative in $resources) {
    $path = Join-Path $PackageRoot $relative
    Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "AD-01 missing resource: $relative"
    $text = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($path))
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($text)) "AD-01 empty resource: $relative"
  }
  if ($SourceOnly) { return }
  foreach ($route in $routes) {
    $path = Join-Path $PackageRoot $route.Path
    $text = [IO.File]::ReadAllText($path)
    $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.Target) + '(?:#[^)]+)?\)'
    Assert-Condition ($text -match $pattern) "AD-02 missing route: $($route.Path) -> $($route.Target)"
    $target = Join-Path (Split-Path -Parent $path) $route.Target
    Assert-Condition (Test-Path -LiteralPath $target -PathType Leaf) "AD-02 unresolved route: $target"
  }
  foreach ($relative in $resources) {
    $path = Join-Path $PackageRoot $relative
    foreach ($link in [regex]::Matches([IO.File]::ReadAllText($path), '\[[^\]]+\]\(([^)]+)\)')) {
      $target = $link.Groups[1].Value.Split('#')[0]
      if (-not $target -or $target -match '^[a-z]+:' ) { continue }
      Assert-Condition (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $path) $target)) (
        "AD-02 broken guide link: $relative -> $target"
      )
    }
  }
  foreach ($role in @('team-ai-architect', 'team-ai-engineer', 'team-ai-tester')) {
    $text = [IO.File]::ReadAllText((Join-Path $PackageRoot "agents/$role.toml"))
    $skill = if ($role -eq 'team-ai-tester') { 'ai-testing-engineering' } else { 'ai-engineering' }
    Assert-Condition ($text -match ('developer_instructions\s*=\s*"[^"\r\n]*\b' +
      [regex]::Escape($skill) + '\b')) "AD-02 missing role Skill route: $role"
  }
}

# Scenario AD-01: source must include all four approved portable guidance resources.
# Expected: fail directly on a missing/empty resource; setup is not a fabricated Red.
Test-GuidancePackage -PackageRoot $root
if ($SourceOnly) {
  Write-Output 'AD-01 distributed resources passed; native behavior not tested.'
  return
}

$workRoot = Join-Path $root '_work/ai-development-guidance'
$fixture = Join-Path $workRoot ('package-' + [guid]::NewGuid().ToString('N'))
$artifactHelper = Join-Path $root 'skills/team-core/scripts/generated-artifacts.ps1'
$shell = (Get-Process -Id $PID).Path
& $shell -NoProfile -File $artifactHelper -Action Protect -ProjectRoot $root `
  -Profile Work -WorkPath '_work/ai-development-guidance' | Out-Null
Assert-Condition ($LASTEXITCODE -eq 0) 'Work protection failed before fixture creation.'

function Get-Fingerprint {
  # Hash names and bytes to detect accidental source-copy mutation or lost restoration.
  return ((Get-ChildItem -LiteralPath $fixture -File -Recurse | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($fixture, $_.FullName)
    "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
  } | Sort-Object) -join "`n")
}

function Assert-PackageRejects([string]$Diagnostic) {
  # Observe this test's structural contract, not an invented production-validator guard.
  $observed = $null
  try { Test-GuidancePackage -PackageRoot $fixture } catch { $observed = $_.Exception.Message }
  Assert-Condition ($null -ne $observed -and $observed.Contains($Diagnostic)) (
    "Expected package rejection '$Diagnostic'; observed '$observed'"
  )
}

try {
  New-Item -ItemType Directory -Path $fixture -Force | Out-Null
  foreach ($directory in @('agents', 'skills')) {
    Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $fixture -Recurse
  }
  # Scenario AD-02 happy: copy actual distributed resources and direct routes.
  # Expected: complete isolated package passes with every intended link resolving.
  Test-GuidancePackage -PackageRoot $fixture
  $fingerprint = Get-Fingerprint

  # Scenario AD-02 resource edge: each approved resource is removed individually.
  # Expected: precise resource rejection, then byte-exact restoration without source edits.
  foreach ($relative in $resources) {
    $path = Join-Path $fixture $relative
    $original = [IO.File]::ReadAllBytes($path)
    try {
      Remove-Item -LiteralPath $path
      Assert-PackageRejects "AD-01 missing resource: $relative"
    } finally { [IO.File]::WriteAllBytes($path, $original) }
  }

  # Scenario AD-02 route edge: intended link is replaced by an existing unrelated guide.
  # Expected: every lost route rejects even though the replacement Markdown link resolves.
  foreach ($route in $routes) {
    $path = Join-Path $fixture $route.Path
    $original = [IO.File]::ReadAllBytes($path)
    try {
      $text = [IO.File]::ReadAllText($path)
      $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.Target) + '(?:#[^)]+)?\)'
      $replacement = if ($route.Path -eq 'skills/team-core/SKILL.md') {
        '[unrelated](references/execution-contract.md)'
      } else { '[unrelated](../team-core/references/execution-contract.md)' }
      [IO.File]::WriteAllText($path, [regex]::Replace($text, $pattern, $replacement))
      Assert-PackageRejects "AD-02 missing route: $($route.Path) -> $($route.Target)"
    } finally { [IO.File]::WriteAllBytes($path, $original) }
  }

  # Scenario AD-02 broken link edge: a new guide points to an absent local resource.
  # Expected: link resolution rejects each broken guide link, then restores original bytes.
  foreach ($relative in $resources) {
    $path = Join-Path $fixture $relative
    $original = [IO.File]::ReadAllBytes($path)
    try {
      $text = [IO.File]::ReadAllText($path) + "`n[broken](missing-ai-resource.md)`n"
      [IO.File]::WriteAllText($path, $text)
      Assert-PackageRejects "AD-02 broken guide link: $relative -> missing-ai-resource.md"
    } finally { [IO.File]::WriteAllBytes($path, $original) }
  }

  # Scenario AD-02 recovery: all negative fixtures have been restored.
  # Expected: complete package passes and names/bytes equal the original fingerprint.
  Test-GuidancePackage -PackageRoot $fixture
  Assert-Condition ((Get-Fingerprint) -eq $fingerprint) 'Package restoration changed bytes.'
  Write-Output "AD-01/02 passed: 4 resources and $($routes.Count) routes; mutations rejected."
  Write-Output 'Structural evidence only; native adherence and capability improvement untested.'
} finally {
  # Scenario: test success or failure ends with cleanup of only this owned GUID child.
  # Expected: exact protected task parent/prefix validated before recursive removal.
  $resolved = [IO.Path]::GetFullPath($fixture)
  $expectedParent = [IO.Path]::GetFullPath($workRoot)
  Assert-Condition ((Split-Path -Parent $resolved) -eq $expectedParent -and
    (Split-Path -Leaf $resolved) -match '^package-[a-f0-9]{32}$') 'Unsafe fixture cleanup.'
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert-Condition (-not (Test-Path -LiteralPath $resolved)) 'Owned fixture cleanup failed.'
}
