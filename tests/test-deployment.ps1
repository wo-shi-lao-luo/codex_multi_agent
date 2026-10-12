# End-to-end deployment tests confined to unique fake homes, package copies and local Git repositories.
# No network, real installation, project data or global Git configuration is used.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$manager = Join-Path $repo 'scripts/deploy-user.ps1'
$tempParent = (Get-TestTemporaryParent)
$testRoot = Join-Path $tempParent ('codex-deploy-test-' + [guid]::NewGuid().ToString('N') + ' space 中文')
$fakeCodex = Join-Path $testRoot 'codex'
$fakeAgents = Join-Path $testRoot 'agents-home'
$arguments = @{ CodexHome = $fakeCodex; AgentsHome = $fakeAgents }
$management = Join-Path $fakeAgents 'codex-multi-agent'
function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
# Match the intended error to avoid passing a negative case on an unrelated exception.
function Assert-Fails([scriptblock]$Run, [string]$Pattern) {
  try { & $Run | Out-Null } catch { if ($_.Exception.Message -notmatch $Pattern) { throw "Expected $Pattern; got $_" }; return }
  throw "Expected failure: $Pattern"
}
# Fixture packages differ by files, complete components and version; old packages need no manager.
function Write-Package([string]$Path, [string]$Version) {
  New-Item -ItemType Directory -Force "$Path/agents", "$Path/skills/team-fixture" | Out-Null
  Set-Content "$Path/VERSION" $Version
  Set-Content "$Path/agents/team-fixture.toml" "name = `"team-fixture`""
  Set-Content "$Path/skills/team-fixture/SKILL.md" "---`nname: team-fixture`ndescription: Fixture workflow.`n---`n# Fixture $Version"
}
# Fingerprints include relative names and contents so unnoticed extra files cannot pass.
function Fingerprint([string]$Path) {
  if (-not (Test-Path $Path)) { return '' }
  return (@(Get-ChildItem $Path -Recurse -File -Force | ForEach-Object { [IO.Path]::GetRelativePath($Path,$_.FullName) + ':' + (Get-FileHash $_.FullName).Hash } | Sort-Object) -join "`n")
}
try {
  New-Item -ItemType Directory $testRoot | Out-Null
  $old = Join-Path $testRoot 'old'; $new = Join-Path $testRoot 'new'
  Write-Package $old '0.11.0'; Write-Package $new '1.0.0'
  Set-Content "$new/skills/team-fixture/new-only.md" 'new-only file'
  New-Item -ItemType Directory "$new/skills/team-new" | Out-Null
  Set-Content "$new/skills/team-new/SKILL.md" "---`nname: team-new`ndescription: New fixture.`n---"
  Set-Content "$new/agents/team-new.toml" 'name = "team-new"'
  # SIM-09: the prior prototype uses a generic workflow/actor; 1.0.0 renames and separates AI roles.
  # Expected: upgrade removes obsolete identities; downgrade restores only old owned assets.
  New-Item -ItemType Directory "$old/skills/team-simulate" | Out-Null
  Set-Content "$old/skills/team-simulate/SKILL.md" "---`nname: team-simulate`ndescription: Old synthetic simulation fixture.`n---"
  Set-Content "$old/agents/team-simulation-actor.toml" 'name = "team-simulation-actor"'
  foreach ($name in 'team-ai-simulation-actor-basic','team-ai-simulation-actor-advanced','team-ai-architect','team-ai-engineer') {
    Set-Content "$new/agents/$name.toml" "name = `"$name`""
  }
  foreach ($name in 'team-ai-simulate','ai-engineering') {
    New-Item -ItemType Directory "$new/skills/$name" | Out-Null
    Set-Content "$new/skills/$name/SKILL.md" "---`nname: $name`ndescription: Synthetic simulation fixture.`n---"
  }
  foreach ($package in $old,$new) {
    New-Item -ItemType Directory "$package/skills/team-core" | Out-Null
    Set-Content "$package/skills/team-core/SKILL.md" "---`nname: team-core`ndescription: Retained synthetic core.`n---"
  }
  New-Item -ItemType Directory "$new/skills/team-core/scripts" | Out-Null
  Set-Content "$new/skills/team-core/scripts/ai-simulation.ps1" '# Synthetic new-version helper'
  # CR-04: the readability release adds a role, an implicitly invokable Skill and core reference.
  # Expected: deploy includes these owned assets; downgrade and stable restore remove all of them.
  Set-Content "$new/agents/team-code-maintainer.toml" 'name = "team-code-maintainer"'
  New-Item -ItemType Directory `
    "$new/skills/team-code-maintain/agents", "$new/skills/team-core/references" | Out-Null
  Set-Content "$new/skills/team-code-maintain/SKILL.md" "---`nname: team-code-maintain`ndescription: Readability fixture.`n---"
  Set-Content "$new/skills/team-code-maintain/agents/openai.yaml" "policy:`n  allow_implicit_invocation: true"
  Set-Content "$new/skills/team-core/references/code-readability.md" '# Synthetic readability contract'
  $readabilityPaths = @(
    "$fakeCodex/agents/team-code-maintainer.toml",
    "$fakeAgents/skills/team-code-maintain",
    "$fakeAgents/skills/team-core/references/code-readability.md"
  )
  # Scenario: preview on empty homes. Expected: no installation or manager files are written.
  & $manager -Action Deploy -SourceRoot $old @arguments -WhatIf | Out-Null
  Assert-True (-not (Test-Path $fakeCodex) -and -not (Test-Path $fakeAgents)) 'Preview changed homes.'
  # Scenario: initial install. Expected: v2 receipt covers exact payload and independent manager exists.
  & $manager -Action Deploy -SourceRoot $old @arguments | Out-Null
  & $manager -Action Verify @arguments | Out-Null
  $receiptPath = "$management/install-receipt.json"
  $receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
  Assert-True ($receipt.schemaVersion -eq 2 -and $receipt.kitVersion -eq '0.11.0') 'Wrong receipt.'
  Assert-True (-not(Test-Path -LiteralPath "$management/stable.json")) 'Initial major-line lifecycle test implicitly marked stable.'
  Assert-True (Test-Path "$management/rollback.ps1") 'Missing persistent recovery entrypoint.'
  # Scenario: an explicitly selected source/home is an arbitrary link.
  # Expected: refuse even a preview, retaining the same managed installation.
  $selectedLink = Join-Path $testRoot 'selected-root-link'
  try {
    New-TestDirectoryLink -Path $selectedLink -Target $old
    Assert-Fails { & $manager -Action Deploy -SourceRoot $selectedLink @arguments -WhatIf } 'PATH'
    Remove-TestLink $selectedLink
    New-TestDirectoryLink -Path $selectedLink -Target $fakeCodex
    Assert-Fails { & $manager -Action Deploy -SourceRoot $old -CodexHome $selectedLink -AgentsHome $fakeAgents -WhatIf } 'PATH'
  } finally { Remove-TestLink $selectedLink }
  if ($IsMacOS) {
    # Scenario: macOS's verified /var or /tmp spelling names these same physical fake homes.
    # Expected: source preview and receipt verification work without a second installation.
    $aliasRoot = $null
    foreach ($alias in @('/var','/tmp')) {
      $physical = '/private' + $alias
      if ($testRoot.StartsWith($physical + '/', [StringComparison]::Ordinal)) { $aliasRoot = $alias + $testRoot.Substring($physical.Length) }
    }
    if ($aliasRoot) {
      & $manager -Action Deploy -SourceRoot "$aliasRoot/old" -CodexHome "$aliasRoot/codex" -AgentsHome "$aliasRoot/agents-home" -WhatIf | Out-Null
      & $manager -Action Verify -CodexHome "$aliasRoot/codex" -AgentsHome "$aliasRoot/agents-home" | Out-Null
      Assert-True ($receipt.codexHome -ceq $fakeCodex -and $receipt.agentsHome -ceq $fakeAgents) 'Receipt did not retain canonical fake-home paths.'
    } else { Write-Host 'NOT APPLICABLE: macOS temp root has no /var or /tmp spelling; deployment alias case was not exercised.' }
  }
  # Scenario: user explicitly pins a tested install. Expected: later upgrades do not move stable.
  $stable = & $manager -Action MarkStable @arguments | ConvertFrom-Json
  $stableBytes = Get-Content "$management/stable.json" -Raw
  # Scenario: personal files coexist. Expected: exact Kit deployment never changes them.
  Set-Content "$fakeCodex/config.toml" '# personal settings'
  New-Item -ItemType Directory "$fakeAgents/skills/personal" | Out-Null
  Set-Content "$fakeAgents/skills/personal/SKILL.md" 'personal skill'
  & $manager -Action Deploy -SourceRoot $new @arguments | Out-Null
  # CR-04 happy: deployed readability payload. Expected: role, reference and nested metadata exist.
  foreach ($path in $readabilityPaths) {
    Assert-True (Test-Path -LiteralPath $path) "CR-04 missing deployed asset: $path"
  }
  Assert-True (Test-Path -LiteralPath "$fakeAgents/skills/team-code-maintain/agents/openai.yaml") `
    'CR-04 missing nested Skill metadata.'
  Assert-True ((Get-Content "$management/stable.json" -Raw) -eq $stableBytes) 'Upgrade moved stable.'
  Assert-True (-not(Test-Path -LiteralPath "$fakeAgents/skills/team-simulate") -and -not(Test-Path -LiteralPath "$fakeCodex/agents/team-simulation-actor.toml")) 'SIM-09 upgrade retained old workflow/actor.'
  foreach($path in @("$fakeAgents/skills/team-ai-simulate/SKILL.md","$fakeCodex/agents/team-ai-simulation-actor-basic.toml","$fakeCodex/agents/team-ai-simulation-actor-advanced.toml","$fakeCodex/agents/team-ai-architect.toml")){
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "SIM-09 upgrade omitted $path"
  }
  # Scenario: new -> old source. Expected: new agent, whole Skill and file inside retained Skill disappear.
  & $manager -Action Deploy -SourceRoot $old @arguments | Out-Null
  # CR-04 edge: downgrade to the earlier package. Expected: no newly owned readability residue.
  foreach ($path in $readabilityPaths) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "CR-04 downgrade residue: $path"
  }
  foreach ($path in @("$fakeCodex/agents/team-new.toml","$fakeAgents/skills/team-new","$fakeAgents/skills/team-fixture/new-only.md")) { Assert-True (-not (Test-Path $path)) "Residual content: $path" }
  foreach ($path in @("$fakeCodex/agents/team-ai-simulation-actor-basic.toml","$fakeCodex/agents/team-ai-simulation-actor-advanced.toml","$fakeCodex/agents/team-ai-architect.toml","$fakeCodex/agents/team-ai-engineer.toml","$fakeAgents/skills/team-ai-simulate","$fakeAgents/skills/ai-engineering","$fakeAgents/skills/team-core/scripts/ai-simulation.ps1")) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "SIM-07 downgrade left residue: $path"
  }
  Assert-True (Test-Path -LiteralPath "$fakeAgents/skills/team-simulate/SKILL.md") 'SIM-09 downgrade did not restore old Skill.'
  Assert-True (Test-Path -LiteralPath "$fakeCodex/agents/team-simulation-actor.toml") 'SIM-09 downgrade did not restore old actor.'
  Assert-True ((Get-Content "$management/stable.json" -Raw) -eq $stableBytes -and (Test-Path -LiteralPath "$management/backups/$($stable.snapshotId)")) 'SIM-09 downgrade changed/deleted pinned stable snapshot.'
  Assert-True ((Get-Content "$fakeCodex/config.toml" -Raw).Trim() -eq '# personal settings') 'Global config changed.'
  Assert-True ((Get-Content "$fakeAgents/skills/personal/SKILL.md" -Raw).Trim() -eq 'personal skill') 'Personal Skill changed.'
  # Scenario: standalone rollback entry survives source checkout removal. Expected: stable restores offline.
  & $manager -Action Deploy -SourceRoot $new @arguments | Out-Null
  & "$management/rollback.ps1" -Action Restore @arguments | Out-Null
  # CR-04 recovery: restore pinned old package offline. Expected: new readability assets disappear.
  foreach ($path in $readabilityPaths) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "CR-04 stable restore residue: $path"
  }
  & $manager -Action Verify @arguments | Out-Null
  Assert-True (-not (Test-Path "$fakeAgents/skills/team-new")) 'Standalone restore left new Skill.'
  Assert-True (-not(Test-Path -LiteralPath "$fakeAgents/skills/team-ai-simulate") -and -not(Test-Path -LiteralPath "$fakeCodex/agents/team-ai-architect.toml")) 'SIM-09 standalone stable restore retained major-line identities.'
  Assert-True (Test-Path -LiteralPath "$fakeAgents/skills/team-simulate/SKILL.md") 'SIM-09 stable restore omitted prior Skill.'
  # Scenario: local customization. Expected: refuse by default; explicit Force preserves original in backup.
  Set-Content "$fakeAgents/skills/team-fixture/SKILL.md" 'user modification'
  Assert-Fails { & $manager -Action Deploy -SourceRoot $new @arguments } 'CONFLICT'
  & $manager -Action Deploy -SourceRoot $new @arguments -Force | Out-Null
  $found = @(Get-ChildItem "$management/backups" -Recurse -Filter SKILL.md | Where-Object { (Get-Content $_.FullName -Raw).Trim() -eq 'user modification' })
  Assert-True ($found.Count -gt 0) 'Force discarded customization.'
  # Scenario: operation failure after first activation. Expected: all files and receipt roll back, not only last unit.
  $beforeFiles = Fingerprint "$fakeAgents/skills"
  $beforeAgents = Fingerprint "$fakeCodex/agents"
  $beforeReceipt = Get-Content $receiptPath -Raw
  $fault = Join-Path $testRoot 'fault.ps1'
  $source = Get-Content $manager -Raw
  Set-Content $fault ($source.Replace("Write-Verbose 'Unit activated.'", "throw 'TEST: injected activation failure'"))
  Assert-Fails { & $fault -Action Deploy -SourceRoot $old @arguments } 'TEST: injected'
  Assert-True ((Fingerprint "$fakeAgents/skills") -eq $beforeFiles -and (Fingerprint "$fakeCodex/agents") -eq $beforeAgents) 'Rollback left mixed files.'
  Assert-True ((Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Rollback changed receipt.'
  Assert-True (-not (Test-Path "$management/pending.json")) 'Successful recovery left pending operation.'
  # Scenario: failure immediately before or after receipt replacement. Expected: exact prior receipt and payload return.
  foreach ($hook in @("Write-Verbose 'Before receipt commit.'", "Write-Verbose 'Receipt committed.'")) {
    Set-Content $fault ($source.Replace($hook, "throw 'TEST: receipt boundary failure'"))
    Assert-Fails { & $fault -Action Deploy -SourceRoot $old @arguments } 'TEST: receipt boundary'
    Assert-True ((Fingerprint "$fakeAgents/skills") -eq $beforeFiles -and (Fingerprint "$fakeCodex/agents") -eq $beforeAgents -and (Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Receipt boundary recovery failed.'
    Assert-True (-not (Test-Path "$management/pending.json")) 'Receipt failure left a pending operation.'
  }
  # Scenario: another process holds the deployment lock. Expected: no active payload or receipt changes.
  $heldLock = [IO.File]::Open("$management/deployment.lock",'Open','ReadWrite','None')
  try {
    $contender = Invoke-TestPowerShell -Arguments @('-File',$manager,'-Action','Deploy','-SourceRoot',$old,'-CodexHome',$fakeCodex,'-AgentsHome',$fakeAgents)
    Assert-True ($contender.ExitCode -ne 0 -and ($contender.Output + $contender.Errors) -match 'LOCK:') 'Separate deployment process did not refuse the held lock.'
  } finally { $heldLock.Dispose() }
  Assert-True ((Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Lock conflict changed receipt.'
  # Scenario: hard process exit after activation. Expected: pending journal blocks new work; Recover restores all.
  Set-Content $fault ($source.Replace("Write-Verbose 'Unit activated.'", '[Environment]::Exit(91)'))
  & (Get-TestPowerShell) -NoProfile -File $fault -Action Deploy -SourceRoot $old -CodexHome $fakeCodex -AgentsHome $fakeAgents | Out-Null
  Assert-True ($LASTEXITCODE -eq 91) 'Crash fixture did not exit at intended point.'
  Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments } 'PENDING'
  # Scenario: an external edit appears after the crash. Expected: recovery refuses to erase it; journal survives.
  Set-Content "$fakeAgents/skills/team-fixture/external.md" 'preserve this user edit'
  Assert-Fails { & $manager -Action Recover @arguments } 'RECOVERY_CONFLICT'
  Assert-True ((Test-Path "$management/pending.json") -and (Test-Path "$fakeAgents/skills/team-fixture/external.md")) 'Recovery discarded external changes.'
  Remove-Item -LiteralPath "$fakeAgents/skills/team-fixture/external.md"
  & $manager -Action Recover @arguments | Out-Null
  Assert-True ((Fingerprint "$fakeAgents/skills") -eq $beforeFiles -and (Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Crash recovery failed.'
  Assert-True (@(Get-ChildItem "$management/staging" -Force).Count -eq 0) 'Crash recovery left staging data.'
  # Scenario: stable payload is corrupted. Expected: reject before altering the installed files.
  $snapshotFile = "$management/backups/$($stable.snapshotId)/payload/skills/team-fixture/SKILL.md"
  $snapshotBytes = [IO.File]::ReadAllBytes($snapshotFile)
  Set-Content $snapshotFile 'corrupt snapshot'
  Assert-Fails { & $manager -Action Restore @arguments } 'SNAPSHOT'
  [IO.File]::WriteAllBytes($snapshotFile,$snapshotBytes)
  Assert-True ((Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Invalid snapshot changed installation.'
  # Scenario: tampered receipt tries to claim global config. Expected: reject outside managed namespaces even with Force.
  $receipt = $beforeReceipt | ConvertFrom-Json
  $receipt.files[0].path = "$fakeCodex/config.toml"
  $receipt | ConvertTo-Json -Depth 20 | Set-Content $receiptPath
  Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments -Force } 'RECEIPT|PATH'
  [IO.File]::WriteAllText($receiptPath,$beforeReceipt)
  # Scenario: case-sensitive host receives a receipt claiming a case-distinct home.
  # Expected: reject ownership before changing payload, even when remaining file entries match.
  if (Test-CaseSensitiveFixture $testRoot) {
    $receipt = $beforeReceipt | ConvertFrom-Json
    $receipt.codexHome = Join-Path $testRoot 'CODEX'
    $receipt | ConvertTo-Json -Depth 20 | Set-Content $receiptPath
    Assert-Fails { & $manager -Action Verify @arguments } 'RECEIPT|PATH'
    [IO.File]::WriteAllText($receiptPath,$beforeReceipt)
    Assert-True ((Fingerprint "$fakeAgents/skills") -eq $beforeFiles) 'Case-distinct receipt changed payload.'
    # Scenario: source files differ only in case. Expected: portable package refuses them before writes.
    Set-Content "$old/skills/team-fixture/Guide.md" 'uppercase fixture'
    Set-Content "$old/skills/team-fixture/guide.md" 'lowercase fixture'
    try {
      Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments } 'PACKAGE|PORTABLE|PATH'
      Assert-True ((Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Case-colliding source changed receipt.'
    } finally {
      Remove-Item -LiteralPath "$old/skills/team-fixture/Guide.md","$old/skills/team-fixture/guide.md" -Force
    }
  } else { Write-Host 'NOT APPLICABLE: Case-distinct package/receipt scenarios require a case-sensitive fixture volume.' }
  # Scenario: source contains an existing or dangling directory link. Expected: reject both without activation.
  $sourceLink = "$old/skills/team-fixture/linked"
  $linkTarget = "$testRoot/link-target"
  New-Item -ItemType Directory $linkTarget | Out-Null
  Set-Content "$linkTarget/preserve.md" 'preserve target bytes'
  try {
    New-TestDirectoryLink -Path $sourceLink -Target $linkTarget
    Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments } 'PATH|PACKAGE'
    Assert-True ((Get-Content "$linkTarget/preserve.md" -Raw).Trim() -eq 'preserve target bytes') 'Source-link target changed.'
    Remove-Item -LiteralPath $linkTarget -Recurse -Force
    Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments } 'PATH|PACKAGE'
    Assert-True ((Get-Content $receiptPath -Raw) -eq $beforeReceipt) 'Rejected source link changed receipt.'
  } finally { Remove-TestLink $sourceLink }
  # Scenario: newer runtime data contract. Expected: incompatible downgrade stops before payload changes.
  Set-Content "$old/deployment.json" '{"runtimeDataSchema":0}'
  Assert-Fails { & $manager -Action Deploy -SourceRoot $old @arguments } 'DATA_SCHEMA'
  Remove-Item -LiteralPath "$old/deployment.json"
  # Scenario: Git is not installed. Expected: directory deployment still works, GitRef reports its dependency.
  # This empty, owned PATH fixture changes only this process and is restored before local-Git tests.
  $savedPath = $env:PATH
  $emptyBin = Join-Path $testRoot 'empty-bin'
  New-Item -ItemType Directory -Path $emptyBin | Out-Null
  try {
    $env:PATH = $emptyBin
    & $manager -Action Deploy -SourceRoot $new @arguments | Out-Null
    $withoutGit = Get-Content $receiptPath -Raw | ConvertFrom-Json
    Assert-True ($null -eq $withoutGit.source.commit -and $withoutGit.source.dirty -eq $true) 'Directory install without Git invented provenance.'
    Assert-Fails { & $manager -Action Deploy -SourceRoot $old -GitRef HEAD @arguments } 'GIT|DEPENDENCY'
  } finally { $env:PATH = $savedPath }
  # Scenario: immutable local Git target while dirty worktree exists. Expected: use commit, preserve working files.
  # An empty template/hooks directory and disabled signing keep fixture commits local and noninteractive.
  & git init --quiet "--template=$emptyBin" $old
  & git -C $old add .
  & git -C $old -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c "core.hooksPath=$emptyBin" commit --quiet -m fixture
  $commit = (& git -C $old rev-parse HEAD).Trim()
  Set-Content "$old/VERSION" '9.9.9'
  & $manager -Action Deploy -SourceRoot $old -GitRef $commit @arguments | Out-Null
  $gitReceipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
  Assert-True ($gitReceipt.kitVersion -eq '0.11.0' -and $gitReceipt.source.commit -eq $commit) 'Git target not honored.'
  Assert-True ((Get-Content "$old/VERSION" -Raw).Trim() -eq '9.9.9') 'Git target changed worktree.'
  # Scenario: old schema-v1 receipt. Expected: adopt known paths, upgrade ownership metadata and remove retired units.
  $legacy = @{ schemaVersion=1; kitVersion='0.11.0'; codexHome=$fakeCodex; agentsHome=$fakeAgents; files=$gitReceipt.files }
  $legacy | ConvertTo-Json -Depth 20 | Set-Content $receiptPath
  & $manager -Action Deploy -SourceRoot $new @arguments | Out-Null
  & $manager -Action Restore -SnapshotId $stable.snapshotId @arguments | Out-Null
  & $manager -Action Verify @arguments | Out-Null
  # Scenario: prune preview/execution. Expected: keep stable snapshot; no active content changed.
  $before = Fingerprint "$fakeAgents/skills"
  & $manager -Action Prune -KeepSnapshots 1 @arguments -WhatIf | Out-Null
  & $manager -Action Prune -KeepSnapshots 1 @arguments -ConfirmPrune | Out-Null
  Assert-True (Test-Path "$management/backups/$($stable.snapshotId)") 'Prune removed stable.'
  Assert-True ((Fingerprint "$fakeAgents/skills") -eq $before) 'Prune changed active files.'
  Write-Host 'Deployment tests passed: isolated upgrade/downgrade, recovery, Git target, ownership and cleanup.'
} finally {
  # Delete only the exact generated child of the system temp directory; never a home or workspace root.
  if (Test-Path $testRoot) {
    $resolved = (Resolve-Path $testRoot).Path
    if ((Split-Path $resolved -Parent) -ne $tempParent -or (Split-Path $resolved -Leaf) -notlike 'codex-deploy-test-*') { throw 'Unsafe cleanup path.' }
    Remove-Item -LiteralPath $resolved -Force -Recurse
    if (Test-Path $resolved) { throw 'Deployment test cleanup failed.' }
    Write-Host 'Isolated deployment directory removed.'
  }
}
