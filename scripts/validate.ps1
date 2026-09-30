# Validate distributable metadata and resource routing, not runtime or visual quality.
[CmdletBinding()]
param()

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

foreach ($resource in @('scripts/deploy-user.ps1')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) { $failures.Add("Missing deployment resource: $resource") }
}

$versionPath = Join-Path $root 'VERSION'
$kitVersion = $null
if (-not (Test-Path -LiteralPath $versionPath)) {
  $failures.Add('VERSION is missing')
} elseif (($kitVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()) -notmatch '^\d+\.\d+\.\d+$') {
  $failures.Add('VERSION must use semantic version format, for example 0.1.0')
}

$changelogPath = Join-Path $root 'CHANGELOG.md'
if (-not (Test-Path -LiteralPath $changelogPath)) {
  $failures.Add('CHANGELOG.md is missing')
} elseif ($null -ne $kitVersion -and -not ((Get-Content -LiteralPath $changelogPath -Raw) -match ('(?m)^## \[' + [regex]::Escape($kitVersion) + '\]'))) {
  $failures.Add("CHANGELOG.md does not contain a release heading for $kitVersion")
}

$expectedAgentProfiles = @{
  'team-architect' = @{ model = 'gpt-6.1-sol'; reasoning = 'xhigh' }
  'team-backend-engineer' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-database-specialist' = @{ model = 'gpt-6.1-sol'; reasoning = 'high' }
  'team-docs-maintainer' = @{ model = 'gpt-6-luna'; reasoning = 'high' }
  'team-explorer' = @{ model = 'gpt-6-luna'; reasoning = 'medium' }
  'team-frontend-engineer' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-reviewer' = @{ model = 'gpt-6.1-sol'; reasoning = 'high' }
  'team-tester' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
}

Get-ChildItem -Path (Join-Path $root 'agents') -Filter '*.toml' -File | ForEach-Object {
  $entries = @{}
  $allowedFields = @('name', 'description', 'model', 'model_reasoning_effort', 'sandbox_mode', 'developer_instructions')
  foreach ($line in Get-Content -LiteralPath $_.FullName) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) { continue }
    if ($line -notmatch '^([a-z_]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*$') {
      $failures.Add("$($_.Name) contains TOML outside the supported string-field subset")
      continue
    }

    $field = $Matches[1]
    $value = $Matches[2]
    if ($entries.ContainsKey($field)) {
      $failures.Add("$($_.Name) declares $field more than once")
    } else {
      $entries[$field] = $value
    }
    if ($allowedFields -notcontains $field) {
      $failures.Add("$($_.Name) declares unsupported field $field")
    }
  }

  foreach ($field in 'name', 'description', 'developer_instructions') {
    if (-not $entries.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($entries[$field])) {
      $failures.Add("$($_.Name) is missing non-empty $field")
    }
  }
  if (-not $entries.ContainsKey('name') -or $entries['name'] -notmatch '^team-[a-z0-9-]+$') {
    $failures.Add("$($_.Name) must declare a team- prefixed agent name")
  } elseif ($entries['name'] -ne $_.BaseName) {
    $failures.Add("$($_.Name) must match its declared agent name")
  }
  if ($expectedAgentProfiles.ContainsKey($_.BaseName)) {
    $expectedProfile = $expectedAgentProfiles[$_.BaseName]
    if ($entries['model'] -ne $expectedProfile.model -or $entries['model_reasoning_effort'] -ne $expectedProfile.reasoning) {
      $failures.Add("$($_.Name) does not match the required model profile")
    }
  } else {
    $failures.Add("$($_.Name) is not part of the supported team agent profile")
  }
}

Get-ChildItem -Path $root -Filter '*.md' -File -Recurse | ForEach-Object {
  $markdownFile = $_
  $content = Get-Content -LiteralPath $markdownFile.FullName -Raw
  foreach ($match in [regex]::Matches($content, '\[[^\]]*\]\(([^)]+)\)')) {
    $target = $match.Groups[1].Value.Trim()
    if ($target.StartsWith('#') -or $target -match '^[a-z][a-z0-9+.-]*:' -or $target.StartsWith('//')) { continue }
    $relativePath = ($target -split '[#?]', 2)[0]
    if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }
    $resolvedPath = Join-Path $markdownFile.DirectoryName ($relativePath -replace '/', '\\')
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
      $failures.Add("$($markdownFile.FullName) links to missing local path $relativePath")
    }
  }
}

$installer = Get-Content -LiteralPath (Join-Path $root 'scripts\install-user.ps1') -Raw
foreach ($requiredInstallerFeature in 'SupportsShouldProcess', '[switch]$Force', 'install-receipt.json') {
  if (-not $installer.Contains($requiredInstallerFeature)) {
    $failures.Add("install-user.ps1 is missing $requiredInstallerFeature")
  }
}

$updater = Join-Path $root 'scripts\update-user.ps1'
if (-not (Test-Path -LiteralPath $updater)) {
  $failures.Add('update-user.ps1 is missing')
} else {
  $updaterContent = Get-Content -LiteralPath $updater -Raw
  foreach ($requiredUpdaterFeature in 'SupportsShouldProcess', 'install-user.ps1', 'WhatIfPreference') {
    if (-not $updaterContent.Contains($requiredUpdaterFeature)) {
      $failures.Add("update-user.ps1 is missing $requiredUpdaterFeature")
    }
  }
}

Get-ChildItem -Path (Join-Path $root 'skills') -Directory | ForEach-Object {
  $skill = Join-Path $_.FullName 'SKILL.md'
  if (-not (Test-Path -LiteralPath $skill)) { $failures.Add("$($_.Name) is missing SKILL.md"); return }
  $content = Get-Content -Raw $skill
  if ($content -notmatch '(?s)^---\s*\r?\nname:\s*[a-z0-9-]+\s*\r?\ndescription:\s*.+?\r?\n---') {
    $failures.Add("$($_.Name) has invalid skill frontmatter")
  }
  if ($content -notmatch '(?m)^name:\s*([a-z0-9-]+)\s*$') {
    $failures.Add("$($_.Name) is missing a parseable skill name")
  } elseif ($Matches[1] -ne $_.Name) {
    $failures.Add("$($_.Name) must match its declared skill name")
  }

  # team-core supplies the shared references; every other directory is a
  # user-invokable skill and must expose the common harness explicitly.
  if ($_.Name -ne 'team-core') {
    foreach ($requiredHarnessElement in 'execution-contract.md', '## When to activate', '## Output contract') {
      if (-not $content.Contains($requiredHarnessElement)) {
        $failures.Add("$($_.Name) is missing required harness element: $requiredHarnessElement")
      }
    }
  }
}

$coreReferences = @('execution-contract.md', 'execution-templates.md', 'role-routing.md', 'file-ownership.md', 'handoff-format.md', 'feedback-recording.md', 'test-acceptance-contract.md', 'tdd-protocol.md')
$coreReferenceDirectory = Join-Path $root 'skills\team-core\references'
$coreReferences += 'project-blueprint.md'
$coreReferences += 'code-comments.md'
$coreReferences += 'ui-quality.md'
$coreReferences += 'documentation-governance.md'
foreach ($reference in $coreReferences) {
  if (-not (Test-Path -LiteralPath (Join-Path $coreReferenceDirectory $reference))) {
    $failures.Add("team-core is missing reference $reference")
  }
}

# Guard discovery routes and distribution; semantic readiness is checked by the Lead, not regexes.
# Losing a direct routing link must fail even when a replacement Markdown link
# resolves. This checks packaged discovery, not actual future spawn arguments.
foreach ($skillName in @('team-core','team-dev','team-plan','team-debug','team-review','team-doc-check')) {
  $target = if ($skillName -eq 'team-core') { 'references/role-routing.md' } else { '../team-core/references/role-routing.md' }
  $file = Join-Path $root "skills/$skillName/SKILL.md"
  if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or -not (Get-Content -LiteralPath $file -Raw).Contains("]($target)")) {
    $failures.Add("$skillName must link to role-routing.md")
  }
}
foreach ($skillName in @('team-core','team-plan','team-dev','team-review','team-doc-check')) {
  $target=if ($skillName -eq 'team-core') {'references/documentation-governance.md'} else {'../team-core/references/documentation-governance.md'}
  $file=Join-Path $root "skills/$skillName/SKILL.md"
  if (-not (Test-Path -LiteralPath $file) -or -not (Get-Content -LiteralPath $file -Raw).Contains("]($target)")) { $failures.Add("$skillName must link to documentation-governance.md") }
}
foreach ($resource in @('skills/team-doc-check/SKILL.md','skills/team-core/scripts/documentation.ps1','agents/team-docs-maintainer.toml')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) { $failures.Add("Missing documentation resource: $resource") }
}
$docsAgent=Join-Path $root 'agents/team-docs-maintainer.toml'
if (Test-Path -LiteralPath $docsAgent) {
  if (-not (Get-Content -LiteralPath $docsAgent -Raw).Contains('team-doc-check')) { $failures.Add('Docs maintainer must route to team-doc-check') }
}

foreach ($skillName in 'team-dev', 'team-plan', 'team-review', 'frontend-engineering', 'testing-engineering', 'team-core') {
  $blueprintSkill = Join-Path $root "skills/$skillName/SKILL.md"
  if (-not (Test-Path -LiteralPath $blueprintSkill) -or -not (Get-Content -LiteralPath $blueprintSkill -Raw).Contains('project-blueprint.md')) { $failures.Add("$skillName must reference project-blueprint.md") }
}
if (-not (Test-Path -LiteralPath (Join-Path $root 'skills/team-core/scripts/project-blueprint.ps1'))) { $failures.Add('Missing project-blueprint.ps1') }

# Require actual Markdown routes so a mere prose mention cannot hide a lost UI contract.
foreach ($skillName in 'team-dev', 'team-plan', 'team-review', 'team-core', 'frontend-engineering', 'code-review', 'testing-engineering', 'frontend-design') {
  $uiSkillPath = Join-Path $root "skills/$skillName/SKILL.md"
  $uiTarget = if ($skillName -eq 'team-core') { 'references/ui-quality.md' } else { '../team-core/references/ui-quality.md' }
  if (-not (Test-Path -LiteralPath $uiSkillPath) -or (Get-Content -LiteralPath $uiSkillPath -Raw) -notmatch ('\]\(' + [regex]::Escape($uiTarget) + '\)')) {
    $failures.Add("$skillName must link to ui-quality.md")
  }
}
$frontendAgentPath = Join-Path $root 'agents/team-frontend-engineer.toml'
if (-not (Test-Path -LiteralPath $frontendAgentPath) -or -not (Get-Content -LiteralPath $frontendAgentPath -Raw).Contains('frontend-design')) {
  $failures.Add('team-frontend-engineer must route visible UI work to frontend-design')
}

$tddWorkflowSkills = @('team-dev', 'team-plan', 'team-debug', 'team-review', 'testing-engineering')
# This guards contract discovery, not the semantic quality of code comments.
foreach ($skillName in 'team-core', 'team-dev', 'team-review', 'code-review', 'frontend-engineering', 'backend-engineering', 'database-engineering', 'testing-engineering') {
  $commentSkill = Join-Path $root "skills/$skillName/SKILL.md"
  if (-not (Test-Path -LiteralPath $commentSkill) -or -not (Get-Content -LiteralPath $commentSkill -Raw).Contains('code-comments.md')) {
    $failures.Add("$skillName must reference code-comments.md")
  }
}
foreach ($skillName in $tddWorkflowSkills) {
  $skillPath = Join-Path $root (Join-Path 'skills' (Join-Path $skillName 'SKILL.md'))
  if (-not (Test-Path -LiteralPath $skillPath)) {
    $failures.Add("TDD workflow Skill is missing: $skillName")
  } elseif (-not (Get-Content -LiteralPath $skillPath -Raw).Contains('tdd-protocol.md')) {
    $failures.Add("$skillName does not reference tdd-protocol.md")
  }
}

$stageVerification = Join-Path $root 'skills\team-core\scripts\stage-verification.ps1'
if (-not (Test-Path -LiteralPath $stageVerification)) {
  $failures.Add('team-core is missing scripts/stage-verification.ps1')
} else {
  $stageVerificationContent = Get-Content -LiteralPath $stageVerification -Raw
  foreach ($requiredStageFeature in "'Validate'", 'Final manual status:', 'TDD behavior matrix', 'Test-Packet') {
    if (-not $stageVerificationContent.Contains($requiredStageFeature)) {
      $failures.Add("stage-verification.ps1 is missing $requiredStageFeature")
    }
  }
}

$feedbackRuntime = Join-Path $root 'skills\team-core\scripts\feedback-runtime.ps1'
# Guard optional integration distribution and discoverable routing; runtime tests check behavior.
foreach ($relative in @('references/spec-lifecycle.md','references/openspec-integration.md','scripts/openspec-adapter.ps1','scripts/openspec-common.ps1','scripts/spec-traceability.ps1','templates/openspec/config.yaml')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root "skills/team-core/$relative") -PathType Leaf)) { $failures.Add("Missing optional OpenSpec resource: $relative") }
}
foreach ($skillName in @('team-core','team-plan','team-dev','team-review','testing-engineering','code-review')) {
  $target = if ($skillName -eq 'team-core') { 'references/spec-lifecycle.md' } else { '../team-core/references/spec-lifecycle.md' }
  if ((Get-Content -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Raw) -notmatch ('\]\(' + [regex]::Escape($target) + '\)')) { $failures.Add("$skillName must link to spec-lifecycle.md") }
}
if (-not (Test-Path -LiteralPath $feedbackRuntime)) {
  $failures.Add('team-core is missing scripts/feedback-runtime.ps1')
} else {
  $runtimeContent = Get-Content -LiteralPath $feedbackRuntime -Raw
  foreach ($requiredRuntimeFeature in "'Record'", "'Maintain'", "'SetCandidateState'", 'ConfirmDeletion', 'projectPathDigest') {
    if (-not $runtimeContent.Contains($requiredRuntimeFeature)) {
      $failures.Add("feedback-runtime.ps1 is missing $requiredRuntimeFeature")
    }
  }
}

Get-ChildItem -Path (Join-Path $root 'skills') -Filter 'SKILL.md' -Recurse -File | ForEach-Object {
  $content = Get-Content -Raw $_.FullName
  if ($content -match 'policies/') { $failures.Add("$($_.FullName) references unpackaged policies/") }
}

Get-ChildItem -Path (Join-Path $root 'agents') -Filter '*.toml' -File | ForEach-Object {
  $content = Get-Content -Raw $_.FullName
  if ($content -match 'policies/') { $failures.Add("$($_.Name) references unpackaged policies/") }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'Codex Team Kit validation passed.'
