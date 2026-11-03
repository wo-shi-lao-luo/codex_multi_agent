#requires -Version 7.0
<#
Inspect portable Agent-document source fingerprints without writing files or Git.
Exit 0 is mechanically fresh within the declared scope, never semantic approval;
1 reports changes/coverage gaps; 2 means unadopted, unsafe or incomplete evidence.
Sources and target documents are whole-file byte identities. Anchors are inert
human locators. Only the Lead's semantic assessment may authorize map advancement.
#>
[CmdletBinding()]
param(
  [string]$Action = 'Inspect',
  [string]$ProjectRoot,
  [string]$ManifestPath = 'docs/agent/sources.json'
)
$ErrorActionPreference = 'Stop'
$watch = [Diagnostics.Stopwatch]::StartNew()
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$script:hashedBytes = 0L
$script:capturedBytes = 0L
$script:filterArguments = @()
$script:observations = @{}
$script:identities = [Collections.Generic.Dictionary[string,string]]::new(
  [StringComparer]::OrdinalIgnoreCase
)
$result = [ordered]@{
  schemaVersion = 1
  status = 'unknown'
  manifestSha256 = $null
  documents = @()
  inventory = @{ added = @(); missing = @() }
  git = @{
    status = 'unknown'; baseline = $null; head = $null
    committed = @(); staged = @(); unstaged = @(); untracked = @()
  }
  coverage = @{
    scope = 'Mapped sources and bounded document inventory only. Git hints are net baseline-to-HEAD and current deltas; intermediate changes reverted before HEAD are not observed. Hashes do not establish semantic approval.'
    unmapped = @()
    gaps = @('The source map itself is excluded from freshness decisions.')
  }
  errors = @()
  limits = @{
    maxManifestBytes = 262144; maxDocuments = 512; maxSources = 4096
    maxInventoryFiles = 4096; maxFileBytes = 8388608; maxHashBytes = 67108864
    maxGitBytes = 4194304; maxGitPaths = 20000; timeoutSeconds = 60
    incomplete = $false
  }
}

function Assert-Time {
  if ($watch.Elapsed.TotalSeconds -ge 60) { throw 'limit' }
}

# Exclusions match the document runtime, with additional self-cycle and ephemeral
# boundaries. They apply even when a caller explicitly names the excluded file.
function Test-Excluded([string]$Relative) {
  # Formal governance documents remain eligible sources. Only the retained local
  # documentation-runtime bundle is excluded, independent of its parent root.
  if ($Relative -match '(^|/)governance/(reviews(/|$)|documentation\.json$|doc-index\.md$|\.documentation\.lock$|\.pending\.json$|(documentation\.json|doc-index\.md|\.pending\.json)\.[a-f0-9]{32}\.tmp$)') { return $true }
  foreach ($part in ($Relative -split '/')) {
    if ($part -match '^(\.git|\.codex|\.agents|\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|dist|build|coverage|\.next|\.cache|__pycache__|\.venv|venv|_work|_tmp|tmp|temp)$') { return $true }
    if ($part -match '^\.env($|\.)|^(\.npmrc|\.pypirc|\.netrc|id_rsa|id_ed25519|credentials|credentials\.(json|toml|ini|yaml|yml)|secrets\.(json|toml|ini|yaml|yml)|tokens\.json)$|\.(pem|key|pfx|p12|keystore|tmp)$') { return $true }
    if ($part -match '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock)$') { return $true }
  }
  return $false
}

# Keep portable spelling unique across sources, targets and inventory. Repeated
# references to one exact source across different documents are legitimate.
function Normalize-Path([string]$Relative) {
  Assert-Time
  $key = Normalize-TeamRelativePath $Relative
  if (Test-Excluded $key) { throw 'excluded-path' }
  if ($script:identities.ContainsKey($key)) {
    if ($script:identities[$key] -cne $key) { throw 'path-collision' }
  } else { $script:identities.Add($key, $key) }
  $null = Resolve-TeamContainedPath $root $key
  return $key
}

function Assert-Keys($Value, [string[]]$Required, [string[]]$Optional = @()) {
  if ($Value -isnot [Collections.IDictionary]) { throw 'invalid-schema' }
  foreach ($key in $Value.Keys) {
    if ($key -cnotin ($Required + $Optional)) { throw 'invalid-schema' }
  }
  foreach ($key in $Required) {
    if (-not $Value.Contains($key)) { throw 'invalid-schema' }
  }
}

function Assert-Array($Value) {
  if ($Value -isnot [array]) { throw 'invalid-schema' }
}

function Assert-Hash($Value) {
  if ($Value -isnot [string] -or $Value -cnotmatch '^[a-f0-9]{64}$') {
    throw 'invalid-hash'
  }
}

# JSON aliases and repeated properties must not disappear during conversion to
# PowerShell maps. Validate the original property stream before deserialization.
function Assert-JsonProperties($Element) {
  if ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($property in $Element.EnumerateObject()) {
      if (-not $names.Add($property.Name)) { throw 'duplicate-field' }
      Assert-JsonProperties $property.Value
    }
  } elseif ($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array) {
    foreach ($child in $Element.EnumerateArray()) { Assert-JsonProperties $child }
  }
}

# Absence is distinct from unreadable, linked and directory inputs. File reads
# have a byte cap before allocation and verify size again on the opened handle.
function Read-Fingerprint([string]$Relative, [int]$Maximum = 8388608) {
  Assert-Time
  $absolute = Resolve-TeamContainedPath $root $Relative
  try { $item = Get-Item -LiteralPath $absolute -Force -ErrorAction Stop }
  catch [System.Management.Automation.ItemNotFoundException] {
    return @{ exists = $false; sha256 = $null; kind = 'missing' }
  }
  if ($item.PSIsContainer) { return @{ exists = $true; sha256 = $null; kind = 'directory' } }
  if ($item.Length -gt $Maximum) { throw 'limit' }
  $stream = [IO.File]::Open($absolute, 'Open', 'Read', 'Read')
  try {
    if ($stream.Length -gt $Maximum -or
        $script:hashedBytes + $stream.Length -gt 64MB) { throw 'limit' }
    $memory = [IO.MemoryStream]::new()
    try {
      $buffer = [byte[]]::new(8192)
      while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        Assert-Time
        $script:hashedBytes += $count
        if ($memory.Length + $count -gt $Maximum -or
            $script:hashedBytes -gt 64MB) { throw 'limit' }
        $memory.Write($buffer, 0, $count)
      }
      $bytes = $memory.ToArray()
      return @{ exists = $true; sha256 = Get-TeamSha256Hex $bytes; kind = 'file'; bytes = $bytes }
    } finally { $memory.Dispose() }
  } finally { $stream.Dispose() }
}

function Observe([string]$Relative) {
  if (-not $script:observations.ContainsKey($Relative)) {
    try { $value = Read-Fingerprint $Relative }
    catch [System.IO.IOException] {
      $value = @{ exists = $null; sha256 = $null; kind = 'unreadable' }
    }
    catch [System.UnauthorizedAccessException] {
      $value = @{ exists = $null; sha256 = $null; kind = 'unreadable' }
    }
    $script:observations[$Relative] = @{
      exists = $value.exists; sha256 = $value.sha256; kind = $value.kind
    }
  }
  return $script:observations[$Relative]
}

# Only the selected document directory is walked. No repository-wide content
# discovery is attempted; excluded namespaces are neither opened nor traversed.
function Get-Inventory([string]$Relative) {
  $paths = [Collections.Generic.List[string]]::new()
  $visited = 0
  $pending = [Collections.Generic.Stack[string]]::new()
  $pending.Push($Relative)
  while ($pending.Count) {
    Assert-Time
    $current = Normalize-Path $pending.Pop()
    $absolute = Resolve-TeamContainedPath $root $current
    try { $item = Get-Item -LiteralPath $absolute -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { continue }
    if (-not $item.PSIsContainer) { throw 'not-directory' }
    foreach ($child in Get-ChildItem -LiteralPath $absolute -Force -ErrorAction Stop) {
      $visited++
      if ($visited -gt 8192) { throw 'limit' }
      $path = "$current/$($child.Name)"
      if (Test-Excluded $path) { continue }
      $path = Normalize-Path $path
      if ($path -ceq $manifestRelative) { continue }
      if ($child.PSIsContainer) { $pending.Push($path) }
      else {
        $paths.Add($path)
        if ($paths.Count -gt 4096) { throw 'limit' }
      }
    }
  }
  $paths.Sort([StringComparer]::Ordinal)
  return ,$paths.ToArray()
}

# Run fixed read-only Git builtins as literal argv; suppress inherited Git state,
# hooks, external diffs, clean/process filters, locks, lazy fetch and raw stderr.
# Drain both pipes concurrently under one aggregate byte/time budget.
function Invoke-Git([string[]]$Arguments, [int[]]$Allowed = @(0)) {
  Assert-Time
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
    '-c', 'diff.autoRefreshIndex=false', '-c', 'core.hooksPath=/dev/null',
    '-c', 'diff.external=', '-c', 'core.excludesFile=/dev/null',
    '-c', 'submodule.recurse=false', '-c', "safe.directory=$($root.Replace('\','/'))"
  )
  foreach ($argument in $configuration + $script:filterArguments + $Arguments) {
    $info.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  $memory = [IO.MemoryStream]::new()
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $outBuffer = [byte[]]::new(8192)
    $errBuffer = [byte[]]::new(8192)
    $outTask = $process.StandardOutput.BaseStream.ReadAsync($outBuffer, 0, 8192)
    $errTask = $process.StandardError.BaseStream.ReadAsync($errBuffer, 0, 8192)
    $outDone = $false
    $errDone = $false
    while (-not ($outDone -and $errDone)) {
      Assert-Time
      if (-not $outDone -and $outTask.IsCompleted) {
        $count = $outTask.GetAwaiter().GetResult()
        $script:capturedBytes += $count
        if ($count -eq 0) { $outDone = $true }
        else {
          $memory.Write($outBuffer, 0, $count)
          $outTask = $process.StandardOutput.BaseStream.ReadAsync($outBuffer, 0, 8192)
        }
      }
      if (-not $errDone -and $errTask.IsCompleted) {
        $count = $errTask.GetAwaiter().GetResult()
        $script:capturedBytes += $count
        if ($count -eq 0) { $errDone = $true }
        else { $errTask = $process.StandardError.BaseStream.ReadAsync($errBuffer, 0, 8192) }
      }
      if ($script:capturedBytes -gt 4MB) { throw 'limit' }
      [Threading.Thread]::Sleep(2)
    }
    if (-not $process.WaitForExit(1000)) { throw 'limit' }
    if ($process.ExitCode -notin $Allowed) { throw 'git-failed' }
    return @{ code = $process.ExitCode; text = $utf8.GetString($memory.ToArray()) }
  } finally {
    if ($process.Id -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    $process.Dispose()
    $memory.Dispose()
  }
}

function Get-GitPaths([string[]]$Arguments) {
  $data = Invoke-Git $Arguments
  $paths = @($data.text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
  if ($paths.Count -gt 20000) { throw 'limit' }
  $safe = [Collections.Generic.List[string]]::new()
  foreach ($path in $paths) {
    if (Test-Excluded $path) {
      $result.coverage.gaps += 'Excluded Git path hints were omitted; their relevance needs scoped assessment.'
      continue
    }
    $safe.Add((Normalize-Path $path))
  }
  $safe.Sort([StringComparer]::Ordinal)
  return ,$safe.ToArray()
}

# Gitlink entries describe a separate repository, whose worktree and metadata
# are outside this collector's evidence. Inspect only the parent index/tree
# records; do not enter submodules or let diff invoke their Git configuration.
function Assert-NoGitlinks([string[]]$Arguments) {
  $data = Invoke-Git $Arguments
  $entries = @($data.text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
  if ($entries.Count -gt 20000) { throw 'limit' }
  foreach ($entry in $entries) {
    Assert-Time
    if ($entry.StartsWith('160000 ', [StringComparison]::Ordinal)) {
      throw 'git-submodule'
    }
  }
}

# Partial/promisor configuration is inspected before commands that read objects.
# Without a usable ancestor baseline, retain file evidence but require explicit
# scoped snapshot reassessment rather than pretending repository history is known.
function Get-GitSnapshot {
  # Reject linked metadata before even probing Git. A plain .git file is valid
  # for ordinary worktrees; Git may resolve its separate plain metadata directory.
  Assert-TeamPlainPath (Join-Path $root '.git')
  foreach ($name in @('config','HEAD','index')) {
    if (Test-Path -LiteralPath (Join-Path $root '.git') -PathType Container) {
      Assert-TeamPlainPath (Join-Path $root ".git/$name")
    }
  }
  $top = Invoke-Git @('rev-parse', '--show-toplevel') @(0,128)
  if ($top.code -ne 0) { throw 'git-unavailable' }
  if (-not [string]::Equals((Get-TeamCanonicalRoot $top.text.Trim()), $root,
      (Get-TeamPathComparison))) { throw 'git-boundary' }
  $metadata = Invoke-Git @('rev-parse', '--absolute-git-dir')
  $gitDirectory = Get-TeamCanonicalRoot $metadata.text.Trim()
  foreach ($name in @('config','HEAD','index','objects','refs','packed-refs','commondir')) {
    Assert-TeamPlainPath (Join-Path $gitDirectory $name)
  }
  $partial = Invoke-Git @('config', '--null', '--name-only', '--get-regexp',
    '^extensions\.partialclone$|^remote\..*\.promisor$') @(0,1)
  foreach ($key in $partial.text.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
    if ($key -ieq 'extensions.partialclone') { throw 'git-partial' }
    $enabled = Invoke-Git @('config', '--type=bool', '--get-all', $key) @(0,1)
    if (@($enabled.text -split '\s+' | Where-Object { $_ -ieq 'true' }).Count) {
      throw 'git-partial'
    }
  }
  $filters = Invoke-Git @('config', '--name-only', '--get-regexp', '^filter\.') @(0,1)
  $script:filterArguments = @()
  foreach ($key in @($filters.text -split "`n" | Where-Object { $_ })) {
    if ($key.Trim() -notmatch '^filter\.(.+)\.[^.]+$') { throw 'git-failed' }
    $driver = $Matches[1]
    foreach ($setting in @('clean','smudge','process')) {
      $script:filterArguments += @('-c', "filter.$driver.$setting=")
    }
    $script:filterArguments += @('-c', "filter.$driver.required=false")
  }
  $head = Invoke-Git @('rev-parse', '--verify', 'HEAD^{commit}') @(0,128)
  $snapshot = @{
    status = 'baseline-unknown'; baseline = $manifest.gitBaseline
    head = if ($head.code -eq 0) { $head.text.Trim() } else { $null }
    committed = @(); staged = @(); unstaged = @(); untracked = @()
  }
  $baseCommit = $null
  if ($manifest.gitBaseline -and $snapshot.head) {
    $base = Invoke-Git @('rev-parse', '--verify', "$($manifest.gitBaseline)^{commit}") @(0,128)
    if ($base.code -eq 0) {
      $ancestor = Invoke-Git @('merge-base', '--is-ancestor', $base.text.Trim(), $snapshot.head) @(0,1,128)
      if ($ancestor.code -eq 0) {
        $snapshot.status = 'available'
        $baseCommit = $base.text.Trim()
      }
    }
  }
  # Check all relevant parent snapshots before diff: an index-only addition,
  # staged deletion still present in HEAD, or historical baseline-only gitlink
  # must each make coverage incomplete. ls-tree -r does not recurse into gitlinks.
  Assert-NoGitlinks @('ls-files', '--stage', '-z')
  if ($snapshot.head) {
    Assert-NoGitlinks @('ls-tree', '-r', '-z', '--full-tree', $snapshot.head)
  }
  if ($baseCommit -and $baseCommit -cne $snapshot.head) {
    Assert-NoGitlinks @('ls-tree', '-r', '-z', '--full-tree', $baseCommit)
  }
  $snapshot.staged = Get-GitPaths @('diff', '--cached', '--name-only', '-z',
    '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=all')
  $snapshot.unstaged = Get-GitPaths @('diff', '--name-only', '-z',
    '--no-renames', '--no-ext-diff', '--no-textconv', '--ignore-submodules=all')
  $snapshot.untracked = Get-GitPaths @('ls-files', '--others', '--exclude-standard', '-z')
  if ($baseCommit) {
    $snapshot.committed = Get-GitPaths @('diff', '--name-only', '-z', '--no-renames',
      '--no-ext-diff', '--no-textconv', '--ignore-submodules=all',
      $baseCommit, $snapshot.head, '--')
  }
  return $snapshot
}

# Stable JSON key order makes repeated evidence comparable without treating field
# insertion order as meaningful. Array order remains the authored/ordinal order.
function ConvertTo-StableValue($Value) {
  if ($Value -is [Collections.IDictionary]) {
    $ordered = [ordered]@{}
    $keys = [Collections.Generic.List[string]]::new()
    foreach ($key in $Value.Keys) { $keys.Add($key) }
    $keys.Sort([StringComparer]::Ordinal)
    foreach ($key in $keys) { $ordered[$key] = ConvertTo-StableValue $Value[$key] }
    return $ordered
  }
  if ($Value -is [array]) {
    $items = foreach ($item in $Value) { ConvertTo-StableValue $item }
    return ,@($items)
  }
  return $Value
}

try {
  . (Join-Path $PSScriptRoot 'platform-filesystem.ps1')
  if ($Action -cne 'Inspect' -or [string]::IsNullOrWhiteSpace($ProjectRoot)) { throw 'invalid-input' }
  $root = Get-TeamCanonicalRoot $ProjectRoot
  $manifestRelative = Normalize-Path $ManifestPath
  $map = Read-Fingerprint $manifestRelative 262144
  $result.manifestSha256 = $map.sha256
  if (-not $map.exists) {
    $result.status = 'unadopted'
    $result.coverage.gaps += 'Author a scoped source map after semantic source assessment; no map was created.'
  } else {
    if ($map.kind -ne 'file') { throw 'not-file' }
    $text = $utf8.GetString($map.bytes)
    $options = [Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = 16
    $json = [Text.Json.JsonDocument]::Parse($text, $options)
    try { Assert-JsonProperties $json.RootElement } finally { $json.Dispose() }
    $manifest = $text | ConvertFrom-Json -AsHashtable -Depth 16
    Assert-Keys $manifest @('schemaVersion','documentsRoot','gitBaseline','documents')
    if ($manifest.schemaVersion -isnot [long] -and $manifest.schemaVersion -isnot [int] -or
        $manifest.schemaVersion -ne 1) { throw 'invalid-schema' }
    if ($manifest.documentsRoot -isnot [string]) { throw 'invalid-schema' }
    $documentsRoot = Normalize-Path $manifest.documentsRoot
    if ($manifest.gitBaseline -isnot [string] -and $null -ne $manifest.gitBaseline -or
        $null -ne $manifest.gitBaseline -and $manifest.gitBaseline -cnotmatch '^([a-f0-9]{40}|[a-f0-9]{64})$') { throw 'invalid-baseline' }
    Assert-Array $manifest.documents
    if ($manifest.documents.Count -gt 512) { throw 'limit' }
    $targets = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $mapped = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $sourceCount = 0
    foreach ($document in $manifest.documents) {
      Assert-Keys $document @('path','documentSha256','sources')
      if ($document.path -isnot [string]) { throw 'invalid-schema' }
      $path = Normalize-Path $document.path
      if (-not $path.StartsWith("$documentsRoot/", [StringComparison]::Ordinal) -or
          $path -ceq $manifestRelative -or -not $targets.Add($path)) { throw 'invalid-target' }
      $null = $mapped.Add($path)
      $document.path = $path
      Assert-Hash $document.documentSha256
      Assert-Array $document.sources
    }
    foreach ($document in $manifest.documents) {
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($source in $document.sources) {
        $sourceCount++
        if ($sourceCount -gt 4096) { throw 'limit' }
        Assert-Keys $source @('path','exists','sha256') @('anchor')
        if ($source.path -isnot [string]) { throw 'invalid-schema' }
        $path = Normalize-Path $source.path
        if ($path -ceq $manifestRelative -or $targets.Contains($path) -or
            -not $seen.Add($path)) { throw 'source-cycle-or-duplicate' }
        if ($source.exists -isnot [bool]) { throw 'invalid-schema' }
        if ($source.exists) { Assert-Hash $source.sha256 }
        elseif ($null -ne $source.sha256) { throw 'invalid-absence' }
        if ($null -ne $source.anchor -and ($source.anchor -isnot [string] -or
            $source.anchor.Length -gt 256 -or $source.anchor -match '[\x00-\x1f]')) { throw 'invalid-anchor' }
        $null = $mapped.Add($path)
        $source.path = $path
      }
    }
    $inventory = Get-Inventory $documentsRoot
    foreach ($path in $inventory) { $null = Observe $path }
    $result.inventory.added = @($inventory | Where-Object { -not $targets.Contains($_) })
    $unknown = $false
    $changed = $result.inventory.added.Count -gt 0
    foreach ($document in $manifest.documents) {
      $current = Observe $document.path
      $row = @{
        path = $document.path; status = 'fresh'
        exists = $current.exists; sha256 = $current.sha256
        expectedSha256 = $document.documentSha256
        documentChanged = (-not $current.exists -or $current.sha256 -cne $document.documentSha256)
        sources = @()
      }
      if ($current.kind -notin @('file','missing')) {
        $row.status = 'unknown'; $unknown = $true
        $row.documentChanged = $null
        $result.errors += "document-$($current.kind)"
      }
      if (-not $document.sources.Count) { $row.status = 'unknown'; $unknown = $true }
      foreach ($source in $document.sources) {
        $actual = Observe $source.path
        $different = $source.exists -ne $actual.exists -or $source.sha256 -cne $actual.sha256
        $sourceStatus = if ($different) { 'changed' } else { 'fresh' }
        if ($actual.kind -notin @('file','missing')) {
          $sourceStatus = 'unknown'; $row.status = 'unknown'; $unknown = $true
          $result.errors += "source-$($actual.kind)"
        }
        $row.sources += @{
          path = $source.path; expectedExists = $source.exists; exists = $actual.exists
          expectedSha256 = $source.sha256
          sha256 = $actual.sha256; status = $sourceStatus
        }
        if ($different) { $changed = $true; if ($row.status -ne 'unknown') { $row.status = 'changed' } }
      }
      if ($row.documentChanged) {
        $changed = $true
        if ($row.status -ne 'unknown') { $row.status = 'changed' }
      }
      if ($current.kind -eq 'missing') {
        $row.status = 'missing'
        $result.inventory.missing += $document.path
      }
      $result.documents += $row
    }
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git) {
      try { $result.git = Get-GitSnapshot }
      catch {
        $code = $_.Exception.Message
        $result.git.status = if ($code -eq 'git-partial') { 'partial' }
          elseif ($code -eq 'git-unavailable') { 'unavailable' }
          else { 'unknown' }
        if ($code -eq 'limit') { throw 'limit' }
        if ($code -eq 'git-submodule') {
          $result.errors += 'git-submodule'
          $result.coverage.gaps += 'Submodule working trees are uninspected; perform scoped reassessment.'
        } else { $result.errors += 'git-incomplete' }
      }
    } else { $result.git.status = 'unavailable' }
    if ($result.git.status -ne 'available') {
      $unknown = $true
      $result.coverage.gaps += 'Git history is incomplete; reassess the scoped snapshot and relevant source coverage.'
    }
    $unmapped = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $hints = @($result.git.committed) + @($result.git.staged) +
      @($result.git.unstaged) + @($result.git.untracked)
    foreach ($path in $hints) {
      if ($path -cne $manifestRelative -and -not $mapped.Contains($path)) { $null = $unmapped.Add($path) }
    }
    $result.coverage.unmapped = @($unmapped)
    if ($unmapped.Count) {
      $changed = $true
      $result.coverage.gaps += 'Unmapped changed paths require a relevance and source-coverage assessment.'
    }
    if ($result.coverage.gaps -contains 'Excluded Git path hints were omitted; their relevance needs scoped assessment.') {
      $unknown = $true
    }
    if ($unknown) {
      $result.limits.incomplete = $true
      $result.coverage.gaps += 'Missing source coverage or unavailable evidence cannot certify readiness.'
    }
    # Recheck the inspected evidence immediately before reporting. This detects
    # ordinary concurrent changes, but does not establish an owner lock or sandbox.
    $latestMap = Read-Fingerprint $manifestRelative 262144
    if ($map.sha256 -cne $latestMap.sha256) { throw 'concurrent-change' }
    if (($inventory -join "`0") -cne ((Get-Inventory $documentsRoot) -join "`0")) { throw 'concurrent-change' }
    foreach ($path in @($script:observations.Keys)) {
      $before = $script:observations[$path]
      if ($before.kind -eq 'unreadable') { continue }
      $latest = Read-Fingerprint $path
      if ($before.exists -ne $latest.exists -or $before.sha256 -cne $latest.sha256) { throw 'concurrent-change' }
    }
    if ($result.git.status -eq 'available') {
      $latestGit = Get-GitSnapshot
      foreach ($key in @('status','baseline','head','committed','staged','unstaged','untracked')) {
        if ((@($result.git[$key]) -join "`0") -cne (@($latestGit[$key]) -join "`0")) { throw 'concurrent-change' }
      }
    }
    $result.status = if (-not $manifest.documents.Count) { 'unadopted' }
      elseif ($unknown) { 'unknown' }
      elseif ($changed) { 'changed' }
      else { 'fresh' }
  }
} catch {
  # Never echo exception text: filesystem and Git failures may include private
  # absolute paths, configuration values or source text. Codes are fixed tokens.
  $code = $_.Exception.Message
  $safeCodes = @('limit','invalid-input','invalid-schema','invalid-hash','duplicate-field',
    'excluded-path','path-collision','not-file','not-directory','invalid-baseline',
    'invalid-target','source-cycle-or-duplicate','invalid-absence','invalid-anchor',
    'concurrent-change')
  $result.errors += if ($code -cin $safeCodes) { $code } else { 'inspection-failed' }
  $result.status = 'unknown'
  $result.limits.incomplete = $true
  $result.coverage.gaps += 'Inspection is incomplete; correct the reported boundary and reassess scoped evidence.'
}
$result.coverage.gaps = @($result.coverage.gaps | Select-Object -Unique)
$output = ConvertTo-StableValue $result | ConvertTo-Json -Depth 16 -Compress
if ([Text.Encoding]::UTF8.GetByteCount($output) -gt 4MB) {
  $result.status = 'unknown'
  $result.documents = @()
  $result.git.committed = @(); $result.git.staged = @()
  $result.git.unstaged = @(); $result.git.untracked = @()
  $result.inventory = @{ added = @(); missing = @() }
  $result.coverage.unmapped = @()
  $result.errors = @('output-limit')
  $result.limits.incomplete = $true
  $output = ConvertTo-StableValue $result | ConvertTo-Json -Depth 16 -Compress
}
Write-Output $output
if ($result.status -eq 'fresh') { exit 0 }
if ($result.status -eq 'changed') { exit 1 }
exit 2
