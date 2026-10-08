# Validate package contracts in a disposable copy; no real installation is modified.
[CmdletBinding()]
param([switch]$DesignExplorationOnly)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = "codex-multi-agent-validate-test-" + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName
$validator = Join-Path $testRoot 'scripts\validate.ps1'

function Assert-Condition {
  # Abort a scenario when its observable package-validation result is wrong.
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-CopiedValidator {
  # Return success as a Boolean while preserving the caller's error/exit state.
  $previousErrorActionPreference = $ErrorActionPreference
  $previousLastExitCode = $global:LASTEXITCODE
  try {
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    & $validator 2>&1 | Out-Null
    return ($global:LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    $global:LASTEXITCODE = $previousLastExitCode
  }
}

try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  # Copy both release histories because reciprocal language navigation is a real local link;
  # this fixture completeness does not make Chinese documentation an installer prerequisite.
  foreach ($item in 'agents', 'skills', 'scripts', 'VERSION', 'CHANGELOG.md', 'CHANGELOG.zh-CN.md') {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $testRoot -Recurse -Force -ErrorAction Stop
  }
  # Fixture completeness: current release links a real repository guide and its packet.
  # Expected: copied source paths resolve without fabricated files or relaxed validation.
  foreach ($relative in @('docs/formatter-tool.md', 'docs/verification/active/formatter-tool.md')) {
    $destination = Join-Path $testRoot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination
  }

  # Scenario: an intact package. Expected: validation succeeds before mutations.
  Assert-Condition (Invoke-CopiedValidator) 'Baseline validation failed in an isolated package copy.'

  # DE-01: a copied package without the required shared design reference is incomplete.
  # Expected: the real package validator rejects omission, then accepts exact restoration.
  $designReference=Join-Path $testRoot 'skills/team-core/references/design-exploration.md'
  if(Test-Path -LiteralPath $designReference){Remove-Item -LiteralPath $designReference -Force}
  Assert-Condition (-not(Invoke-CopiedValidator)) 'DE-01 validator accepted missing design-exploration reference.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/design-exploration.md') -Destination $designReference -Force
  Assert-Condition (Invoke-CopiedValidator) 'DE-01 validator did not recover after reference restoration.'

  # DE-01: each declared Team/shared execution entrypoint loses its Markdown resource route.
  # Expected: even a plain-prose mention cannot satisfy the concrete local-link contract.
  foreach($route in @(
    @{path='skills/team-core/SKILL.md';target='references/design-exploration.md'},
    @{path='skills/team-plan/SKILL.md';target='../team-core/references/design-exploration.md'},
    @{path='skills/team-dev/SKILL.md';target='../team-core/references/design-exploration.md'},
    @{path='skills/team-core/references/execution-contract.md';target='design-exploration.md'}
  )){
    $routePath=Join-Path $testRoot $route.path
    $routeText=Get-Content -LiteralPath $routePath -Raw
    $linkPattern='\[[^\]]+\]\('+[regex]::Escape($route.target)+'\)'
    Assert-Condition ($routeText -match $linkPattern) "Missing baseline design route in $($route.path)."
    $withoutLink=[regex]::Replace($routeText,$linkPattern,'design-exploration.md (unlinked mention)')
    Set-Content -LiteralPath $routePath -Value $withoutLink -Encoding utf8
    Assert-Condition (-not(Invoke-CopiedValidator)) "Validator accepted unlinked design route in $($route.path)."
    Copy-Item -LiteralPath (Join-Path $root $route.path) -Destination $routePath -Force
    Assert-Condition (Invoke-CopiedValidator) "Validator failed after restoring design route in $($route.path)."
  }
  if($DesignExplorationOnly){Write-Output 'Design-exploration package guard tests passed.';return}

  # SIM-08: an obsolete but syntactically valid workflow must not coexist with its new AI-only name.
  # Expected: validator rejects the extra retired unit and accepts removal of that owned fixture.
  $retiredUnit=Join-Path $testRoot 'skills/team-simulate'
  New-Item -ItemType Directory -Path $retiredUnit | Out-Null
  Set-Content -LiteralPath (Join-Path $retiredUnit 'SKILL.md') -Value "---`nname: team-simulate`ndescription: Retired synthetic workflow fixture.`n---`n# Retired workflow" -Encoding utf8
  Assert-Condition (-not(Invoke-CopiedValidator)) 'Validator accepted obsolete team-simulate unit.'
  $resolvedRetired=[IO.Path]::GetFullPath($retiredUnit)
  Assert-Condition ($resolvedRetired -eq [IO.Path]::GetFullPath((Join-Path $testRoot 'skills/team-simulate'))) 'Unsafe retired-unit fixture cleanup.'
  Remove-Item -LiteralPath $resolvedRetired -Recurse -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validator failed after removing obsolete workflow fixture.'

  # SIM-08: basic/advanced actors and AI architect must not acquire production-write permissions.
  # Expected: validator rejects each writable sandbox mutation and accepts exact restoration.
  foreach ($role in 'team-ai-simulation-actor-basic','team-ai-simulation-actor-advanced','team-ai-architect') {
    $rolePath=Join-Path $testRoot "agents/$role.toml"
    $roleText=Get-Content -LiteralPath $rolePath -Raw
    Assert-Condition ($roleText.Contains('sandbox_mode = "read-only"')) "$role lacks declared readonly sandbox."
    Set-Content -LiteralPath $rolePath -Value ($roleText.Replace('sandbox_mode = "read-only"','sandbox_mode = "workspace-write"')) -Encoding utf8
    Assert-Condition (-not(Invoke-CopiedValidator)) "Validator accepted write permissions for $role."
    Copy-Item -LiteralPath (Join-Path $root "agents/$role.toml") -Destination $rolePath -Force
    Assert-Condition (Invoke-CopiedValidator) "Validator failed after restoring readonly $role."
  }

  # SIM-01: required optional-simulation payload assets disappear one at a time.
  # Expected: validator rejects each omission and recovers after exact restoration.
  foreach ($relative in @('skills/team-ai-simulate/SKILL.md','skills/ai-engineering/SKILL.md','agents/team-ai-simulation-actor-basic.toml','agents/team-ai-simulation-actor-advanced.toml','agents/team-ai-architect.toml','agents/team-ai-engineer.toml','skills/team-core/scripts/ai-simulation.ps1')) {
    $asset = Join-Path $testRoot $relative
    Remove-Item -LiteralPath $asset -Force
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing simulation asset $relative."
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $asset -Force
    Assert-Condition (Invoke-CopiedValidator) "Validation did not recover after restoring $relative."
  }

  # Scenario: the required local artifact protection helper is absent from the payload.
  # Expected: package validation fails and recovers after restoring the exact source helper.
  $artifactHelper = Join-Path $testRoot 'skills/team-core/scripts/generated-artifacts.ps1'
  Remove-Item -LiteralPath $artifactHelper -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted missing artifact protection helper.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/scripts/generated-artifacts.ps1') -Destination $artifactHelper -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation did not recover after restoring artifact protection helper.'

  # Scenario: a required Team workflow replaces its role-routing link with an existing valid link.
  # Expected: package validation rejects a missing named-role route, then accepts its restoration.
  foreach ($skillName in 'team-dev', 'team-core', 'team-plan', 'team-debug', 'team-review', 'team-doc-check', 'team-project-rules') {
    $roleSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalRoleSkill = Get-Content -LiteralPath $roleSkill -Raw
    Assert-Condition ($originalRoleSkill.Contains('role-routing.md')) "Required role-routing route is absent in $skillName."
    Set-Content -LiteralPath $roleSkill -Value ($originalRoleSkill.Replace('role-routing.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing named-role routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $roleSkill -Force
    Assert-Condition (Invoke-CopiedValidator) "Validation failed after restoring named-role routing in $skillName."
  }

  # Scenario: the shared handoff contract disappears from an otherwise complete package.
  # Expected: validation rejects the missing contract and recovers after exact restoration.
  $roleHandoff = Join-Path $testRoot 'skills/team-core/references/handoff-format.md'
  Remove-Item -LiteralPath $roleHandoff -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing shared handoff contract.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/handoff-format.md') -Destination $roleHandoff -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation failed after restoring the shared handoff contract.'

  # Scenario: shipped roles use the approved GPT-6 allocation.
  # Expected: Architect uses 6.1 Sol/xhigh, Tester stays medium, and Explorer retains Luna/medium.
  $approvedProfiles = @{
    'team-architect' = @('gpt-6.1-sol', 'xhigh')
    'team-backend-engineer' = @('gpt-6.1-sol', 'medium')
    'team-database-specialist' = @('gpt-6.1-sol', 'high')
    'team-docs-maintainer' = @('gpt-6-luna', 'high')
    'team-explorer' = @('gpt-6-luna', 'medium')
    'team-frontend-engineer' = @('gpt-6.1-sol', 'medium')
    'team-reviewer' = @('gpt-6.1-sol', 'high')
    'team-tester' = @('gpt-6.1-sol', 'medium')
    'team-ai-simulation-actor-basic' = @('gpt-6-luna', 'medium')
    'team-ai-simulation-actor-advanced' = @('gpt-6.1-sol', 'medium')
    'team-ai-architect' = @('gpt-6.1-sol', 'xhigh')
    'team-ai-engineer' = @('gpt-6.1-sol', 'medium')
  }
  foreach ($role in $approvedProfiles.Keys) {
    $agentPath = Join-Path $testRoot "agents/$role.toml"
    $agentContent = Get-Content -LiteralPath $agentPath -Raw
    $profile = $approvedProfiles[$role]
    Assert-Condition ($agentContent -match ('(?m)^model = "' + [regex]::Escape($profile[0]) + '"\r?$')) "$role has an unexpected model."
    Assert-Condition ($agentContent -match ('(?m)^model_reasoning_effort = "' + $profile[1] + '"\r?$')) "$role has an unexpected reasoning effort."

    # Scenario: a role silently reverts to a legacy model or a different effort.
    # Expected: validation rejects either drift and accepts the restored role.
    foreach ($mutation in @(
      $agentContent.Replace('model = "' + $profile[0] + '"', 'model = "gpt-5.6-sol"'),
      $agentContent.Replace('model_reasoning_effort = "' + $profile[1] + '"', 'model_reasoning_effort = "low"')
    )) {
      Set-Content -LiteralPath $agentPath -Value $mutation -Encoding utf8
      Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted model-profile drift in $role."
    }
    Copy-Item -LiteralPath (Join-Path $root "agents/$role.toml") -Destination $agentPath -Force
    Assert-Condition (Invoke-CopiedValidator) "Validation failed after restoring $role."
  }

  # Scenario: a documentation entrypoint or route disappears. Expected: reject each omission, accept restoration.
  foreach ($relative in @('skills/team-doc-check/SKILL.md','skills/team-core/scripts/documentation.ps1','agents/team-docs-maintainer.toml')) {
    $file=Join-Path $testRoot $relative
    Remove-Item -LiteralPath $file
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing $relative."
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $file
    Assert-Condition (Invoke-CopiedValidator) "Validation failed after restoring $relative."
  }
  foreach ($name in @('team-core','team-dev','team-plan','team-review','team-doc-check')) {
    $file=Join-Path $testRoot "skills/$name/SKILL.md"
    $text=Get-Content -LiteralPath $file -Raw
    Set-Content -LiteralPath $file -Value ($text.Replace('documentation-governance.md','execution-contract.md'))
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing docs route in $name."
    Copy-Item -LiteralPath (Join-Path $root "skills/$name/SKILL.md") -Destination $file -Force
  }
  Assert-Condition (Invoke-CopiedValidator) 'Restored documentation routes did not validate.'

  # Scenario: target-project instruction capability loses a distributed resource.
  # Expected: reject each omission and accept exact restoration, without installing anything.
  foreach ($relative in @('skills/team-project-rules/SKILL.md','skills/team-core/references/project-rules.md','skills/team-core/scripts/project-rules.ps1')) {
    $file=Join-Path $testRoot $relative
    Remove-Item -LiteralPath $file
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing project-rule resource $relative."
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $file
    Assert-Condition (Invoke-CopiedValidator) "Validation did not recover after restoring $relative."
  }
  # Scenario: a workflow substitutes another valid local link for project-rule routing.
  # Expected: reject the missing route; ordinary Markdown link validity is insufficient.
  foreach ($name in @('team-core','team-dev','team-plan','team-doc-check','team-project-rules')) {
    $file=Join-Path $testRoot "skills/$name/SKILL.md"
    $text=Get-Content -LiteralPath $file -Raw
    Assert-Condition ($text.Contains('project-rules.md')) "Required project-rule route absent in $name."
    Set-Content -LiteralPath $file -Value ($text.Replace('project-rules.md','execution-contract.md'))
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing project-rule route in $name."
    Copy-Item -LiteralPath (Join-Path $root "skills/$name/SKILL.md") -Destination $file -Force
  }
  Assert-Condition (Invoke-CopiedValidator) 'Restored project-rule routing did not validate.'

  # Scenario: each UI workflow loses its contract route while links remain valid.
  # Expected: reject each mutation, and accept the restored package.
  foreach ($skillName in 'team-dev', 'team-plan', 'team-review', 'team-core', 'frontend-engineering', 'code-review', 'testing-engineering', 'frontend-design') {
    $uiSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalUiSkill = Get-Content -LiteralPath $uiSkill -Raw
    Set-Content -LiteralPath $uiSkill -Value ($originalUiSkill.Replace('ui-quality.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing UI routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $uiSkill -Force
  }
  Assert-Condition (Invoke-CopiedValidator) 'Validation failed after restoring UI routes.'

  # Scenario: a missing design entrypoint or shared UI contract.
  # Expected: reject the package; restoring each file restores successful validation.
  foreach ($relativePath in 'skills/frontend-design/SKILL.md', 'skills/team-core/references/ui-quality.md') {
    $missingPath = Join-Path $testRoot $relativePath
    Remove-Item -LiteralPath $missingPath -Force
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing $relativePath."
    Copy-Item -LiteralPath (Join-Path $root $relativePath) -Destination $missingPath -Force
    Assert-Condition (Invoke-CopiedValidator) "Validation failed after restoring $relativePath."
  }

  # Scenario: the native frontend agent loses its design-Skill route.
  # Expected: reject it without requiring any particular instruction wording.
  $frontendAgentPath = Join-Path $testRoot 'agents/team-frontend-engineer.toml'
  $frontendAgentContent = Get-Content -LiteralPath $frontendAgentPath -Raw
  Set-Content -LiteralPath $frontendAgentPath -Value ($frontendAgentContent.Replace('frontend-design', 'frontend-engineering')) -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted missing native frontend design routing.'
  Copy-Item -LiteralPath (Join-Path $root 'agents/team-frontend-engineer.toml') -Destination $frontendAgentPath -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation failed after restoring native frontend routing.'

  # Scenario: remove a comment-contract route but keep its replacement link valid.
  # Expected: reject each missing route rather than rely on generic link checks.
  foreach ($skillName in 'team-core', 'team-dev', 'team-review', 'code-review', 'frontend-engineering', 'backend-engineering', 'database-engineering', 'testing-engineering') {
    $commentSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalSkill = Get-Content -LiteralPath $commentSkill -Raw
    Set-Content -LiteralPath $commentSkill -Value ($originalSkill.Replace('code-comments.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing comment-contract routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $commentSkill -Force
  }

  $invalidAgent = Join-Path $testRoot 'agents\team-architect.toml'
  # Scenario: remove the comment contract. Expected: reject, then pass after restoration.
  $commentReference = Join-Path $testRoot 'skills/team-core/references/code-comments.md'
  Remove-Item -LiteralPath $commentReference -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing code-comment contract.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/code-comments.md') -Destination $commentReference -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation did not recover after restoring comment routing and the contract.'

  # Scenario: adapter runtime or routing is missing. Expected: distributable validation rejects each omission.
  foreach ($relative in @('skills/team-core/scripts/openspec-adapter.ps1', 'skills/team-core/templates/openspec/config.yaml')) {
    $resourcePath = Join-Path $testRoot $relative
    Remove-Item -LiteralPath $resourcePath
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing $relative"
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $resourcePath
  }
  Assert-Condition (Invoke-CopiedValidator) 'Validation did not recover after restoring OpenSpec files.'
  # Scenario: add an unsupported TOML field. Expected: validation rejects it.
  Add-Content -LiteralPath $invalidAgent -Value 'unsupported = "value"' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted an unsupported TOML field.'
  Copy-Item -LiteralPath (Join-Path $root 'agents\team-architect.toml') -Destination $invalidAgent -Force

  $skillPath = Join-Path $testRoot 'skills\team-dev\SKILL.md'
  # Scenario: introduce a broken local link. Expected: reject the package.
  Add-Content -LiteralPath $skillPath -Value '[broken link](missing-local-reference.md)' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing local Markdown reference.'

  Copy-Item -LiteralPath (Join-Path $root 'skills\team-dev\SKILL.md') -Destination $skillPath -Force
  # Scenario: remove TDD guidance. Expected: the existing contract remains enforced.
  Remove-Item -LiteralPath (Join-Path $testRoot 'skills\team-core\references\tdd-protocol.md') -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing TDD protocol reference.'

  Write-Host 'Validation tests passed.'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedTestRoot)).TrimEnd([char]'\', [char]'/' )
  $normalizedTemporaryParent = $temporaryParent.TrimEnd([char]'\', [char]'/' )
  if ($resolvedParent -ne $normalizedTemporaryParent -or -not ([System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('codex-multi-agent-validate-test-'))) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedTestRoot)) "Test cleanup left an unexpected directory: $resolvedTestRoot"
  Write-Host 'Isolated validation directory removed.'
}
