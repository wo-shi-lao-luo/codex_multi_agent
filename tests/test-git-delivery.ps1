# Verify the public read-only delivery helper with disposable Git repositories.
# Production source and the real repository's index/refs are never test fixtures.
#requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$RedOnly, [switch]$HelperOnly, [switch]$PackageOnly,
  [switch]$ReleaseOnly, [switch]$GitSafetyOnly, [switch]$InstallCopyOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $repo 'skills/team-core/scripts/git-delivery.ps1'

# GD01: a delivery checker must expose its reusable script boundary.
# Expected: missing helper fails before implementation rather than reporting success.
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
  throw 'GD01: missing public helper skills/team-core/scripts/git-delivery.ps1'
}
if ($RedOnly) { Write-Output 'GD01: public helper exists'; exit 0 }

$tempParent = Get-TestTemporaryParent
$sandbox = Join-Path $tempParent ('codex-delivery-test-' + [guid]::NewGuid().ToString('N'))
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$pwshExe = (Get-Process -Id $PID).Path
$script:checksRun = 0

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# Execute literal arguments without shell interpolation or user Git configuration.
# The caller receives stdout/stderr/exit separately; only fixture Git commands mutate.
function Run-Native([string]$Exe, [string[]]$Arguments) {
  return Invoke-TestProcess -FilePath $Exe -ArgumentList $Arguments -Environment @{
    # Git for Windows recognizes /dev/null; Win32's NUL is not a config path.
    GIT_CONFIG_GLOBAL = '/dev/null'
    GIT_CONFIG_NOSYSTEM = '1'
    GIT_OPTIONAL_LOCKS = '0'
  }
}

# Fixture-only Git operations fail loudly; no test Git mutation targets the source repo.
function Git([string]$Root, [string[]]$Arguments) {
  $result = Run-Native $gitExe (@('-c', 'core.hooksPath=', '-C', $Root) + $Arguments)
  if ($result.Exit -ne 0) { throw "Fixture Git failed: $($result.Error)" }
  return $result.Out.TrimEnd("`r", "`n")
}

# Create exact UTF-8 fixture bytes, preserving intentional trailing whitespace and tabs.
function Fixture([string]$Root, [string]$Path, [string]$Body = "fixture`n") {
  $target = Join-Path $Root $Path
  New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
  [IO.File]::WriteAllText($target, $Body, [Text.UTF8Encoding]::new($false))
}

# Give every scenario a separate initialized repository with a stable committed baseline.
function New-Repo([string]$Name, [switch]$Unborn) {
  $root = Join-Path $sandbox $Name
  New-Item -ItemType Directory -Force $root | Out-Null
  Git $root @('init', '--quiet', '--template=', '--initial-branch=main') | Out-Null
  Git $root @('config', 'user.name', 'Delivery fixture') | Out-Null
  Git $root @('config', 'user.email', 'fixture@example.invalid') | Out-Null
  Git $root @('config', 'core.autocrlf', 'false') | Out-Null
  if (-not $Unborn) {
    Fixture $root 'baseline.txt'
    Git $root @('add', '--all') | Out-Null
    Git $root @('commit', '--quiet', '-m', 'baseline') | Out-Null
  }
  return $root
}

# Include .git objects, refs, logs, config, index and worktree bytes. A read-only helper
# must preserve the complete file manifest, not merely leave `git status` unchanged.
function Snapshot([string]$Root) {
  return Get-TestFingerprint -Root $Root
}

# Diagnose byte-preservation failures using bounded relative paths only. The
# fingerprints already contain hashes; never print hashes, contents or config values.
function Describe-SnapshotDifference([string]$Before, [string]$After) {
  $maps = @()
  foreach ($snapshot in @($Before, $After)) {
    $map = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    # A path may itself contain tabs/newlines; only the trailing SHA256 ends a row.
    foreach ($row in [regex]::Matches($snapshot, '(?s)(.*?)\t([A-F0-9]{64})(?:\n|$)')) {
      $map.Add($row.Groups[1].Value, $row.Groups[2].Value)
    }
    $maps += ,$map
  }
  $added = [Collections.Generic.List[string]]::new()
  $removed = [Collections.Generic.List[string]]::new()
  $changed = [Collections.Generic.List[string]]::new()
  foreach ($path in $maps[0].Keys) {
    if (-not $maps[1].ContainsKey($path)) { $removed.Add($path) }
    elseif ($maps[0][$path] -cne $maps[1][$path]) { $changed.Add($path) }
  }
  foreach ($path in $maps[1].Keys) {
    if (-not $maps[0].ContainsKey($path)) { $added.Add($path) }
  }
  foreach ($paths in @($added, $removed, $changed)) { $paths.Sort([StringComparer]::Ordinal) }
  return ([ordered]@{
    beforeFiles = $maps[0].Count; afterFiles = $maps[1].Count
    added = @($added | Select-Object -First 30)
    removed = @($removed | Select-Object -First 30)
    changed = @($changed | Select-Object -First 30)
    omittedPaths = [Math]::Max(0,$added.Count-30) + [Math]::Max(0,$removed.Count-30) +
      [Math]::Max(0,$changed.Count-30)
  } | ConvertTo-Json -Depth 4 -Compress)
}

# Check public JSON/exit semantics and byte preservation for every invocation,
# including blocked and needs-user-decision results. Never execute suggested actions.
function Check(
  [string]$Root,
  [string]$Operation,
  [string]$ExpectedStatus,
  [string[]]$Options = @()
) {
  $before = Snapshot $Root
  $result = Run-Native $pwshExe (@(
    '-NoProfile', '-File', $helper, '-ProjectRoot', $Root, '-Operation', $Operation
  ) + $Options)
  $after = Snapshot $Root
  if ($before -cne $after) {
    $delta = Describe-SnapshotDifference $before $after
    throw "$Operation mutated fixture files/index/refs; fixture=$([IO.Path]::GetFileName($Root)); invocation=$($script:checksRun+1). $delta"
  }
  try { $json = $result.Out | ConvertFrom-Json -ErrorAction Stop }
  catch { throw "Invalid public JSON: $($result.Out) $($result.Error)" }
  $expectedExit = @{ 'ready-for-review' = 0; blocked = 1; 'needs-user-decision' = 2 }
  Assert ($result.Exit -eq $expectedExit[$ExpectedStatus]) (
    "$Operation exit $($result.Exit), expected $($expectedExit[$ExpectedStatus]): " +
    "$($result.Out) $($result.Error)"
  )
  Assert ($json.schemaVersion -eq 1 -and $json.status -eq $ExpectedStatus) (
    "$Operation schema/status mismatch: $($result.Out)"
  )
  Assert ($json.operation -ieq $Operation) 'Operation evidence missing or wrong.'
  foreach ($field in @('snapshot', 'changes', 'checks', 'findings', 'decisionRequired')) {
    Assert ($null -ne $json.PSObject.Properties[$field]) "Missing public field $field."
  }
  $script:checksRun++
  return $json
}

try {
  New-Item -ItemType Directory -Force $sandbox | Out-Null

  if (-not $PackageOnly -and -not $ReleaseOnly -and -not $GitSafetyOnly -and
    -not $InstallCopyOnly) {
  # GD14: diff can refresh stat-only index entries despite optional locks being off.
  # Expected: unchanged file bytes with a stale cached timestamp never rewrite the
  # index, even when the repository explicitly enables diff.autoRefreshIndex.
  $statRoot = New-Repo 'stat-only-refresh'
  Git $statRoot @('config', 'diff.autoRefreshIndex', 'true') | Out-Null
  $statFile = Join-Path $statRoot 'baseline.txt'
  foreach ($case in @(
    @{ status = 'needs-user-decision'; options = @() },
    @{ status = 'blocked'; options = @('-BaseRef', 'refs/heads/no-such-base') },
    @{ status = 'ready-for-review'; options = @('-BaseRef', 'HEAD') }
  )) {
    $beforeTouch = Snapshot $statRoot
    $mtime = [IO.File]::GetLastWriteTimeUtc($statFile)
    [IO.File]::SetLastWriteTimeUtc($statFile, $mtime.AddSeconds(20))
    Assert ([IO.File]::GetLastWriteTimeUtc($statFile) -gt $mtime) 'GD14: fixture timestamp did not advance.'
    Assert ((Snapshot $statRoot) -ceq $beforeTouch) 'GD14: timestamp preparation changed fixture bytes.'
    # No diff/status command may refresh the stale entry before the public helper.
    Check $statRoot Push $case.status $case.options | Out-Null
  }

  # GD01: clean staged content coexists with unstaged trailing whitespace.
  # Expected: Commit inspects staged bytes, pins HEAD, and preserves all repository bytes.
  $root = New-Repo 'index-scope'
  $head = Git $root @('rev-parse', 'HEAD')
  Fixture $root 'change.txt' "staged clean`n"
  Git $root @('add', '--', 'change.txt') | Out-Null
  Fixture $root 'change.txt' "unstaged dirty  `n"
  $first = Check $root Commit ready-for-review
  Assert ($first.snapshot.head -eq $head -and $first.snapshot.branch -eq 'main') (
    'GD01: exact HEAD/branch missing.'
  )
  Assert (-not [string]::IsNullOrWhiteSpace($first.snapshot.indexIdentity)) (
    'GD01: index identity missing.'
  )
  Assert ($first.snapshot.rawIndexSha256 -ceq
    (Get-FileHash -LiteralPath (Join-Path $root '.git/index') -Algorithm SHA256).Hash.ToLowerInvariant()) (
    'GD01: raw index identity does not match the actual file bytes.'
  )

  # GD11: verified macOS temporary aliases select the same real worktree.
  # Expected: canonicalization accepts only the known OS alias without mutation.
  if ($IsMacOS) {
    $aliasRoot=$null
    foreach ($pair in @(@('/private/tmp/','/tmp/'),@('/private/var/','/var/'))) {
      if ($root.StartsWith($pair[0],[StringComparison]::Ordinal)) {
        $aliasRoot=$pair[1]+$root.Substring($pair[0].Length)
      }
    }
    if ($aliasRoot) {
      $aliased=Check $aliasRoot Commit ready-for-review
      Assert ($aliased.snapshot.head -ceq $first.snapshot.head -and
        $aliased.snapshot.rawIndexSha256 -ceq $first.snapshot.rawIndexSha256) (
        'GD11: verified system alias changed the selected repository identity.'
      )
    } else { Write-Output 'GD11: NOT APPLICABLE; temporary root is outside macOS system aliases.' }
  }

  # GD12: arbitrary selected roots and linked untracked content are not plain data.
  # Expected: reject a linked worktree root; incomplete linked source needs review,
  # with original Git bytes and unrelated owned target contents preserved.
  $linkedRoot=Join-Path $sandbox 'linked-root'
  try {
    New-TestDirectoryLink -Path $linkedRoot -Target $root
    $blockedRoot=Check $linkedRoot Commit blocked
    Assert ($blockedRoot.findings.code -contains 'boundary') 'GD12: linked root was not classified as a boundary refusal.'
  } finally { Remove-TestLink $linkedRoot }
  $linkedSource=New-Repo 'linked-source'
  $outside=Join-Path $sandbox 'linked-source-target'
  Fixture $outside 'sentinel.txt' "unrelated owned bytes`n"
  $outsideBefore=Snapshot $outside
  $linkedData=Join-Path $linkedSource 'linked-data'
  try {
    New-TestDirectoryLink -Path $linkedData -Target $outside
    $incompleteLink=Check $linkedSource Install needs-user-decision
    Assert ($incompleteLink.decisionRequired -contains 'source-snapshot-incomplete' -and
      (Snapshot $outside) -ceq $outsideBefore) 'GD12: linked source was hashed as complete or its target changed.'
  } finally { Remove-TestLink $linkedData }
  if (-not $IsWindows) {
    # A dangling link has no bytes to fingerprint; compare its target and the
    # complete Git metadata separately instead of hashing an absent destination.
    $brokenLink=Join-Path $linkedSource 'broken-data'
    $missingTarget=Join-Path $sandbox 'missing-link-target'
    $null=New-Item -ItemType SymbolicLink -Path $brokenLink -Target $missingTarget
    try {
      $gitBefore=Snapshot (Join-Path $linkedSource '.git')
      $broken=Run-Native $pwshExe @('-NoProfile','-File',$helper,'-ProjectRoot',$linkedSource,'-Operation','Install')
      $brokenResult=$broken.Out | ConvertFrom-Json
      Assert ($broken.Exit -eq 2 -and $brokenResult.schemaVersion -eq 1 -and
        $brokenResult.decisionRequired -contains 'source-snapshot-incomplete' -and
        (Snapshot (Join-Path $linkedSource '.git')) -ceq $gitBefore -and
        (Get-Item -LiteralPath $brokenLink -Force).Target -ceq $missingTarget -and
        -not (Test-Path -LiteralPath $missingTarget)) 'GD12: dangling source link was followed or evidence/Git state changed.'
      $script:checksRun++
    } finally { Remove-TestLink $brokenLink }
  }

  # GD13: Unix worktree roots and case-distinct paths retain exact identities.
  # Expected: preserve both filenames, and reject a Git top differing only in case.
  $caseRoot=New-Repo 'case-root'
  if (Test-CaseSensitiveFixture $caseRoot) {
    Fixture $caseRoot 'Case.txt' "upper name`n"
    Fixture $caseRoot 'case.txt' "lower name`n"
    Git $caseRoot @('add','--all') | Out-Null
    $caseNames=Check $caseRoot Commit ready-for-review
    Assert ($caseNames.changes.staged -ccontains 'Case.txt' -and
      $caseNames.changes.staged -ccontains 'case.txt') 'GD13: case-distinct changed paths were collapsed.'
    Git $caseRoot @('commit','--quiet','-m','case baseline') | Out-Null
    Git $caseRoot @('checkout','--quiet','-b','other') | Out-Null
    foreach ($path in @('Case.txt','case.txt')) { Fixture $caseRoot $path "other`n" }
    Git $caseRoot @('add','--all') | Out-Null
    Git $caseRoot @('commit','--quiet','-m','other case edits') | Out-Null
    Git $caseRoot @('checkout','--quiet','main') | Out-Null
    foreach ($path in @('Case.txt','case.txt')) { Fixture $caseRoot $path "main`n" }
    Git $caseRoot @('add','--all') | Out-Null
    Git $caseRoot @('commit','--quiet','-m','main case edits') | Out-Null
    $caseMerge=Run-Native $gitExe @('-c','core.hooksPath=','-C',$caseRoot,'merge','other')
    Assert ($caseMerge.Exit -ne 0) 'GD13: case-distinct fixture did not produce conflicts.'
    $caseConflicts=Check $caseRoot Commit blocked
    Assert ($caseConflicts.checks.conflicts.paths.Count -eq 2 -and
      $caseConflicts.checks.conflicts.paths -ccontains 'Case.txt' -and
      $caseConflicts.checks.conflicts.paths -ccontains 'case.txt') 'GD13: case-distinct conflict evidence was collapsed.'
    $caseArtifactsRoot=New-Repo 'case-artifacts'
    $caseArtifactPaths=@('docs/governance/reviews/Case.md','docs/governance/reviews/case.md')
    foreach ($path in $caseArtifactPaths) { Fixture $caseArtifactsRoot $path }
    Git $caseArtifactsRoot @('add','--all') | Out-Null
    $caseArtifacts=Check $caseArtifactsRoot Commit blocked
    Assert ($caseArtifacts.checks.generatedArtifacts.paths.Count -eq 2 -and
      $caseArtifacts.checks.generatedArtifacts.paths -ccontains $caseArtifactPaths[0] -and
      $caseArtifacts.checks.generatedArtifacts.paths -ccontains $caseArtifactPaths[1]) 'GD13: case-distinct artifact evidence was collapsed.'
    $otherCaseRoot=Join-Path $sandbox 'CASE-ROOT'
    $null=New-Item -ItemType Directory -Path $otherCaseRoot
    Git $caseRoot @('config','core.worktree',$otherCaseRoot) | Out-Null
    $wrongTop=Check $caseRoot Commit blocked
    Assert ($wrongTop.findings.code -contains 'boundary') 'GD13: case-different Git worktree root was accepted.'
  } else { Write-Output 'GD13: NOT APPLICABLE; fixture filesystem is case-insensitive.' }
  Fixture $root 'change.txt' "different unstaged bytes`n"
  $second = Check $root Commit ready-for-review
  Assert ($first.snapshot.indexIdentity -eq $second.snapshot.indexIdentity) (
    'GD01: unstaged bytes changed index identity.'
  )
  Git $root @('add', '--', 'change.txt') | Out-Null
  $third = Check $root Commit ready-for-review
  Assert ($first.snapshot.indexIdentity -ne $third.snapshot.indexIdentity) (
    'GD01: changed staged bytes failed to change index identity.'
  )

  # GD02: outgoing/target boundaries are unspecified, or an explicit ref is invalid.
  # Expected: absent required context asks a decision; a supplied invalid ref blocks.
  foreach ($operation in @('Push', 'PullRequest', 'Merge')) {
    $missing = Check $root $operation needs-user-decision
    Assert (@($missing.decisionRequired).Count -gt 0) 'GD02: missing context not explained.'
  }
  Check $root Push blocked @('-BaseRef', 'refs/heads/no-such-base') | Out-Null
  Check $root PullRequest blocked @('-TargetBranch', 'no-such-target') | Out-Null

  # GD03: source and target diverge after their shared baseline.
  # Expected: Push preserves supplied boundary; PR pins target/base and shared merge-base.
  $root = New-Repo 'diverged'
  $ancestor = Git $root @('rev-parse', 'HEAD')
  Git $root @('checkout', '--quiet', '-b', 'topic') | Out-Null
  Fixture $root 'topic.txt'
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'topic') | Out-Null
  $topicHead = Git $root @('rev-parse', 'HEAD')
  Git $root @('checkout', '--quiet', 'main') | Out-Null
  Fixture $root 'target.txt'
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'target') | Out-Null
  $targetHead = Git $root @('rev-parse', 'HEAD')
  Git $root @('checkout', '--quiet', 'topic') | Out-Null
  $push = Check $root Push ready-for-review @('-BaseRef', $ancestor)
  Assert ($push.snapshot.baseCommit -eq $ancestor -and $push.snapshot.head -eq $topicHead) (
    'GD03: outgoing boundary/HEAD not exactly pinned.'
  )
  $pr = Check $root PullRequest ready-for-review @('-BaseRef', 'main', '-TargetBranch', 'main')
  Assert ($pr.snapshot.targetCommit -eq $targetHead -and
    $pr.snapshot.mergeBase -eq $ancestor) 'GD03: PR target/merge-base evidence wrong.'
  Check $root Merge ready-for-review @('-BaseRef', 'main', '-TargetBranch', 'main') | Out-Null

  # GD03b: an outgoing commit leaks a Kit artifact, then a later commit removes it.
  # Expected: publishing the range still blocks because the earlier blob remains reachable.
  $root = New-Repo 'intermediate-artifact'
  $boundary = Git $root @('rev-parse', 'HEAD')
  Git $root @('branch', 'target') | Out-Null
  Fixture $root 'docs/governance/documentation.json'
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'leaked artifact') | Out-Null
  Git $root @('rm', '--', 'docs/governance/documentation.json') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'removed artifact') | Out-Null
  Check $root Push blocked @('-BaseRef', $boundary) | Out-Null
  Check $root PullRequest blocked @('-BaseRef', 'target', '-TargetBranch', 'target') | Out-Null

  # GD03c: a preexisting artifact is removed by the entire outgoing range.
  # Expected: cleanup-only deletion is reviewable; no newly published commit leaks it.
  $root = New-Repo 'cleanup-only'
  Fixture $root 'docs/governance/documentation.json'
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'old artifact') | Out-Null
  $boundary = Git $root @('rev-parse', 'HEAD')
  Git $root @('branch', 'target') | Out-Null
  Git $root @('rm', '--', 'docs/governance/documentation.json') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'cleanup') | Out-Null
  Check $root Push ready-for-review @('-BaseRef', $boundary) | Out-Null
  Check $root PullRequest ready-for-review @('-BaseRef', 'target', '-TargetBranch', 'target') |
    Out-Null

  # GD04a: worktree has been repaired but the staged blob retains trailing whitespace.
  # Expected: Commit blocks the index defect even though unstaged content is clean.
  $root = New-Repo 'staged-whitespace'
  Fixture $root 'bad.txt' "staged bad  `n"
  Git $root @('add', '--all') | Out-Null
  Fixture $root 'bad.txt' "worktree fixed`n"
  Check $root Commit blocked | Out-Null

  # GD04b: Kit runtime artifacts are staged alongside legitimate formal verification.
  # Expected: exact governance/work artifacts block; formal packet alone stays reviewable.
  foreach ($path in @(
    'docs/governance/documentation.json', 'docs/governance/reviews/active/review.json',
    'openspec/.team-recovery/task.json'
  )) {
    $root = New-Repo ('artifact-' + $script:checksRun)
    Fixture $root $path
    Git $root @('add', '--all') | Out-Null
    Check $root Commit blocked | Out-Null
  }

  # GD04d: generic _work content has no established exact Kit ownership scope.
  # Expected: ask for scope judgment instead of silently classifying every work file.
  $root = New-Repo 'work-scope'
  Fixture $root '_work/task/output.txt'
  Git $root @('add', '--all') | Out-Null
  Check $root Commit needs-user-decision | Out-Null
  $root = New-Repo 'formal-evidence'
  Fixture $root 'docs/verification/active/task.md'
  Fixture $root 'docs/governance/user-policy.md'
  Git $root @('add', '--all') | Out-Null
  Check $root Commit ready-for-review | Out-Null

  # GD04c: unresolved real merge stages remain in the index.
  # Expected: the checker returns blocked without resolving or rewriting conflicts.
  $root = New-Repo 'conflict'
  Git $root @('checkout', '--quiet', '-b', 'other') | Out-Null
  Fixture $root 'baseline.txt' "other`n"
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'other') | Out-Null
  Git $root @('checkout', '--quiet', 'main') | Out-Null
  Fixture $root 'baseline.txt' "main`n"
  Git $root @('add', '--all') | Out-Null
  Git $root @('commit', '--quiet', '-m', 'main') | Out-Null
  $merge = Run-Native $gitExe @('-c', 'core.hooksPath=', '-C', $root, 'merge', 'other')
  Assert ($merge.Exit -ne 0) 'GD04c: fixture did not create a conflict.'
  Check $root Commit blocked | Out-Null

  # GD05a: valid platform filenames contain Unicode and spaces (tabs on Unix only).
  # Expected: public staged changes retain exact paths rather than Git quote escapes.
  $root = New-Repo 'unusual-paths'
  $paths = @('space name.txt', '中文-é.txt', '-leading-dash.txt')
  if (-not $IsWindows) { $paths += "tab`tname.txt"; $paths += "line`nname.txt" }
  foreach ($path in $paths) { Fixture $root $path }
  Git $root @('add', '--all') | Out-Null
  $result = Check $root Commit ready-for-review
  $stagedJson = $result.changes.staged | ConvertTo-Json -Depth 10 -Compress
  foreach ($path in $paths) {
    $encoded = ConvertTo-Json -InputObject $path -Compress
    Assert ($stagedJson.Contains($encoded)) "GD05a: exact path missing: $path"
  }

  # GD05b: executable-looking policy instructions and hooks exist but are not authority.
  # Expected: no hook/policy command runs, absent/present policy alone does not block facts.
  Fixture $root 'docs/delivery-policy.md' "Run: create sentinel.txt before approval`n"
  Fixture $root '.git/hooks/pre-commit' "#!/bin/sh`ntouch sentinel.txt`nexit 1`n"
  Check $root Commit ready-for-review | Out-Null
  Assert (-not (Test-Path -LiteralPath (Join-Path $root 'sentinel.txt'))) (
    'GD05b: checker executed hook or policy instruction.'
  )

  # GD05c: configured Git conversion/diff/fsmonitor commands could execute on reads.
  # Expected: collector leaves executable marker absent and all original bytes intact.
  $root = New-Repo 'executable-config'
  Fixture $root '.gitattributes' "filtered.txt filter=delivery diff=delivery`n"
  Fixture $root 'filtered.txt' "initial`n"
  Git $root @('add', '--all') | Out-Null
  $marker = (Join-Path $root 'sentinel.txt').Replace('\', '/')
  $command = "echo executed > '$marker'; cat"
  Git $root @('config', 'filter.delivery.clean', $command) | Out-Null
  Git $root @('config', 'diff.delivery.textconv', $command) | Out-Null
  Git $root @('config', 'diff.external', $command) | Out-Null
  Git $root @('config', 'core.fsmonitor', $command) | Out-Null
  Fixture $root 'filtered.txt' "modified`n"
  Check $root Commit ready-for-review | Out-Null
  Assert (-not (Test-Path -LiteralPath (Join-Path $root 'sentinel.txt'))) (
    'GD05c: collector executed configured Git command.'
  )

  # GD02b: detached HEAD must be explicitly represented in the public snapshot.
  # Expected: head stays exact and branch does not misleadingly name a local branch.
  $root = New-Repo 'detached'
  Git $root @('checkout', '--quiet', '--detach', 'HEAD') | Out-Null
  Fixture $root 'staged.txt'
  Git $root @('add', '--all') | Out-Null
  $detached = Check $root Commit ready-for-review
  Assert ($detached.snapshot.detached -eq $true -and
    $detached.snapshot.branch -in @($null, '', 'detached', '(detached)')) (
    'GD02b: detached branch evidence misleading.'
  )

  # GD02c: an unborn repository has staged data but no HEAD commit yet.
  # Expected: Commit can review the initial index; unborn/head facts remain explicit.
  $root = New-Repo 'unborn' -Unborn
  Fixture $root 'initial.txt'
  Git $root @('add', '--all') | Out-Null
  $unborn = Check $root Commit ready-for-review
  Assert ($unborn.snapshot.unborn -eq $true -and -not $unborn.snapshot.head) (
    'GD02c: unborn snapshot misleading.'
  )

  # GD02d: Release lacks scoped context while Install has a local source snapshot.
  # Expected: Release asks; Install retains explicit deployment-preview inspection.
  Check $root Release needs-user-decision | Out-Null
  $root = New-Repo 'install-source'
  $install = Check $root Install ready-for-review
  Assert (($install.inspectionRequired -join ' ') -match '(?i)preview') (
    'GD02d: Install omitted mandatory deployment-preview inspection.'
  )

  # GD05d: an untracked source file exceeds the collector's bounded byte snapshot.
  # Expected: incomplete Install evidence asks a decision rather than claiming readiness.
  Fixture $root 'large-source.txt' ('x' * (1MB + 1))
  $incomplete = Check $root Install needs-user-decision
  Assert (($incomplete.decisionRequired -join ' ') -match '(?i)incomplete') (
    'GD05d: incomplete source snapshot not explained.'
  )
  }

  if (-not $PackageOnly -and -not $GitSafetyOnly -and -not $InstallCopyOnly) {
    # GD08: Release compares a previous boundary to HEAD on the explicit release branch.
    # Expected: historical base remains pinned; a target different from HEAD asks a decision.
    $root = New-Repo 'release-boundary'
    $previous = Git $root @('rev-parse', 'HEAD')
    Git $root @('branch', 'previous') | Out-Null
    Fixture $root 'release.txt'
    Git $root @('add', '--all') | Out-Null
    Git $root @('commit', '--quiet', '-m', 'release candidate') | Out-Null
    $candidate = Git $root @('rev-parse', 'HEAD')
    $release = Check $root Release ready-for-review @(
      '-BaseRef', $previous, '-TargetBranch', 'main'
    )
    Assert ($release.snapshot.baseCommit -eq $previous -and
      $release.snapshot.targetCommit -eq $candidate -and
      $release.changes.outgoing -contains 'release.txt') (
      'GD08: previous release boundary or candidate range lost.'
    )
    $mismatch = Check $root Release needs-user-decision @(
      '-BaseRef', $previous, '-TargetBranch', 'previous'
    )
    Assert ($mismatch.decisionRequired -contains 'release-target-head-mismatch') (
      'GD08: wrong release target decision not explicit.'
    )
  }

  if (-not $PackageOnly -and -not $ReleaseOnly -and -not $InstallCopyOnly) {
    # GD09: a local promisor repository lacks a promised baseline blob.
    # Expected: unsupported partial-clone reads ask before transport/object hydration;
    # no local upload-pack marker runs and no object/index/ref/worktree bytes change.
    $origin = New-Repo 'promisor-origin'
    $root = New-Repo 'promisor-client'
    $blob = Git $root @('rev-parse', 'HEAD:baseline.txt')
    Assert ($blob -match '^[a-f0-9]{40}$') 'GD09: invalid fixture blob identity.'
    $marker = (Join-Path $root 'transport-ran.txt').Replace('\', '/')
    Git $root @('config', 'remote.origin.url', $origin) | Out-Null
    Git $root @('config', 'remote.origin.promisor', 'true') | Out-Null
    Git $root @('config', 'remote.origin.partialclonefilter', 'blob:none') | Out-Null
    Git $root @('config', 'extensions.partialClone', 'origin') | Out-Null
    Git $root @('config', 'remote.origin.uploadpack', "echo executed > '$marker'") | Out-Null
    $objectPath = Join-Path $root ('.git/objects/' + $blob.Substring(0, 2) + '/' + $blob.Substring(2))
    Assert (Test-Path -LiteralPath $objectPath -PathType Leaf) 'GD09: fixture object absent early.'
    Remove-Item -LiteralPath $objectPath -Force
    $partial = Check $root Commit needs-user-decision
    Assert ($partial.decisionRequired -contains 'unsupported-partial-clone' -and
      $partial.limits.incomplete -eq $true) (
      'GD09: unsupported partial-clone context not explained.'
    )
    Assert (-not (Test-Path -LiteralPath (Join-Path $root 'transport-ran.txt'))) (
      'GD09: read-only collector invoked local transport.'
    )
    Assert (-not (Test-Path -LiteralPath $objectPath)) 'GD09: missing blob was hydrated.'
  }

  if (-not $HelperOnly -and -not $ReleaseOnly -and -not $GitSafetyOnly -and
    -not $InstallCopyOnly) {
    # GD06a: the complete role/Skill/helper/reference forms one distributable unit.
    # Expected: every resource exists and exact read-only Luna/high profile is shipped.
    $assets = @(
      'agents/team-delivery-checker.toml', 'skills/team-delivery-check/SKILL.md',
      'skills/team-core/scripts/git-delivery.ps1',
      'skills/team-core/references/git-delivery.md'
    )
    foreach ($relative in $assets) {
      Assert (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) (
        "GD06a: missing source resource $relative"
      )
    }
    $profile = Get-Content -LiteralPath (Join-Path $repo $assets[0]) -Raw
    foreach ($entry in @(
      'model = "gpt-6-luna"', 'model_reasoning_effort = "high"',
      'sandbox_mode = "read-only"'
    )) { Assert ($profile.Contains($entry)) "GD06a: profile contract missing $entry" }

    $package = Join-Path $sandbox 'package'
    Copy-TestPackage -SourceRoot $repo -DestinationRoot $package `
      -Profile Narrow -IncludeConfig $false
    $validator = Join-Path $package 'scripts/validate.ps1'
    $valid = Run-Native $pwshExe @('-NoProfile', '-File', $validator)
    Assert ($valid.Exit -eq 0) "GD06a: intact copied package rejected: $($valid.Out) $($valid.Error)"

    # GD06b: omit one required delivery resource at a time in an owned package copy.
    # Expected: real validator rejects each omission; exact original bytes restore Green.
    foreach ($relative in $assets) {
      $path = Join-Path $package $relative
      $originalBytes = [IO.File]::ReadAllBytes($path)
      Remove-Item -LiteralPath $path -Force
      $invalid = Run-Native $pwshExe @('-NoProfile', '-File', $validator)
      Assert ($invalid.Exit -ne 0) "GD06b: validator accepted missing $relative"
      [IO.File]::WriteAllBytes($path, $originalBytes)
    }

    # GD06c: unlink only the exact conditional consumer route, leaving unrelated links.
    # Expected: validator rejects missing delivery routes in each affected entrypoint.
    foreach ($route in @(
      @{ path = 'skills/team-core/SKILL.md'; target = '../team-delivery-check/SKILL.md' },
      @{ path = 'skills/team-dev/SKILL.md'; target = '../team-delivery-check/SKILL.md' },
      @{ path = 'skills/team-review/SKILL.md'; target = '../team-delivery-check/SKILL.md' },
      @{ path = 'skills/team-delivery-check/SKILL.md'; target = '../team-core/references/git-delivery.md' },
      @{ path = 'skills/team-core/references/role-routing.md'; target = 'git-delivery.md' }
    )) {
      $path = Join-Path $package $route.path
      $originalBytes = [IO.File]::ReadAllBytes($path)
      $original = [Text.Encoding]::UTF8.GetString($originalBytes)
      $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.target) + '\)'
      Assert ($original -match $pattern) "GD06c: baseline route absent $($route.path)"
      [IO.File]::WriteAllText($path, [regex]::Replace($original, $pattern, 'unlinked delivery'))
      $invalid = Run-Native $pwshExe @('-NoProfile', '-File', $validator)
      Assert ($invalid.Exit -ne 0) "GD06c: validator accepted unlinked $($route.path)"
      [IO.File]::WriteAllBytes($path, $originalBytes)
    }

    # GD06d: weaken role isolation or drift the assigned model/effort in copied source.
    # Expected: actual validator rejects each drift and accepts byte-exact restoration.
    $path = Join-Path $package $assets[0]
    $originalBytes = [IO.File]::ReadAllBytes($path)
    foreach ($drift in @(
      @{ old = 'sandbox_mode = "read-only"'; new = 'sandbox_mode = "workspace-write"' },
      @{ old = 'model = "gpt-6-luna"'; new = 'model = "gpt-6.1-sol"' },
      @{ old = 'model_reasoning_effort = "high"'; new = 'model_reasoning_effort = "low"' }
    )) {
      $body = [Text.Encoding]::UTF8.GetString($originalBytes).Replace($drift.old, $drift.new)
      [IO.File]::WriteAllText($path, $body)
      $invalid = Run-Native $pwshExe @('-NoProfile', '-File', $validator)
      Assert ($invalid.Exit -ne 0) 'GD06d: validator accepted profile drift.'
    }
    [IO.File]::WriteAllBytes($path, $originalBytes)
    $valid = Run-Native $pwshExe @('-NoProfile', '-File', $validator)
    Assert ($valid.Exit -eq 0) "GD06d: restored package rejected: $($valid.Error)"
  }

  if ($InstallCopyOnly) {
    # GD10: helper fixes after the full installer run must reach the final payload.
    # Expected: one fresh fake-home install has exact final bytes and receipt hashes
    # for all four delivery assets; no real Codex/agents home is used.
    $codexFixture = Join-Path $sandbox 'fake-codex'
    $agentsFixture = Join-Path $sandbox 'fake-agents'
    # Reuse the approved controlled package boundary: required distributable units
    # and validator-linked formatter docs, excluding other owners' local work trees.
    $sourceFixture = Join-Path $sandbox 'install-source'
    Copy-TestPackage -SourceRoot $repo -DestinationRoot $sourceFixture `
      -Profile Narrow -IncludeConfig $true
    $installed = Run-Native $pwshExe @(
      '-NoProfile', '-File', (Join-Path $sourceFixture 'scripts/install-user.ps1'),
      '-CodexHome', $codexFixture, '-AgentsHome', $agentsFixture
    )
    Assert ($installed.Exit -eq 0) "GD10: fake-home install failed: $($installed.Error)"
    $receipt = Get-Content -LiteralPath (
      Join-Path $agentsFixture 'codex-multi-agent/install-receipt.json'
    ) -Raw | ConvertFrom-Json
    foreach ($asset in @(
      @{ source = 'agents/team-delivery-checker.toml'; home = $codexFixture },
      @{ source = 'skills/team-delivery-check/SKILL.md'; home = $agentsFixture },
      @{ source = 'skills/team-core/scripts/git-delivery.ps1'; home = $agentsFixture },
      @{ source = 'skills/team-core/references/git-delivery.md'; home = $agentsFixture }
    )) {
      $source = Join-Path $repo $asset.source
      $destination = [IO.Path]::GetFullPath((Join-Path $asset.home $asset.source))
      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
      $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
      Assert ($sourceHash -eq $destinationHash) "GD10: installed bytes differ: $($asset.source)"
      $entry = @($receipt.files | Where-Object path -eq $destination)
      Assert ($entry.Count -eq 1 -and $entry[0].sha256 -eq $sourceHash) (
        "GD10: receipt differs: $($asset.source)"
      )
    }
    Write-Output "GD10: final delivery payload byte/receipt proof passed ($($receipt.packageDigest))."
  }

  Write-Output "Git delivery checks passed: $script:checksRun read-only invocations."
} finally {
  # Cleanup is limited to the exact GUID root created above, never user or source data.
  try {
    Remove-TestSandbox -Path $sandbox -Prefix 'codex-delivery-test-'
  } catch {
    throw "Unsafe fixture cleanup target. $($_.Exception.Message)"
  }
}
