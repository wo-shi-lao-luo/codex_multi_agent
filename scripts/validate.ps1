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
  'team-code-maintainer' = @{ model = 'gpt-6-luna'; reasoning = 'medium' }
  'team-delivery-checker' = @{ model = 'gpt-6-luna'; reasoning = 'high' }
  'team-database-specialist' = @{ model = 'gpt-6.1-sol'; reasoning = 'high' }
  'team-docs-maintainer' = @{ model = 'gpt-6-luna'; reasoning = 'high' }
  'team-explorer' = @{ model = 'gpt-6-luna'; reasoning = 'medium' }
  'team-frontend-engineer' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-reviewer' = @{ model = 'gpt-6.1-sol'; reasoning = 'high' }
  'team-tester' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-ai-tester' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-ai-engineer' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-ai-simulation-actor-basic' = @{ model = 'gpt-6-luna'; reasoning = 'medium' }
  'team-ai-simulation-actor-advanced' = @{ model = 'gpt-6.1-sol'; reasoning = 'medium' }
  'team-ai-architect' = @{ model = 'gpt-6.1-sol'; reasoning = 'xhigh' }
}

# The thin entry adds discoverable contracts, not an executable intent router.
# Keep every direct entry available and check concrete links rather than wording.
$directTeamEntries = @(
  'team-plan', 'team-dev', 'team-debug', 'team-review', 'team-doc-check',
  'team-project-rules', 'team-code-maintain', 'team-delivery-check', 'team-ai-simulate'
)
$teamEntryResources = @(
  'skills/team/SKILL.md'
  'skills/team/agents/openai.yaml'
  'skills/team-core/references/workflow-routing.md'
)
foreach ($entry in $directTeamEntries) {
  $teamEntryResources += "skills/$entry/SKILL.md"
}
foreach ($resource in $teamEntryResources) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) {
    $failures.Add("Missing unified Team resource: $resource")
  }
}
$teamEntryRoutes = @(
  @{
    path = 'skills/team/SKILL.md'
    target = '../team-core/references/workflow-routing.md'
  }
  @{
    path = 'skills/team/SKILL.md'
    target = '../team-core/references/execution-contract.md'
  }
  @{
    path = 'skills/team-core/SKILL.md'
    target = 'references/workflow-routing.md'
  }
  @{
    path = 'skills/team-core/references/role-routing.md'
    target = 'workflow-routing.md'
  }
)
foreach ($entry in $directTeamEntries) {
  $teamEntryRoutes += @{
    path = 'skills/team-core/references/workflow-routing.md'
    target = "../../$entry/SKILL.md"
  }
}
foreach ($reference in @('repair-loop-guard.md','feedback-recording.md','role-routing.md')) {
  $teamEntryRoutes += @{
    path = 'skills/team-core/references/workflow-routing.md'
    target = $reference
  }
}
foreach ($route in $teamEntryRoutes) {
  $path = Join-Path $root $route.path
  $content = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw
  } else { $null }
  if ([string]::IsNullOrWhiteSpace($content) -or
      -not $content.Contains("]($($route.target))")) {
    $failures.Add("$($route.path) must link to $($route.target)")
  }
}

# Delivery guards establish package integrity, not semantic/runtime acceptance.
foreach ($resource in @(
  'agents/team-delivery-checker.toml'
  'skills/team-delivery-check/SKILL.md'
  'skills/team-core/references/git-delivery.md'
  'skills/team-core/scripts/git-delivery.ps1'
)) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) {
    $failures.Add("Missing Git delivery resource: $resource")
  }
}
foreach ($skillName in @('team-core','team-dev','team-review','team-delivery-check')) {
  $path = Join-Path $root "skills/$skillName/SKILL.md"
  $target = if ($skillName -eq 'team-core') {
    'references/git-delivery.md'
  } else { '../team-core/references/git-delivery.md' }
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
      -not (Get-Content -LiteralPath $path -Raw).Contains("]($target)")) {
    $failures.Add("$skillName must link to git-delivery.md")
  }
}
foreach ($skillName in @('team-core','team-dev','team-review')) {
  $path = Join-Path $root "skills/$skillName/SKILL.md"
  if ((Test-Path -LiteralPath $path -PathType Leaf) -and
      -not (Get-Content -LiteralPath $path -Raw).Contains('](../team-delivery-check/SKILL.md)')) {
    $failures.Add("$skillName must conditionally route to team-delivery-check")
  }
}
$deliveryRouting = Join-Path $root 'skills/team-core/references/role-routing.md'
if ((Test-Path -LiteralPath $deliveryRouting -PathType Leaf) -and
    -not (Get-Content -LiteralPath $deliveryRouting -Raw).Contains('](git-delivery.md)')) {
  $failures.Add('role-routing must link to git-delivery.md')
}
$deliveryPolicy = Join-Path $root 'skills/team-delivery-check/agents/openai.yaml'
if ((Test-Path -LiteralPath $deliveryPolicy -PathType Leaf) -and
    (Get-Content -LiteralPath $deliveryPolicy -Raw) -match 'allow_implicit_invocation\s*:\s*false') {
  $failures.Add('team-delivery-check must permit implicit invocation')
}

# New workflow assets must be shipped together; routing prose is not execution proof.
foreach ($resource in @('skills/team-ai-simulate/SKILL.md','skills/ai-engineering/SKILL.md','agents/team-ai-engineer.toml','agents/team-ai-simulation-actor-basic.toml','agents/team-ai-simulation-actor-advanced.toml','agents/team-ai-architect.toml','skills/team-core/scripts/ai-simulation.ps1','skills/team-core/references/ai-simulation.md','skills/team-core/templates/ai-simulation/definition.json')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) { $failures.Add("Missing AI simulation resource: $resource") }
}
# Retired source names would create duplicate discovery routes in a new install.
# Deployment tests separately establish removal of old receipt-owned payload files.
foreach ($obsolete in @('skills/team-simulate','agents/team-simulation-actor.toml')) {
  if (Test-Path -LiteralPath (Join-Path $root $obsolete)) { $failures.Add("Obsolete AI simulation source resource: $obsolete") }
}
foreach ($profile in $expectedAgentProfiles.Keys) {
  if (-not (Test-Path -LiteralPath (Join-Path $root "agents/$profile.toml") -PathType Leaf)) { $failures.Add("Missing required agent profile: $profile") }
}
# Guard actual reference links rather than accepting an unconnected prose mention.
foreach ($skillName in @('team-core','team-ai-simulate','ai-engineering')) {
  $path=Join-Path $root "skills/$skillName/SKILL.md"
  $target=if ($skillName -eq 'team-core') { 'references/ai-simulation.md' } else { '../team-core/references/ai-simulation.md' }
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Content -LiteralPath $path -Raw) -notmatch ('\]\(' + [regex]::Escape($target) + '\)')) { $failures.Add("$skillName must link to ai-simulation.md") }
}
$aiAgentPath=Join-Path $root 'agents/team-ai-engineer.toml'
if ((Test-Path -LiteralPath $aiAgentPath -PathType Leaf) -and -not (Get-Content -LiteralPath $aiAgentPath -Raw).Contains('ai-engineering')) { $failures.Add('team-ai-engineer must route to ai-engineering') }

# AI capability guidance is one distribution unit. Resource/link guards only
# establish discovery, never native adherence, replay safety or AI quality.
foreach ($resource in @(
  'skills/team-core/references/ai-capability-contract.md'
  'skills/team-core/references/ai-record-replay-testing.md'
  'skills/team-core/templates/ai-capability/contract-brief.md'
  'skills/team-core/templates/ai-capability/record-replay-plan.md'
)) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) {
    $failures.Add("Missing AI capability resource: $resource")
  }
}
foreach ($route in @(
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-capability-contract.md' },
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-record-replay-testing.md' },
  @{
    path = 'skills/ai-engineering/SKILL.md'
    target = '../team-core/references/ai-capability-contract.md'
  },
  @{
    path = 'skills/backend-engineering/SKILL.md'
    target = '../team-core/references/ai-capability-contract.md'
  },
  @{
    path = 'skills/testing-engineering/SKILL.md'
    target = '../team-core/references/ai-record-replay-testing.md'
  },
  @{
    path = 'skills/team-core/references/test-acceptance-contract.md'
    target = 'ai-record-replay-testing.md'
  },
  @{
    path = 'skills/team-core/references/ai-capability-contract.md'
    target = '../templates/ai-capability/contract-brief.md'
  },
  @{
    path = 'skills/team-core/references/ai-record-replay-testing.md'
    target = '../templates/ai-capability/record-replay-plan.md'
  }
)) {
  $path = Join-Path $root $route.path
  $content = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw
  } else { $null }
  if ([string]::IsNullOrWhiteSpace($content) -or
      -not $content.Contains("]($($route.target))")) {
    $failures.Add("$($route.path) must link to $($route.target)")
  }
}

# AI evaluation distribution guards are not behavior-quality or native-role proof.
foreach ($resource in @(
  'agents/team-ai-tester.toml'
  'skills/ai-testing-engineering/SKILL.md'
  'skills/ai-testing-engineering/agents/openai.yaml'
  'skills/team-core/references/ai-evaluation.md'
)) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) {
    $failures.Add("Missing AI evaluation resource: $resource")
  }
}
foreach ($route in @(
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-evaluation.md' },
  @{
    path = 'skills/ai-testing-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  },
  @{
    path = 'skills/ai-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  },
  @{
    path = 'skills/testing-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  },
  @{
    path = 'skills/team-ai-simulate/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  },
  @{ path = 'skills/team-core/references/execution-contract.md'; target = 'ai-evaluation.md' },
  @{ path = 'skills/team-core/references/test-acceptance-contract.md'; target = 'ai-evaluation.md' },
  @{ path = 'skills/team-core/references/role-routing.md'; target = 'ai-evaluation.md' }
)) {
  $path = Join-Path $root $route.path
  $content = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw
  } else { $null }
  if ([string]::IsNullOrWhiteSpace($content) -or
      -not $content.Contains("]($($route.target))")) {
    $failures.Add("$($route.path) must link to $($route.target)")
  }
}
$aiTesterPath = Join-Path $root 'agents/team-ai-tester.toml'
if ((Test-Path -LiteralPath $aiTesterPath -PathType Leaf) -and
    -not (Get-Content -LiteralPath $aiTesterPath -Raw).Contains('ai-testing-engineering')) {
  $failures.Add('team-ai-tester must route to ai-testing-engineering')
}

# Migration guidance must ship with its intended conditional discovery routes.
# These structural guards do not establish semantic completeness or native use.
$migrationResource = 'skills/team-core/references/architecture-migration.md'
$migrationPath = Join-Path $root $migrationResource
if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
  $failures.Add("Missing architecture migration resource: $migrationResource")
} elseif ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $migrationPath -Raw))) {
  $failures.Add("Empty architecture migration resource: $migrationResource")
}
$migrationRoutes = @(
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
foreach ($route in $migrationRoutes) {
  $path = Join-Path $root $route.path
  $content = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw
  } else { $null }
  if ([string]::IsNullOrWhiteSpace($content) -or
      -not $content.Contains("]($($route.target))")) {
    $failures.Add("$($route.path) must link to $($route.target)")
  }
}

# Readability resources form one discovery unit; these checks do not prove
# runtime role loading or that a future edit preserves application behavior.
$readabilityResources = @(
  'skills/team-code-maintain/SKILL.md'
  'skills/team-code-maintain/agents/openai.yaml'
  'skills/team-core/references/code-readability.md'
  'skills/team-core/references/formatter-tool.md'
  'skills/team-core/scripts/format-code.ps1'
  'skills/team-core/scripts/format-code-powershell.ps1'
  'agents/team-code-maintainer.toml'
)
foreach ($resource in $readabilityResources) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) {
    $failures.Add("Missing code-readability resource: $resource")
  }
}

$readabilitySkills = @(
  'team-core'
  'team-dev'
  'team-code-maintain'
  'team-review'
  'code-review'
  'frontend-engineering'
  'backend-engineering'
  'database-engineering'
  'ai-engineering'
  'testing-engineering'
)
foreach ($skillName in $readabilitySkills) {
  $path = Join-Path $root "skills/$skillName/SKILL.md"
  $target = if ($skillName -eq 'team-core') {
    'references/code-readability.md'
  } else {
    '../team-core/references/code-readability.md'
  }
  $content = if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Content -LiteralPath $path -Raw
  } else { $null }
  if ([string]::IsNullOrWhiteSpace($content) -or -not $content.Contains("]($target)")) {
    $failures.Add("$skillName must link to code-readability.md")
  }
}

$executionPath = Join-Path $root 'skills/team-core/references/execution-contract.md'
$executionContent = if (Test-Path -LiteralPath $executionPath -PathType Leaf) {
  Get-Content -LiteralPath $executionPath -Raw
} else { $null }
if ([string]::IsNullOrWhiteSpace($executionContent) -or -not $executionContent.Contains('](code-readability.md)')) {
  $failures.Add('execution-contract.md must link to code-readability.md')
}

# Inspect table cells and exact identifiers, without matching routing prose.
$routingPath = Join-Path $root 'skills/team-core/references/role-routing.md'
$hasMaintainerMapping = $false
if (Test-Path -LiteralPath $routingPath -PathType Leaf) {
  foreach ($line in Get-Content -LiteralPath $routingPath) {
    if ($line -notmatch '^\s*\|') { continue }
    $cells = $line.Split('|')
    if ($cells.Count -eq 4 -and
        $cells[1] -match '(?<![a-z0-9-])team-code-maintain(?![a-z0-9-])' -and
        $cells[2].Contains('`team-code-maintainer`')) {
      $hasMaintainerMapping = $true
    }
  }
}
if (-not $hasMaintainerMapping) {
  $failures.Add('role-routing.md must map team-code-maintain to team-code-maintainer')
}

# Support the shipped policy mapping subset and unrelated interface metadata.
# Duplicate sections/flags and flags outside policy must not enable discovery.
$invocationPolicies = @(
  @{ skill = 'team-code-maintain'; expected = 'true' }
  @{ skill = 'team'; expected = 'true' }
)
foreach ($invocationPolicy in $invocationPolicies) {
  $implicitRoutePath = Join-Path $root "skills/$($invocationPolicy.skill)/agents/openai.yaml"
  if (-not (Test-Path -LiteralPath $implicitRoutePath -PathType Leaf)) { continue }
  $policyCount = 0
  $flagCount = 0
  $inPolicy = $false
  $validPolicy = $true
  foreach ($line in Get-Content -LiteralPath $implicitRoutePath) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) { continue }
    if ($line -match '^policy\s*:') {
      $policyCount++
      $inPolicy = $true
      if ($line -notmatch '^policy:\s*(?:#.*)?$') { $validPolicy = $false }
      continue
    }
    if ($line -match '^\S') { $inPolicy = $false }
    if ($line -match '^\s*allow_implicit_invocation\s*:') {
      $flagCount++
      $expectedFlag = '^  allow_implicit_invocation:\s*' +
        $invocationPolicy.expected + '\s*(?:#.*)?$'
      if (-not $inPolicy -or $line -notmatch $expectedFlag) {
        $validPolicy = $false
      }
    } elseif ($inPolicy) {
      $validPolicy = $false
    }
  }
  if ($policyCount -ne 1 -or $flagCount -ne 1 -or -not $validPolicy) {
    $failures.Add(
      "$($invocationPolicy.skill) must declare one policy allow_implicit_invocation: $($invocationPolicy.expected)"
    )
  }
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
    # Actors and the AI design specialist observe bounded evidence; they are not
    # production writers. A stronger actor model must not broaden its permissions.
    if ($_.BaseName -in @('team-ai-simulation-actor-basic','team-ai-simulation-actor-advanced','team-ai-architect','team-delivery-checker') -and $entries['sandbox_mode'] -ne 'read-only') {
      $failures.Add("$($_.Name) must declare read-only sandbox mode")
    }
    if ($_.BaseName -in @('team-ai-simulation-actor-basic','team-ai-simulation-actor-advanced','team-ai-architect') -and -not ([string]$entries['developer_instructions']).Contains('team-ai-simulate')) {
      $failures.Add("$($_.Name) must route explicit simulations to team-ai-simulate")
    }
    if ($_.BaseName -eq 'team-ai-architect' -and -not ([string]$entries['developer_instructions']).Contains('ai-engineering')) {
      $failures.Add('team-ai-architect must reference ai-engineering domain guidance')
    }
    if ($_.BaseName -eq 'team-delivery-checker') {
      foreach ($route in @('team-delivery-check', 'git-delivery.md', 'git-delivery.ps1')) {
        if (-not ([string]$entries['developer_instructions']).Contains($route)) {
          $failures.Add("team-delivery-checker must reference $route")
        }
      }
    }
    if ($_.BaseName -eq 'team-code-maintainer') {
      if ($entries.ContainsKey('sandbox_mode') -and $entries['sandbox_mode'] -ne 'workspace-write') {
        $failures.Add('team-code-maintainer must retain writable sandbox permissions')
      }
      foreach ($route in @('team-code-maintain', 'code-readability.md', 'format-code.ps1')) {
        if (-not ([string]$entries['developer_instructions']).Contains($route)) {
          $failures.Add("team-code-maintainer must reference $route")
        }
      }
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
$coreReferences += 'project-rules.md'
$coreReferences += 'design-exploration.md'
foreach ($reference in $coreReferences) {
  if (-not (Test-Path -LiteralPath (Join-Path $coreReferenceDirectory $reference))) {
    $failures.Add("team-core is missing reference $reference")
  }
}

# These routes make the shared exploration contract reachable at planning and
# development checkpoints. Structural links do not establish semantic compliance.
foreach ($route in @(
  @{ path='skills/team-core/SKILL.md'; target='references/design-exploration.md' },
  @{ path='skills/team-plan/SKILL.md'; target='../team-core/references/design-exploration.md' },
  @{ path='skills/team-dev/SKILL.md'; target='../team-core/references/design-exploration.md' },
  @{ path='skills/team-core/references/execution-contract.md'; target='design-exploration.md' }
)) {
  $path=Join-Path $root $route.path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Content -LiteralPath $path -Raw) -notmatch ('\]\(' + [regex]::Escape($route.target) + '\)')) {
    $failures.Add("$($route.path) must link to $($route.target)")
  }
}

# Guard discovery routes and distribution; semantic readiness is checked by the Lead, not regexes.
# Losing a direct routing link must fail even when a replacement Markdown link
# resolves. This checks packaged discovery, not actual future spawn arguments.
foreach ($skillName in @('team-core','team-dev','team-plan','team-debug','team-review','team-doc-check','team-project-rules')) {
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
# Ship the narrow local-artifact boundary and its writer routes. This verifies
# packaging/discovery only; real Git tests establish policy and index behavior.
$artifactHelper = Join-Path $root 'skills/team-core/scripts/generated-artifacts.ps1'
if (-not (Test-Path -LiteralPath $artifactHelper -PathType Leaf)) { $failures.Add('Missing generated-artifacts.ps1') }
foreach ($caller in @('documentation.ps1','openspec-adapter.ps1')) {
  $callerPath = Join-Path $root "skills/team-core/scripts/$caller"
  # Missing/empty resources are normal package failures, not null dereferences.
  $callerContent = if (Test-Path -LiteralPath $callerPath -PathType Leaf) { Get-Content -LiteralPath $callerPath -Raw } else { $null }
  if ([string]::IsNullOrWhiteSpace($callerContent) -or -not $callerContent.Contains("'generated-artifacts.ps1'")) { $failures.Add("$caller must route writer protection to generated-artifacts.ps1") }
}
$artifactContract = Join-Path $root 'skills/team-core/references/generated-artifacts.md'
if (-not (Test-Path -LiteralPath $artifactContract -PathType Leaf)) { $failures.Add('Missing generated-artifacts.md contract') }
foreach ($skillName in @('team-core','team-dev','team-doc-check')) {
  $target = if ($skillName -eq 'team-core') { 'references/generated-artifacts.md' } else { '../team-core/references/generated-artifacts.md' }
  $file = Join-Path $root "skills/$skillName/SKILL.md"
  $skillContent = if (Test-Path -LiteralPath $file -PathType Leaf) { Get-Content -LiteralPath $file -Raw } else { $null }
  if ([string]::IsNullOrWhiteSpace($skillContent) -or -not $skillContent.Contains("]($target)")) { $failures.Add("$skillName must link to generated-artifacts.md") }
}
# Require packaged instruction discovery plus real Markdown routes. This guards
# discovery/distribution only; it cannot authenticate approval or runtime loading.
foreach ($resource in @('skills/team-project-rules/SKILL.md','skills/team-core/scripts/project-rules.ps1')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) { $failures.Add("Missing project-rules resource: $resource") }
}
foreach ($skillName in @('team-core','team-doc-check','team-dev','team-plan','team-project-rules')) {
  $target = if ($skillName -eq 'team-core') { 'references/project-rules.md' } else { '../team-core/references/project-rules.md' }
  $file = Join-Path $root "skills/$skillName/SKILL.md"
  if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Content -LiteralPath $file -Raw) -notmatch ('\]\(' + [regex]::Escape($target) + '\)')) { $failures.Add("$skillName must link to project-rules.md") }
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
