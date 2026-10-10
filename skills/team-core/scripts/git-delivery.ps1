#requires -Version 7.0
<#
Collect bounded local Git delivery evidence as schema-1 JSON. This helper never
stages, writes objects/refs, contacts a remote, interprets project policy, or grants
delivery approval. Exit 0 means ready for semantic review; 1 blocks; 2 needs a
decision. Ref arguments name local commit-ish objects only. Git stderr/diff content
is never returned because it can contain credentials or source secrets.
#>
[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$Operation,
  [string]$BaseRef,
  [string]$TargetBranch,
  [string]$RemoteName = 'origin'
)
$ErrorActionPreference = 'Stop'
$clock = [Diagnostics.Stopwatch]::StartNew()
$maximumOutput = 4MB
$maximumPaths = 20000
$maximumCommits = 200
$script:filterConfiguration = @()
$script:capturedBytes = 0
$introducedArtifacts = $null
$findings = [Collections.Generic.List[object]]::new()
$decisions = [Collections.Generic.List[string]]::new()
$result = [ordered]@{
  schemaVersion = 1
  operation = $Operation
  status = 'needs-user-decision'
  snapshot = [ordered]@{
    head = $null; branch = $null; detached = $false; unborn = $false
    indexIdentity = $null; rawIndexSha256 = $null; workingTreeIdentity = $null
    baseRef = $BaseRef; baseCommit = $null; targetBranch = $TargetBranch
    targetCommit = $null; mergeBase = $null
  }
  changes = [ordered]@{
    staged = @(); unstaged = @(); untracked = @(); outgoing = @()
    intermediateCommits = @()
  }
  checks = [ordered]@{
    conflicts = @{ status = 'incomplete'; paths = @() }
    whitespace = @{ status = 'not-applicable'; scope = ''; count = 0 }
    generatedArtifacts = @{ status = 'incomplete'; paths = @() }
    freshness = @{ status = 'incomplete'; before = $null; after = $null }
  }
  inspectionRequired = @(
    'Interpret applicable project instructions, delivery policy and user decisions.'
    'Inspect actual scoped changes and current test/review evidence; mechanical readiness is not approval.'
    'Check configured DocsRoot and exact task WorkPath under generated-artifacts.md.'
  )
  findings = @()
  decisionRequired = @()
  limits = @{
    maxOutputBytes = $maximumOutput; maxCommits = $maximumCommits
    maxPaths = $maximumPaths; timeoutSeconds = 60; incomplete = $false
  }
}

# Hash bytes rather than decoded lines: NUL filenames and entry object identities
# must survive unchanged. A missing index is legitimate for an unborn repository.
function Get-DeliveryHash([byte[]]$Bytes) {
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

# Hashing a Git path must not follow a linked ancestor into unrelated local data.
# Git metadata may live outside the worktree; its resolved index is read only.
function Test-DeliveryPlainPath([string]$Path) {
  $cursor = $Path
  while ($cursor) {
    if ((Test-Path -LiteralPath $cursor) -and
        ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      return $false
    }
    $parent = Split-Path -Parent $cursor
    if ($parent -eq $cursor) { break }
    $cursor = $parent
  }
  return $true
}

# Each process uses a fixed built-in Git command with separate argv entries.
# Drain both pipes concurrently with byte/time bounds; never echo Git stderr.
function Invoke-DeliveryGit([string[]]$Arguments, [int[]]$Allowed = @(0)) {
  if ($clock.Elapsed.TotalSeconds -gt 60) { throw 'LIMIT' }
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $git.Source
  $info.WorkingDirectory = $root
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.RedirectStandardInput = $true
  foreach ($name in @($info.Environment.Keys)) {
    if ($name -like 'GIT_*') { $null = $info.Environment.Remove($name) }
  }
  $info.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $info.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'
  $info.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  $info.Environment['GIT_TERMINAL_PROMPT'] = '0'
  $info.Environment['GIT_NO_REPLACE_OBJECTS'] = '1'
  $info.Environment['GIT_NO_LAZY_FETCH'] = '1'
  $configuration = @(
    '--no-optional-locks', '--no-pager', '-c', 'core.fsmonitor=false',
    '-c', 'core.untrackedCache=false', '-c', 'core.quotePath=false',
    '-c', 'core.hooksPath=/dev/null', '-c', 'diff.external=',
    '-c', 'core.excludesFile=/dev/null', '-c', 'submodule.recurse=false',
    '-c', "safe.directory=$($root.Replace('\','/'))"
  )
  foreach ($argument in $configuration + @($script:filterConfiguration) + $Arguments) {
    $info.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  $output = [IO.MemoryStream]::new()
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $outBuffer = [byte[]]::new(8192)
    $errBuffer = [byte[]]::new(8192)
    $outTask = $process.StandardOutput.BaseStream.ReadAsync($outBuffer, 0, $outBuffer.Length)
    $errTask = $process.StandardError.BaseStream.ReadAsync($errBuffer, 0, $errBuffer.Length)
    $outDone = $false
    $errDone = $false
    $total = 0
    while (-not ($outDone -and $errDone)) {
      if ($clock.Elapsed.TotalSeconds -gt 60) { throw 'LIMIT' }
      if (-not $outDone -and $outTask.IsCompleted) {
        $count = $outTask.GetAwaiter().GetResult()
        $total += $count
        if ($total -gt $maximumOutput) { throw 'LIMIT' }
        if ($count -eq 0) { $outDone = $true }
        else {
          $output.Write($outBuffer, 0, $count)
          $outTask = $process.StandardOutput.BaseStream.ReadAsync($outBuffer, 0, $outBuffer.Length)
        }
      }
      if (-not $errDone -and $errTask.IsCompleted) {
        $count = $errTask.GetAwaiter().GetResult()
        $total += $count
        if ($total -gt $maximumOutput) { throw 'LIMIT' }
        if ($count -eq 0) { $errDone = $true }
        else { $errTask = $process.StandardError.BaseStream.ReadAsync($errBuffer, 0, $errBuffer.Length) }
      }
      [Threading.Thread]::Sleep(2)
    }
    if (-not $process.WaitForExit(1000)) { throw 'LIMIT' }
    if ($process.ExitCode -notin $Allowed) { throw 'GIT' }
    $bytes = $output.ToArray()
    $script:capturedBytes += $total
    if ($script:capturedBytes -gt 16MB) { throw 'LIMIT' }
    return @{ code = $process.ExitCode; bytes = $bytes; text = [Text.Encoding]::UTF8.GetString($bytes) }
  } finally {
    if ($process.Id -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    $process.Dispose()
    $output.Dispose()
  }
}

# Local refs are resolved once to immutable commit IDs. Option-looking and revision
# expressions with whitespace/control characters are rejected, not guessed.
function Resolve-DeliveryCommit([string]$Reference) {
  if ([string]::IsNullOrWhiteSpace($Reference) -or $Reference.StartsWith('-') -or
      $Reference -match '[\s\x00-\x1f]' -or $Reference.Length -gt 256) { throw 'REF' }
  $resolved = Invoke-DeliveryGit @('rev-parse', '--verify', '--end-of-options', "$Reference^{commit}") @(0,128)
  if ($resolved.code -ne 0 -or $resolved.text.Trim() -notmatch '^[a-f0-9]{40,64}$') { throw 'REF' }
  return $resolved.text.Trim()
}

# --name-only -z deliberately omits rename pairing: both changed path identities
# are retained with --no-renames, including filenames containing line breaks.
function Get-DeliveryPaths([string[]]$Arguments) {
  $data = Invoke-DeliveryGit $Arguments
  $paths = @($data.text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
  if ($paths.Count -gt $maximumPaths) { throw 'LIMIT' }
  return ,$paths
}

# Fingerprint HEAD, symbolic branch, actual index entries/raw bytes and working
# diff. Untracked content is bounded and excludes credential/dependency locations;
# excluded content cannot count as an exact Install source snapshot.
function Get-DeliverySnapshot {
  $headData = Invoke-DeliveryGit @('rev-parse', '--verify', 'HEAD') @(0,128)
  $branchData = Invoke-DeliveryGit @('symbolic-ref', '--quiet', '--short', 'HEAD') @(0,1)
  $entries = Invoke-DeliveryGit @('ls-files', '--stage', '-z')
  $status = Invoke-DeliveryGit @('status', '--porcelain=v1', '-z', '--untracked-files=all', '--ignore-submodules=all')
  $diff = Invoke-DeliveryGit @('diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--binary', '--ignore-submodules=all')
  $indexPath = (Invoke-DeliveryGit @('rev-parse', '--git-path', 'index')).text.Trim()
  if (-not [IO.Path]::IsPathRooted($indexPath)) { $indexPath = Join-Path $root $indexPath }
  $indexHash = $null
  if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    if (-not (Test-DeliveryPlainPath $indexPath)) { throw 'BOUNDARY' }
    $item = Get-Item -LiteralPath $indexPath -Force
    if ($item.Length -gt 32MB) { throw 'LIMIT' }
    $indexHash = Get-DeliveryHash ([IO.File]::ReadAllBytes($indexPath))
  }
  $untracked = Get-DeliveryPaths @('ls-files', '--others', '--exclude-standard', '-z')
  $untrackedHashes = [Collections.Generic.List[string]]::new()
  $skipped = [Collections.Generic.List[string]]::new()
  $totalBytes = 0
  foreach ($path in $untracked) {
    if ($path -match '(^|/)(\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|\.venv|venv)(/|$)' -or
        $path -match '(^|/)(\.env(?:\..*)?|credentials|.*\.(?:pem|key))$') {
      $skipped.Add($path)
      continue
    }
    $fullPath = Join-Path $root $path
    if (-not (Test-DeliveryPlainPath $fullPath)) { $skipped.Add($path); continue }
    $item = Get-Item -LiteralPath $fullPath -Force
    $totalBytes += $item.Length
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or
        $item.Length -gt 1MB -or $totalBytes -gt 16MB) { $skipped.Add($path); continue }
    $untrackedHashes.Add($path + ':' + (Get-DeliveryHash ([IO.File]::ReadAllBytes($fullPath))))
  }
  $head = if ($headData.code -eq 0) { $headData.text.Trim() } else { $null }
  $branch = if ($branchData.code -eq 0) { $branchData.text.Trim() } else { $null }
  if (-not $head -and -not $branch) { throw 'GIT' }
  $identityParts = @(
    $head, $branch, (Get-DeliveryHash $entries.bytes), $indexHash,
    (Get-DeliveryHash $status.bytes), (Get-DeliveryHash $diff.bytes),
    ($untrackedHashes -join "`0"), ($skipped -join "`0")
  )
  return @{
    head = $head; branch = $branch; entries = $entries.text
    indexIdentity = Get-DeliveryHash $entries.bytes; rawIndexSha256 = $indexHash
    workingTreeIdentity = Get-DeliveryHash ([Text.Encoding]::UTF8.GetBytes($identityParts -join "`0"))
    untracked = $untracked; skipped = @($skipped)
  }
}

# These are candidate paths from the canonical generated-artifacts contract,
# not a substitute for arbitrary DocsRoot/profile policy interpretation. _work is
# flagged for scoped inspection instead of treating every project's work as local.
function Test-DeliveryArtifact([string]$Path) {
  return $Path -cmatch '^(docs/governance/(reviews(?:/|$)|documentation\.json$|doc-index\.md$|\.documentation\.lock$|\.pending\.json$|(?:documentation\.json|doc-index\.md|\.pending\.json)\.[a-f0-9]{32}\.tmp$)|openspec/(\.team-recovery(?:/|$)|\.team-archive\.lock$))'
}

try {
  if ($Operation -notin @('Commit','Push','PullRequest','Merge','Release','Install') -or
      [string]::IsNullOrWhiteSpace($ProjectRoot) -or
      $RemoteName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$') { throw 'INPUT' }
  $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/','\')
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'INPUT' }
  if (-not (Test-DeliveryPlainPath $root)) { throw 'BOUNDARY' }
  $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $git) { throw 'DEPENDENCY' }
  $top = (Invoke-DeliveryGit @('rev-parse', '--show-toplevel')).text.Trim()
  if ([IO.Path]::GetFullPath($top).TrimEnd('/','\') -ne $root) { throw 'BOUNDARY' }
  # Missing objects in a partial/promisor clone may trigger implicit network fetch
  # and object writes. Older Git may ignore GIT_NO_LAZY_FETCH, so reject configured
  # partial clones before any object-reading command, even when objects are local.
  $partialKeys = Invoke-DeliveryGit @(
    'config', '--null', '--name-only', '--get-regexp',
    '^extensions\.partialclone$|^remote\..*\.promisor$'
  ) @(0,1)
  foreach ($key in $partialKeys.text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
    if ($key -ieq 'extensions.partialclone') { throw 'PARTIAL' }
    $enabled = Invoke-DeliveryGit @('config', '--type=bool', '--get-all', $key) @(0,1)
    if (@($enabled.text -split '\s+' | Where-Object { $_ -ieq 'true' }).Count) {
      throw 'PARTIAL'
    }
  }
  # Status/diff can run clean/process filters while inspecting worktree content.
  # Read only configuration key names, then neutralize every configured driver in
  # child argv. Never print or evaluate the corresponding command values.
  $filterKeys = Invoke-DeliveryGit @('config', '--name-only', '--get-regexp', '^filter\.') @(0,1)
  $script:filterConfiguration = @()
  foreach ($key in @($filterKeys.text -split "`n" | Where-Object { $_ })) {
    if ($key.Trim() -notmatch '^filter\.(.+)\.[^.]+$') { throw 'GIT' }
    $driver = $Matches[1]
    foreach ($setting in @('clean','smudge','process')) {
      $script:filterConfiguration += @('-c', "filter.$driver.$setting=")
    }
    $script:filterConfiguration += @('-c', "filter.$driver.required=false")
  }
  $before = Get-DeliverySnapshot
  foreach ($name in @('head','branch','indexIdentity','rawIndexSha256','workingTreeIdentity')) {
    $result.snapshot[$name] = $before[$name]
  }
  $result.snapshot.unborn = -not $before.head
  $result.snapshot.detached = -not $before.branch
  if ($BaseRef) { $result.snapshot.baseCommit = Resolve-DeliveryCommit $BaseRef }
  if ($TargetBranch) {
    if ($TargetBranch.StartsWith('-') -or $TargetBranch -match '[\s\x00-\x1f]') { throw 'REF' }
    $validBranch = Invoke-DeliveryGit @('check-ref-format', '--branch', $TargetBranch) @(0,128,1)
    if ($validBranch.code -ne 0) { throw 'REF' }
    $result.snapshot.targetCommit = Resolve-DeliveryCommit $TargetBranch
  }
  $result.changes.staged = Get-DeliveryPaths @('diff', '--cached', '--name-only', '-z', '--no-renames', '--no-ext-diff', '--no-textconv')
  $result.changes.unstaged = Get-DeliveryPaths @('diff', '--name-only', '-z', '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=all')
  $result.changes.untracked = $before.untracked
  $conflicts = Get-DeliveryPaths @('ls-files', '--unmerged', '-z')
  $conflictPaths = @($conflicts | ForEach-Object { ($_ -split "`t",2)[-1] } | Sort-Object -Unique)
  $result.checks.conflicts = @{ status = 'clean'; paths = $conflictPaths }
  if ($conflictPaths.Count) {
    $result.checks.conflicts.status = 'blocked'
    $findings.Add(@{ code = 'conflicts'; severity = 'blocking'; message = 'Resolve unmerged index entries.' })
  }
  if ($Operation -ne 'Commit' -and -not $before.head) { $decisions.Add('head-required') }
  if ($Operation -in @('Push','PullRequest','Merge','Release') -and -not $BaseRef) { $decisions.Add('base-required') }
  if ($Operation -in @('PullRequest','Merge','Release') -and -not $TargetBranch) { $decisions.Add('target-required') }
  if ($Operation -in @('PullRequest','Merge') -and $BaseRef -and $TargetBranch -and
      $result.snapshot.baseCommit -ne $result.snapshot.targetCommit) { $decisions.Add('target-base-mismatch') }
  # A release base is an independent previous-release boundary. Its target names
  # the intended source at HEAD, not the historical base or a guessed merge target.
  if ($Operation -eq 'Release' -and $TargetBranch -and $before.head -and
      $result.snapshot.targetCommit -ne $before.head) { $decisions.Add('release-target-head-mismatch') }
  if ($Operation -eq 'Commit' -and $result.changes.staged.Count -eq 0) { $decisions.Add('no-staged-changes') }
  if ($Operation -eq 'Install') {
    $result.inspectionRequired += 'Review the existing deployment manager exact package/source digest, preview and selected targets; Git-visible identity excludes ignored payload files and cannot bind installation approval. Do not execute installation.'
    if ($before.skipped.Count) { $decisions.Add('source-snapshot-incomplete'); $result.limits.incomplete = $true }
  }
  if ($before.skipped.Count) {
    $result.inspectionRequired += 'Untracked sensitive/dependency/linked/oversize content was not hashed; inspect relevant source separately.'
  }
  $scopeArguments = $null
  if ($Operation -eq 'Commit') {
    $scopeArguments = @('--cached')
    $result.checks.whitespace.scope = 'index'
  } elseif ($result.snapshot.baseCommit -and $before.head -and $decisions.Count -eq 0) {
    $rangeBase = $result.snapshot.baseCommit
    if ($Operation -in @('PullRequest','Merge')) {
      $mergeBaseData = Invoke-DeliveryGit @('merge-base', '--all', $rangeBase, $before.head) @(0,1)
      $mergeBases = @($mergeBaseData.text.Trim() -split '\s+' | Where-Object { $_ })
      if ($mergeBases.Count -ne 1) { $decisions.Add('merge-base-ambiguous') }
      else { $rangeBase = $mergeBases[0]; $result.snapshot.mergeBase = $rangeBase }
    }
    if ($decisions.Count -eq 0) {
      $scopeArguments = @($rangeBase, $before.head)
      $result.checks.whitespace.scope = 'outgoing'
      $result.changes.outgoing = Get-DeliveryPaths (@('diff','--name-only','-z','--no-renames','--no-ext-diff','--no-textconv') + $scopeArguments)
      $commitsData = Invoke-DeliveryGit @('rev-list', '--max-count=201', "$rangeBase..$($before.head)")
      $commits = @($commitsData.text -split '\s+' | Where-Object { $_ })
      if ($commits.Count -gt $maximumCommits) { throw 'LIMIT' }
      $intermediate = [Collections.Generic.List[object]]::new()
      $introducedArtifacts = [Collections.Generic.List[string]]::new()
      foreach ($commit in $commits) {
        $paths = Get-DeliveryPaths @('diff-tree', '--root', '-m', '--no-commit-id', '--name-only', '-r', '-z', '--no-renames', '--no-ext-diff', '--no-textconv', $commit)
        $intermediate.Add(@{ id = $commit; paths = $paths })
        # Deleted preexisting artifacts are legitimate cleanup. Inspect the entire
        # range's additions/modifications so add-then-delete still cannot escape.
        $introduced = Get-DeliveryPaths @('diff-tree', '--root', '-m', '--no-commit-id', '--name-only', '-r', '-z', '--no-renames', '--no-ext-diff', '--no-textconv', '--diff-filter=ACMRT', $commit)
        foreach ($path in $introduced) { $introducedArtifacts.Add($path) }
      }
      $result.changes.intermediateCommits = @($intermediate)
    }
  }
  if ($null -ne $scopeArguments) {
    $whitespace = Invoke-DeliveryGit (@('diff','--check','--no-ext-diff','--no-textconv') + $scopeArguments) @(0,2)
    $result.checks.whitespace.count = @($whitespace.text -split "`n" | Where-Object { $_ -match ':\d+:' }).Count
    $result.checks.whitespace.status = if ($whitespace.code -eq 0) { 'clean' } else { 'blocked' }
    if ($whitespace.code -ne 0) {
      $findings.Add(@{ code = 'whitespace'; severity = 'blocking'; message = 'Scoped Git whitespace check found violations; inspect locally.' })
    }
  }
  $indexPaths = @($before.entries.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries) |
    ForEach-Object { ($_ -split "`t",2)[-1] })
  $artifactCandidates = @($indexPaths)
  if ($null -ne $introducedArtifacts) { $artifactCandidates += @($introducedArtifacts) }
  $artifacts = @($artifactCandidates | Where-Object { Test-DeliveryArtifact $_ } | Sort-Object -Unique)
  $result.checks.generatedArtifacts = @{ status = 'clean'; paths = $artifacts }
  if ($artifacts.Count) {
    $result.checks.generatedArtifacts.status = 'blocked'
    $findings.Add(@{ code = 'generated-artifacts'; severity = 'blocking'; message = 'Canonical Kit local-artifact candidates occur in the index or outgoing history; inspect profile scope.' })
  }
  if (@($artifactCandidates | Where-Object { $_ -match '^_work/' }).Count) {
    $decisions.Add('work-artifact-scope')
  }
  $after = Get-DeliverySnapshot
  $fresh = $before.workingTreeIdentity -eq $after.workingTreeIdentity
  if ($BaseRef -and (Resolve-DeliveryCommit $BaseRef) -ne $result.snapshot.baseCommit) { $fresh = $false }
  if ($TargetBranch -and (Resolve-DeliveryCommit $TargetBranch) -ne $result.snapshot.targetCommit) { $fresh = $false }
  $result.checks.freshness = @{
    status = if ($fresh) { 'clean' } else { 'blocked' }
    before = $before.workingTreeIdentity; after = $after.workingTreeIdentity
  }
  if (-not $fresh) {
    $findings.Add(@{ code = 'snapshot-changed'; severity = 'blocking'; message = 'Relevant Git/source evidence changed during collection; rerun after writers stop.' })
  }
} catch {
  $code = $_.Exception.Message
  if ($code -eq 'LIMIT') {
    $result.limits.incomplete = $true
    $decisions.Add('resource-limit')
  } elseif ($code -eq 'PARTIAL') {
    $result.limits.incomplete = $true
    $decisions.Add('unsupported-partial-clone')
    $result.inspectionRequired += 'Partial/promisor repositories are unsupported without a separately prepared complete local object store; no fetch was attempted.'
  } else {
    if ($code -notin @('INPUT','REF','DEPENDENCY','BOUNDARY','GIT')) { $code = 'collection-failed' }
    $findings.Add(@{ code = $code.ToLowerInvariant(); severity = 'blocking'; message = 'Local evidence collection failed safely; verify inputs, repository access and supported Git state.' })
  }
}
$result.findings = @($findings)
$result.decisionRequired = @($decisions | Select-Object -Unique)
if ($findings.Count) { $result.status = 'blocked'; $exitCode = 1 }
elseif ($decisions.Count) { $result.status = 'needs-user-decision'; $exitCode = 2 }
else { $result.status = 'ready-for-review'; $exitCode = 0 }
$result | ConvertTo-Json -Depth 16
exit $exitCode
