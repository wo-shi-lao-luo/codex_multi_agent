# Exercise the read-only Agent source-map CLI in isolated fake projects.
# Source checks prove payload availability only; native Agent judgment is separate.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$SourceOnly, [switch]$ReviewOnly, [switch]$SubmoduleOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$root = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $root 'skills/team-core/scripts/agent-docs.ps1'

# AD-01: the requested Inspect boundary must exist before a consumer can run it.
# Expected: an absent payload fails explicitly before fixtures or production work.
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
  throw 'AD-01 missing Inspect helper: skills/team-core/scripts/agent-docs.ps1'
}
if ($SourceOnly) {
  Write-Output 'AD-01 helper exists; runtime and semantic behavior not checked.'
  return
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$fixture = Join-Path (Get-TestTemporaryParent) (
  'codex-agent-docs-test-' + [guid]::NewGuid().ToString('N')
)
$script:caseNumber = 0
$script:checks = 0

function Assert-True([bool]$Value, [string]$Message) {
  # Surface an observable contract failure with its scenario identifier.
  if (-not $Value) { throw $Message }
}

function Write-Fixture([string]$Project, [string]$Relative, [string]$Text) {
  # Write only owned fixture data, creating parents within the isolated project.
  $path = Join-Path $Project $Relative
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
  [IO.File]::WriteAllText($path, $Text, $utf8)
}

function Invoke-Git([string]$Project, [string[]]$Arguments) {
  # Exercise local Git only, without hooks, global configuration or remote access.
  $result = Invoke-TestProcess -FilePath (Get-Command git).Source -ArgumentList (
    @('-C', $Project, '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false') +
    $Arguments
  ) -Environment @{ GIT_CONFIG_NOSYSTEM = '1'; GIT_CONFIG_GLOBAL = '' }
  Assert-True ($result.Exit -eq 0) "Fixture Git failed: $($result.Error)"
  return $result.Out.Trim()
}

function Save-Manifest([string]$Project, [hashtable]$Manifest) {
  # Serialize the portable mapping as fixture input; utility must never rewrite it.
  Write-Fixture $Project 'docs/agent/sources.json' ($Manifest | ConvertTo-Json -Depth 12)
}

function New-Project([switch]$NoGit) {
  # Establish known byte baselines and optional real Git history before each scenario.
  $script:caseNumber++
  $project = Join-Path $fixture ('project ' + $script:caseNumber)
  [IO.Directory]::CreateDirectory($project) | Out-Null
  Write-Fixture $project 'docs/agent/development/common.md' '# Derived development guide'
  Write-Fixture $project 'docs/requirements.md' '# Approved requirements'
  Write-Fixture $project 'src/module.ps1' '# Actual code dependency'
  Write-Fixture $project 'config/settings.json' '{"enabled":true}'
  Write-Fixture $project 'tests/module.ps1' '# Actual test dependency'
  $baseline = $null
  if (-not $NoGit) {
    $null = Invoke-Git $project @('init', '-q')
    $null = Invoke-Git $project @('config', 'user.name', 'Fixture')
    $null = Invoke-Git $project @('config', 'user.email', 'fixture@example.invalid')
    $null = Invoke-Git $project @('add', '.')
    $null = Invoke-Git $project @('commit', '-qm', 'fixture baseline')
    $baseline = Invoke-Git $project @('rev-parse', 'HEAD')
  }
  $sources = @('docs/requirements.md', 'src/module.ps1', 'config/settings.json',
    'tests/module.ps1') | ForEach-Object {
    @{ path = $_; exists = $true; sha256 = (
      Get-FileHash -LiteralPath (Join-Path $project $_)
    ).Hash.ToLowerInvariant(); anchor = $null }
  }
  $sources += @{ path = 'docs/future.md'; exists = $false; sha256 = $null; anchor = $null }
  $manifest = @{
    schemaVersion = 1; documentsRoot = 'docs/agent'; gitBaseline = $baseline
    documents = @(@{
      path = 'docs/agent/development/common.md'
      documentSha256 = (Get-FileHash -LiteralPath (
        Join-Path $project 'docs/agent/development/common.md'
      )).Hash.ToLowerInvariant()
      sources = @($sources)
    })
  }
  Save-Manifest $project $manifest
  return @{ Project = $project; Manifest = $manifest; Baseline = $baseline }
}

function Invoke-Inspect([string]$Project, [string]$ManifestPath = 'docs/agent/sources.json') {
  # Exercise the genuine consumer CLI and prove complete project nonmutation per call.
  # Encoded arguments are literal data, not shell interpolation or command evaluation.
  $before = Get-TestFingerprint $Project
  $parameters = @{
    Action = 'Inspect'; ProjectRoot = $Project; ManifestPath = $ManifestPath
  }
  $encodedParameters = [Convert]::ToBase64String($utf8.GetBytes(
    ($parameters | ConvertTo-Json -Compress)
  ))
  $encodedHelper = [Convert]::ToBase64String($utf8.GetBytes($helper))
  $command = @"
`$parameters = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedParameters')) | ConvertFrom-Json -AsHashtable
`$helper = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedHelper'))
& `$helper @parameters
exit `$LASTEXITCODE
"@
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $child = Invoke-TestPowerShell @('-EncodedCommand', $encodedCommand) -TimeoutSeconds 70
  Assert-True ($watch.Elapsed.TotalSeconds -lt 70) 'AD-05 consumer exceeded outer deadline.'
  Assert-True ($before -ceq (Get-TestFingerprint $Project)) 'Inspect mutated project/Git bytes.'
  Assert-True ([Text.Encoding]::UTF8.GetByteCount($child.Output) -le 5MB) `
    'AD-05 returned unbounded output.'
  Assert-True ([string]::IsNullOrEmpty($child.Errors)) "Inspect leaked stderr: $($child.Errors)"
  try { $payload = $child.Output | ConvertFrom-Json }
  catch { throw "Inspect returned non-JSON (exit $($child.ExitCode)): $($child.Output)" }
  Assert-True ($payload.schemaVersion -eq 1) 'AD contract schema changed.'
  Assert-True ($payload.status -in @('fresh', 'changed', 'unknown', 'unadopted')) `
    'AD contract returned unsupported status.'
  $script:checks++
  return @{ Code = $child.ExitCode; Payload = $payload; Raw = $child.Output }
}

function Assert-Unknown($Result, [string]$Scenario) {
  # Incomplete evidence must be actionable and must never masquerade as freshness.
  Assert-True ($Result.Code -eq 2 -and $Result.Payload.status -eq 'unknown') `
    "$Scenario did not return unknown/2: $($Result.Raw)"
}

function Test-SubmoduleBoundary {
  # AD-SUBMODULE-01: a newly staged gitlink is outside the helper's nonrecursive scope.
  # Expected: unknown/2 with a fixed gap code, rather than false fresh from ignored diffs.
  $case = New-Project
  $gitlink = 'modules/submodule'
  $null = Invoke-Git $case.Project @(
    'update-index', '--add', '--cacheinfo', "160000,$($case.Baseline),$gitlink"
  )
  $staged = Invoke-Inspect $case.Project
  Assert-Unknown $staged 'AD-SUBMODULE-01 staged gitlink'
  Assert-True ($staged.Payload.errors -contains 'git-submodule') `
    'AD-SUBMODULE-01 missing explicit submodule gap.'
  Assert-True ($staged.Payload.documents[0].status -eq 'fresh') `
    'AD-SUBMODULE-01 discarded useful mapped snapshots.'

  # AD-SUBMODULE-02: removing an indexed gitlink cannot conceal the HEAD gitlink.
  # Expected: unknown/2 while HEAD still has the uninspected dependency.
  $null = Invoke-Git $case.Project @('commit', '-qm', 'fixture gitlink')
  $gitlinkCommit = Invoke-Git $case.Project @('rev-parse', 'HEAD')
  $null = Invoke-Git $case.Project @('update-index', '--force-remove', $gitlink)
  $removedFromIndex = Invoke-Inspect $case.Project
  Assert-Unknown $removedFromIndex 'AD-SUBMODULE-02 HEAD-only gitlink'
  Assert-True ($removedFromIndex.Payload.errors -contains 'git-submodule') `
    'AD-SUBMODULE-02 HEAD gitlink gap missing.'

  # AD-SUBMODULE-03: a historical baseline gitlink remains relevant after committed removal.
  # Expected: unknown/2 although neither current index nor HEAD contains a gitlink.
  $null = Invoke-Git $case.Project @('commit', '-qm', 'fixture gitlink removal')
  $case.Manifest.gitBaseline = $gitlinkCommit
  Save-Manifest $case.Project $case.Manifest
  $baselineOnly = Invoke-Inspect $case.Project
  Assert-Unknown $baselineOnly 'AD-SUBMODULE-03 baseline-only gitlink'
  Assert-True ($baselineOnly.Payload.errors -contains 'git-submodule') `
    'AD-SUBMODULE-03 baseline gitlink gap missing.'

  # AD-SUBMODULE-04: an initialized local nested repository has dirty tracked bytes.
  # Expected: unknown/2 without entering/mutating nested Git or claiming its contents fresh.
  # Build it directly with local init/commits: no submodule add, clone or network transport.
  $case = New-Project
  $nested = Join-Path $case.Project $gitlink
  [IO.Directory]::CreateDirectory($nested) | Out-Null
  Write-Fixture $nested 'module.txt' 'tracked nested source'
  $null = Invoke-Git $nested @('init', '-q')
  $null = Invoke-Git $nested @('config', 'user.name', 'Fixture')
  $null = Invoke-Git $nested @('config', 'user.email', 'fixture@example.invalid')
  $null = Invoke-Git $nested @('add', 'module.txt')
  $null = Invoke-Git $nested @('commit', '-qm', 'nested fixture baseline')
  $nestedHead = Invoke-Git $nested @('rev-parse', 'HEAD')
  $null = Invoke-Git $case.Project @(
    'update-index', '--add', '--cacheinfo', "160000,$nestedHead,$gitlink"
  )
  $null = Invoke-Git $case.Project @('commit', '-qm', 'initialized nested fixture')
  $case.Manifest.gitBaseline = Invoke-Git $case.Project @('rev-parse', 'HEAD')
  Save-Manifest $case.Project $case.Manifest
  Write-Fixture $nested 'module.txt' 'dirty tracked nested source'
  Assert-True ((Invoke-Git $nested @('status', '--porcelain')).Contains('module.txt')) `
    'AD-SUBMODULE-04 fixture is not dirty.'
  $dirty = Invoke-Inspect $case.Project
  Assert-Unknown $dirty 'AD-SUBMODULE-04 dirty initialized submodule'
  Assert-True ($dirty.Payload.errors -contains 'git-submodule') `
    'AD-SUBMODULE-04 dirty nested dependency gap missing.'
}

try {
  [IO.Directory]::CreateDirectory($fixture) | Out-Null
  Test-SubmoduleBoundary
  if ($SubmoduleOnly) {
    Write-Output "AD submodule regression checks passed: $script:checks Inspect invocations."
    return
  }

  # AD-REVIEW-01 portable evidence carries exact reviewed source and target identities.
  # Expected: manifest/current/expected fingerprints match fixture bytes, including absence.
  $case = New-Project
  $identities = Invoke-Inspect $case.Project
  Assert-True ($identities.Code -eq 0) 'AD-REVIEW-01 baseline not mechanically fresh.'
  Assert-True ($identities.Payload.manifestSha256 -ceq (
    Get-FileHash -LiteralPath (Join-Path $case.Project 'docs/agent/sources.json')
  ).Hash.ToLowerInvariant()) 'AD-REVIEW-01 manifest identity missing or incorrect.'
  $target = $identities.Payload.documents[0]
  Assert-True ($target.exists -and
    $target.sha256 -ceq $case.Manifest.documents[0].documentSha256 -and
    $target.expectedSha256 -ceq $target.sha256) 'AD-REVIEW-01 target identities lost.'
  foreach ($source in $target.sources) {
    $expected = @($case.Manifest.documents[0].sources | Where-Object path -eq $source.path)[0]
    Assert-True ($source.expectedSha256 -ceq $expected.sha256) `
      'AD-REVIEW-01 source expected identity lost.'
  }

  # AD-REVIEW-02 formal governance is portable authority; only runtime records are excluded.
  # Expected: user-authored rules map successfully, runtime reviews/maps remain unknown/2.
  Write-Fixture $case.Project 'docs/governance/rules.md' '# Formal approved policy'
  $case.Manifest.documents[0].sources += @{
    path = 'docs/governance/rules.md'; exists = $true; anchor = $null
    sha256 = (Get-FileHash -LiteralPath (
      Join-Path $case.Project 'docs/governance/rules.md'
    )).Hash.ToLowerInvariant()
  }
  Save-Manifest $case.Project $case.Manifest
  $formal = Invoke-Inspect $case.Project
  Assert-True ($formal.Code -eq 0 -and $formal.Payload.documents[0].status -eq 'fresh') `
    "AD-REVIEW-02 formal governance authority rejected: $($formal.Raw)"
  foreach ($runtimePath in @('docs/governance/documentation.json',
      'docs/governance/doc-index.md', 'docs/governance/reviews/active/example.json')) {
    $case.Manifest.documents[0].sources[-1].path = $runtimePath
    Save-Manifest $case.Project $case.Manifest
    Assert-Unknown (Invoke-Inspect $case.Project) 'AD-REVIEW-02 runtime governance source'
  }

  # AD-REVIEW-03 linked Git metadata cannot widen the read authority before preflight.
  # Expected: unknown/2 for linked .git, with the actual metadata unchanged.
  $case = New-Project
  $metadata = Join-Path $fixture 'linked git metadata'
  Move-Item -LiteralPath (Join-Path $case.Project '.git') -Destination $metadata
  $metadataBefore = Get-TestFingerprint $metadata
  $gitLink = Join-Path $case.Project '.git'
  try {
    New-TestDirectoryLink $gitLink $metadata
    Assert-Unknown (Invoke-Inspect $case.Project) 'AD-REVIEW-03 linked Git metadata'
    Assert-True ($metadataBefore -ceq (Get-TestFingerprint $metadata)) `
      'AD-REVIEW-03 linked Git metadata mutated.'
  } finally { Remove-TestLink $gitLink }

  # AD-REVIEW-04 normal Git worktree .git indirection is a supported local repository.
  # Expected: fresh/0 from same tracked baseline and no shared repository metadata writes.
  $case = New-Project
  $worktree = Join-Path $fixture 'plain Git worktree'
  $null = Invoke-Git $case.Project @('worktree', 'add', '-q', '-b', 'linked-worktree', $worktree)
  Save-Manifest $worktree $case.Manifest
  $sharedBefore = Get-TestFingerprint (Join-Path $case.Project '.git')
  $worktreeResult = Invoke-Inspect $worktree
  Assert-True ($worktreeResult.Code -eq 0) `
    "AD-REVIEW-04 ordinary worktree rejected: $($worktreeResult.Raw)"
  Assert-True ($sharedBefore -ceq (Get-TestFingerprint (Join-Path $case.Project '.git'))) `
    'AD-REVIEW-04 shared worktree metadata changed.'

  # AD-REVIEW-05 duplicate JSON and unknown fields must not be silently normalized away.
  # Expected: unknown/2, preserving manifest bytes and refusing ambiguous source authority.
  $case = New-Project
  $text = [IO.File]::ReadAllText((Join-Path $case.Project 'docs/agent/sources.json'))
  Write-Fixture $case.Project 'docs/agent/sources.json' (
    $text.Replace('"schemaVersion": 1', '"schemaVersion": 1, "schemaVersion": 1')
  )
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-REVIEW-05 duplicate JSON'
  $case.Manifest.unrecognizedApproval = $true
  Save-Manifest $case.Project $case.Manifest
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-REVIEW-05 unknown schema field'
  if ($ReviewOnly) {
    Write-Output "AD review regression checks passed: $script:checks Inspect invocations."
    return
  }

  # AD-02 unchanged baseline: actual mapped requirements/code/config/tests and absent source.
  # Expected: fresh/0, all mapped rows fresh, manifest exclusion explicitly disclosed.
  $case = New-Project
  $fresh = Invoke-Inspect $case.Project
  Assert-True ($fresh.Code -eq 0 -and $fresh.Payload.status -eq 'fresh') `
    "AD-02 baseline not fresh: $($fresh.Raw)"
  Assert-True ($fresh.Payload.documents[0].status -eq 'fresh') 'Mapped baseline not fresh.'
  Assert-True (@($fresh.Payload.documents[0].sources).Count -eq 5) 'Sources omitted.'
  Assert-True ($fresh.Raw -notmatch 'Approved requirements|Actual code dependency') `
    'Raw source content leaked.'
  Assert-True ($null -ne $fresh.Payload.coverage.scope) 'Scoped boundary missing.'

  # AD-02 independent mapped inputs: changes to any requirement/code/config/test matter.
  # Expected: named source changed/1, restoring exact bytes restores fresh/0.
  foreach ($relative in @('docs/requirements.md', 'src/module.ps1',
      'config/settings.json', 'tests/module.ps1')) {
    $original = [IO.File]::ReadAllText((Join-Path $case.Project $relative))
    Write-Fixture $case.Project $relative ($original + "`nChanged by human")
    $changed = Invoke-Inspect $case.Project
    $row = @($changed.Payload.documents[0].sources | Where-Object path -eq $relative)
    Assert-True ($changed.Code -eq 1 -and $row.Count -eq 1 -and
      $row[0].status -eq 'changed') "AD-02 missed mapped input: $relative"
    Write-Fixture $case.Project $relative $original
  }

  # AD-02 expected absence: creation must invalidate an explicit absent baseline.
  # Expected: source changed with expectedExists=false and exists=true.
  Write-Fixture $case.Project 'docs/future.md' '# Newly supplied authoritative source'
  $appeared = Invoke-Inspect $case.Project
  $row = @($appeared.Payload.documents[0].sources | Where-Object path -eq 'docs/future.md')[0]
  Assert-True ($appeared.Code -eq 1 -and $row.status -eq 'changed' -and
    -not $row.expectedExists -and $row.exists) 'AD-02 absent source creation lost.'

  # AD-02 human document edits remain distinct from source edits and are report-only.
  # Expected: target documentChanged=true, changed/1, preserved edited bytes.
  Write-Fixture $case.Project 'docs/agent/development/common.md' '# Human clarification'
  $human = Invoke-Inspect $case.Project
  Assert-True ($human.Code -eq 1 -and $human.Payload.documents[0].documentChanged) `
    'AD-02 human target edit was silently reconciled.'

  # AD-03 rename is missing+added, never automatic semantic relocation/approval.
  # Expected: old mapped target missing, new target added; deleted source changed.
  Move-Item -LiteralPath (Join-Path $case.Project 'docs/agent/development/common.md') `
    -Destination (Join-Path $case.Project 'docs/agent/development/renamed.md')
  Move-Item -LiteralPath (Join-Path $case.Project 'docs/requirements.md') `
    -Destination (Join-Path $case.Project 'docs/renamed-requirements.md')
  $renamed = Invoke-Inspect $case.Project
  Assert-True ($renamed.Code -eq 1 -and $renamed.Payload.documents[0].status -eq 'missing') `
    'AD-03 missing mapped target lost.'
  Assert-True ($renamed.Payload.inventory.added -contains 'docs/agent/development/renamed.md') `
    'AD-03 new document inventory lost.'
  Assert-True ($renamed.Payload.inventory.missing -contains 'docs/agent/development/common.md') `
    'AD-03 old document identity lost.'
  $row = @($renamed.Payload.documents[0].sources | Where-Object path -eq 'docs/requirements.md')[0]
  Assert-True ($row.status -eq 'changed' -and -not $row.exists) 'Deleted source lost.'

  # AD-03 unmapped additions outside Agent docs need a coverage hint rather than freshness.
  # Expected: untracked path appears as Git and coverage evidence, changed/1.
  $case = New-Project
  Write-Fixture $case.Project 'docs/new-design.md' '# Unmapped new design'
  $unmapped = Invoke-Inspect $case.Project
  Assert-True ($unmapped.Code -eq 1 -and
    $unmapped.Payload.git.untracked -contains 'docs/new-design.md' -and
    $unmapped.Payload.coverage.unmapped -contains 'docs/new-design.md') `
    'AD-03 unmapped new source hidden.'

  # AD-04 Git has simultaneous committed/staged/unstaged/untracked changes.
  # Expected: each exact path survives independently, no diff/content leakage.
  $case = New-Project
  Write-Fixture $case.Project 'docs/requirements.md' 'committed change'
  $null = Invoke-Git $case.Project @('add', 'docs/requirements.md')
  $null = Invoke-Git $case.Project @('commit', '-qm', 'fixture source change')
  Write-Fixture $case.Project 'src/module.ps1' 'staged change'
  $null = Invoke-Git $case.Project @('add', 'src/module.ps1')
  Write-Fixture $case.Project 'config/settings.json' 'unstaged change'
  Write-Fixture $case.Project 'src/new.ps1' 'untracked change'
  $deltas = Invoke-Inspect $case.Project
  Assert-True ($deltas.Code -eq 1) 'AD-04 Git changes not surfaced.'
  foreach ($pair in @(@('committed', 'docs/requirements.md'),
      @('staged', 'src/module.ps1'), @('unstaged', 'config/settings.json'),
      @('untracked', 'src/new.ps1'))) {
    Assert-True ($deltas.Payload.git.($pair[0]) -contains $pair[1]) `
      "AD-04 omitted $($pair[0]) path $($pair[1])."
  }

  # AD-04 no Git, absent/null/unreachable baseline preserve snapshot observations.
  # Expected: unknown/2 even if hashes match; changed source remains observable.
  $case = New-Project -NoGit
  $noGit = Invoke-Inspect $case.Project
  Assert-Unknown $noGit 'AD-04 no Git'
  Assert-True ($noGit.Payload.documents[0].status -eq 'fresh') 'No-Git snapshot discarded.'
  Write-Fixture $case.Project 'src/module.ps1' 'changed without Git'
  $noGitChange = Invoke-Inspect $case.Project
  Assert-Unknown $noGitChange 'AD-04 no Git changed'
  Assert-True ($noGitChange.Payload.documents[0].status -eq 'changed') `
    'No-Git useful scoped evidence discarded.'
  foreach ($baseline in @($null, ('f' * 40))) {
    $case = New-Project
    $case.Manifest.gitBaseline = $baseline
    Save-Manifest $case.Project $case.Manifest
    Assert-Unknown (Invoke-Inspect $case.Project) 'AD-04 unavailable baseline'
  }

  # AD-04 branch switch/rebased history: baseline is not an ancestor of current HEAD.
  # Expected: explicit unknown/2 with scoped hashes retained, no automatic baseline advance.
  $case = New-Project
  $null = Invoke-Git $case.Project @('checkout', '-q', '--orphan', 'unrelated')
  $null = Invoke-Git $case.Project @('add', '.')
  $null = Invoke-Git $case.Project @('commit', '-qm', 'independent history')
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-04 nonancestor baseline'

  # AD-04 switched branch with a reachable ancestor is still valid evidence.
  # Expected: same baseline and byte state stays fresh, without branch-name assumptions.
  $case = New-Project
  $null = Invoke-Git $case.Project @('checkout', '-qb', 'feature')
  $switched = Invoke-Inspect $case.Project
  Assert-True ($switched.Code -eq 0) 'AD-04 valid ancestor branch switch rejected.'

  # AD-04 portable clone contains mapping and source history but no local governance.
  # Expected: existing portable baseline inspected from local clone without network.
  $null = Invoke-Git $case.Project @('add', 'docs/agent/sources.json')
  $null = Invoke-Git $case.Project @('commit', '-qm', 'portable mapping')
  $clone = Join-Path $fixture 'fresh local clone'
  $null = Invoke-Git $case.Project @('clone', '-q', '--no-local', $case.Project, $clone)
  $cloned = Invoke-Inspect $clone
  Assert-True ($cloned.Code -eq 0 -and $cloned.Payload.status -eq 'fresh') `
    "AD-04 fresh local clone failed: $($cloned.Raw)"

  # AD-04 promisor metadata must prevent object-reading Git operations/fetches.
  # Expected: partial/incomplete evidence is unknown/2 even with all current bytes present.
  $case = New-Project
  $null = Invoke-Git $case.Project @('config', 'remote.origin.promisor', 'true')
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-04 promisor repository'

  # AD-05 adoption is explicit: no map and no mapped documents cannot claim readiness.
  # Expected: unadopted/2, with no generated manifest or output files.
  $case = New-Project
  $missing = Invoke-Inspect $case.Project 'docs/agent/not-adopted.json'
  Assert-True ($missing.Code -eq 2 -and $missing.Payload.status -eq 'unadopted') `
    'AD-05 missing manifest silently adopted.'
  $case.Manifest.documents = @()
  Save-Manifest $case.Project $case.Manifest
  $empty = Invoke-Inspect $case.Project
  Assert-True ($empty.Code -eq 2 -and $empty.Payload.status -eq 'unadopted') `
    'AD-05 empty mapping claimed freshness.'
  $case = New-Project
  $case.Manifest.documents[0].sources = @()
  Save-Manifest $case.Project $case.Manifest
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-05 missing source coverage'

  # AD-05 unsafe source paths must fail closed, independent of file availability.
  # Expected: unknown/2, sanitized output, no contents from external/private inputs.
  $outside = Join-Path $fixture 'outside-secret.txt'
  $secret = 'DO_NOT_LEAK_FIXTURE_SECRET_5193'
  [IO.File]::WriteAllText($outside, $secret, $utf8)
  foreach ($relative in @('../outside-secret.txt', $outside, '.git/config',
      '_work/private.md', 'docs/governance/documentation.json',
      '.env', 'node_modules/package/index.js', 'docs/agent/sources.json',
      'docs/agent/development/common.md', 'src/*.ps1')) {
    $case = New-Project
    $case.Manifest.documents[0].sources[0].path = $relative
    Save-Manifest $case.Project $case.Manifest
    $unsafe = Invoke-Inspect $case.Project
    Assert-Unknown $unsafe 'AD-05 unsafe source'
    Assert-True (-not $unsafe.Raw.Contains($secret)) 'AD-05 external secret leaked.'
  }

  # AD-05 linked directory escape may never make outside bytes an allowed source.
  # Expected: unknown/2 and no link traversal/content leak; remove link before cleanup.
  $case = New-Project
  $link = Join-Path $case.Project 'linked'
  try {
    New-TestDirectoryLink $link $fixture
    $case.Manifest.documents[0].sources[0].path = 'linked/outside-secret.txt'
    Save-Manifest $case.Project $case.Manifest
    $linked = Invoke-Inspect $case.Project
    Assert-Unknown $linked 'AD-05 linked escape'
    Assert-True (-not $linked.Raw.Contains($secret)) 'AD-05 linked secret leaked.'
  } finally { Remove-TestLink $link }

  # AD-05 manifest validation rejects malformed hashes/schema/absence and portable aliases.
  # Expected: unknown/2 instead of fabricated clean evidence or partially accepted input.
  foreach ($variant in @('hash', 'schema', 'absence', 'duplicate', 'root')) {
    $case = New-Project
    switch ($variant) {
      hash { $case.Manifest.documents[0].documentSha256 = 'not-a-hash' }
      schema { $case.Manifest.schemaVersion = 99 }
      absence { $case.Manifest.documents[0].sources[0].exists = $false }
      duplicate {
        $copy = $case.Manifest.documents[0].Clone()
        $copy.path = 'docs/agent/development/COMMON.md'
        $case.Manifest.documents += $copy
      }
      root { $case.Manifest.documentsRoot = '../outside' }
    }
    Save-Manifest $case.Project $case.Manifest
    Assert-Unknown (Invoke-Inspect $case.Project) "AD-05 invalid $variant"
  }

  # AD-05 strict UTF-8 and bounded manifest/file sizes prevent unbounded analysis.
  # Expected: unknown/2 with limits/errors visible, no raw payload echoed.
  $case = New-Project
  [IO.File]::WriteAllBytes((Join-Path $case.Project 'docs/agent/sources.json'),
    [byte[]]@(0xFF, 0xFE, 0xFF))
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-05 invalid UTF-8'
  $case = New-Project
  Write-Fixture $case.Project 'docs/agent/sources.json' (' ' * (256KB + 1))
  Assert-Unknown (Invoke-Inspect $case.Project) 'AD-05 manifest size limit'
  $case = New-Project
  Write-Fixture $case.Project 'src/module.ps1' ('x' * (8MB + 1))
  $oversize = Invoke-Inspect $case.Project
  Assert-Unknown $oversize 'AD-05 source size limit'
  Assert-True ($oversize.Payload.limits.incomplete) 'AD-05 incomplete limit not visible.'

  # AD-05 inventory cap: many tiny unadopted documents must not yield partial freshness.
  # Expected: unknown/2 with explicit incomplete evidence, even if every mapped hash matches.
  $case = New-Project
  for ($index = 0; $index -lt 4097; $index++) {
    Write-Fixture $case.Project ("docs/agent/new-$index.md") '# New inventory document'
  }
  $inventoryLimit = Invoke-Inspect $case.Project
  Assert-Unknown $inventoryLimit 'AD-05 inventory count limit'
  Assert-True ($inventoryLimit.Payload.limits.incomplete) 'Inventory truncation concealed.'

  # AD-05 total hash budget: individually allowed sources can exceed the aggregate cap.
  # Expected: unknown/2 rather than continuing unbounded reads or accepting a partial digest.
  $case = New-Project
  for ($index = 0; $index -lt 9; $index++) {
    $relative = "src/large-$index.txt"
    Write-Fixture $case.Project $relative ('x' * 8MB)
    $case.Manifest.documents[0].sources += @{
      path = $relative; exists = $true; anchor = $null
      sha256 = (Get-FileHash -LiteralPath (Join-Path $case.Project $relative)).Hash.ToLowerInvariant()
    }
  }
  Save-Manifest $case.Project $case.Manifest
  $aggregateLimit = Invoke-Inspect $case.Project
  Assert-Unknown $aggregateLimit 'AD-05 aggregate hash limit'
  Assert-True ($aggregateLimit.Payload.limits.incomplete) 'Aggregate truncation concealed.'

  # AD-05 manifest file location uses the same literal containment as source paths.
  # Expected: unsafe override is unknown/2 without reading external bytes or creating a map.
  $case = New-Project
  foreach ($manifestPath in @('../outside-secret.txt', $outside, '.git/config')) {
    $override = Invoke-Inspect $case.Project $manifestPath
    Assert-Unknown $override 'AD-05 unsafe manifest override'
    Assert-True (-not $override.Raw.Contains($secret)) 'Manifest override secret leaked.'
  }

  # AD-02 equivalent target layout is configured explicitly, without a mandated tree.
  # Expected: safe alternate document root maps correctly; no-Git remains unknown overall.
  $case = New-Project -NoGit
  [IO.Directory]::CreateDirectory((Join-Path $case.Project 'guides/development')) | Out-Null
  Move-Item -LiteralPath (Join-Path $case.Project 'docs/agent/development/common.md') `
    -Destination (Join-Path $case.Project 'guides/development/common.md')
  $case.Manifest.documentsRoot = 'guides'
  $case.Manifest.documents[0].path = 'guides/development/common.md'
  Save-Manifest $case.Project $case.Manifest
  Move-Item -LiteralPath (Join-Path $case.Project 'docs/agent/sources.json') `
    -Destination (Join-Path $case.Project 'guides/sources.json')
  $alternateRoot = Invoke-Inspect $case.Project 'guides/sources.json'
  Assert-Unknown $alternateRoot 'AD-02 alternate root no Git'
  Assert-True ($alternateRoot.Payload.documents[0].status -eq 'fresh' -and
    @($alternateRoot.Payload.inventory.added).Count -eq 0) `
    'AD-02 equivalent document root failed or manifest treated as new document.'

  Write-Output "AD deterministic checks passed: $script:checks Inspect invocations; native Agent/user acceptance pending."
} finally {
  Remove-TestSandbox -Path $fixture -Prefix 'codex-agent-docs-test-'
  Assert-True (-not (Test-Path -LiteralPath $fixture)) 'Owned fixture cleanup failed.'
}
