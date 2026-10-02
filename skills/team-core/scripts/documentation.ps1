#requires -Version 7.0
<#[Documentation lifecycle]
This runtime verifies authored evidence and its freshness. It cannot establish business
intent, authenticate user approval, or prove that a document was actually read. The Lead
must choose sufficient sources and resolve semantic questions before submitting a review.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Initialize','Scan','Status','RecordReview','Validate')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRoot,
  [string]$DocsRoot = 'docs',
  [string[]]$AdditionalPaths = @(),
  [string]$ReviewInput,
  [string]$Scope,
  [string]$Task,
  [string]$WorkItem
)
$ErrorActionPreference = 'Stop'
$policyVersion = 1
$kitVersion = '0.9.2'
$categories = @('requirements','architecture','interfaces-data','ui-ux','runtime','testing-acceptance','security-migration')
$root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/','\')
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'PATH: ProjectRoot must be an existing directory.' }

# Every filesystem operation uses a normalized repository-relative path and rejects
# linked ancestors. Even an explicitly supplied path cannot opt into secrets or builds.
function Assert-Plain([string]$Path) {
  $cursor = $Path
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'PATH: Linked paths are unsupported.' }
    }
    $next = Split-Path -Parent $cursor
    if ($next -eq $cursor) { break }; $cursor = $next
  }
}
function Test-Excluded([string]$Relative) {
  foreach ($part in ($Relative -split '/')) {
    if ($part -match '^(\.git|\.codex|\.agents|\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|dist|build|coverage|\.next|\.cache|__pycache__|\.venv|venv)$') { return $true }
    if ($part -match '^\.env($|\.)|^(\.npmrc|\.pypirc|\.netrc|id_rsa|id_ed25519|credentials|credentials\.(json|toml|ini|yaml|yml)|secrets\.(json|toml|ini|yaml|yml)|tokens\.json)$|\.(pem|key|pfx|p12|keystore)$') { return $true }
    if ($part -match '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock)$') { return $true }
  }
  return $false
}
function Normalize-Path([string]$Relative) {
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw 'PATH: Require a repository-relative path.' }
  $normalized = $Relative.Replace('\','/')
  foreach ($part in ($normalized -split '/')) {
    if ($part -in @('','.','..') -or $part -match '[<>:"|?*\x00-\x1f]' -or $part -match '[ .]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw 'PATH: Unsafe path segment.' }
  }
  if (Test-Excluded $normalized) { throw 'PATH: Credentials, dependencies and generated locations are excluded.' }
  return $normalized
}
function Resolve-Project([string]$Relative) {
  $normalized = Normalize-Path $Relative
  $absolute = [IO.Path]::GetFullPath((Join-Path $root $normalized))
  $prefix = $root + [IO.Path]::DirectorySeparatorChar
  if (-not $absolute.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Path leaves ProjectRoot.' }
  Assert-Plain $absolute
  return $absolute
}
Assert-Plain $root
$DocsRoot = Normalize-Path $DocsRoot
$governance = "$DocsRoot/governance"
$stateRelative = "$governance/documentation.json"
$indexRelative = "$governance/doc-index.md"
$statePath = Resolve-Project $stateRelative
$indexPath = Resolve-Project $indexRelative
$pendingPath = Resolve-Project "$governance/.pending.json"
$lock = $null

function Get-Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-TextHash([string]$Text) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
# Sort keys recursively to make structured fingerprints independent of JSON property order.
function Canonical($Value) {
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [Collections.IDictionary]) {
    $parts = @($Value.Keys | Sort-Object | ForEach-Object { (ConvertTo-Json ([string]$_) -Compress) + ':' + (Canonical $Value[$_]) })
    return '{' + ($parts -join ',') + '}'
  }
  if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) { return '[' + (@($Value | ForEach-Object { Canonical $_ }) -join ',') + ']' }
  return ConvertTo-Json $Value -Compress -Depth 50
}
function Fingerprint($Value) { return Get-TextHash (Canonical $Value) }
function Read-Json([string]$Path,[string]$Label) {
  try { $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 60 }
  catch { throw "$Label`: Invalid JSON." }
  if ($value -isnot [Collections.IDictionary]) { throw "$Label`: Require a JSON object." }
  return $value
}
function Assert-String($Value,[string]$Label) { if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { throw "REVIEW: Require nonempty $Label." } }
function Assert-Array($Value,[string]$Label) { if ($null -eq $Value -or $Value -is [string] -or $Value -is [Collections.IDictionary] -or $Value -isnot [Collections.IEnumerable]) { throw "REVIEW: Require array $Label." } }
function Assert-Scope([string]$Value) { if ($Value -notmatch '^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$' -or $Value.Length -gt 80) { throw 'REVIEW: Scope must be a bounded lowercase slug.' } }
function Assert-Hash($Value,[string]$Label) { if ($Value -isnot [string] -or $Value -notmatch '^[a-f0-9]{64}$') { throw "$Label`: Invalid SHA256." } }
function Read-State {
  if (Test-Path -LiteralPath $pendingPath) { throw 'STATE: Incomplete documentation transaction requires inspecting preserved pending evidence.' }
  if (-not (Test-Path -LiteralPath $statePath)) { return $null }
  $state = Read-Json $statePath 'STATE'
  if ($state.schemaVersion -ne 1 -or $state.policyVersion -isnot [long] -and $state.policyVersion -isnot [int] -or $state.policyVersion -lt 0 -or $state.policyVersion -gt $policyVersion) { throw 'STATE: Unsupported schema or future policy; explicit migration is required.' }
  if ($state.docsRoot -cne $DocsRoot -or $state.indexPath -cne $indexRelative) { throw 'STATE: Documentation root/index identity mismatch.' }
  if ($state.reviews -isnot [Collections.IDictionary]) { throw 'STATE: Missing review registry.' }
  Assert-Array $state.inventory 'inventory'; Assert-Array $state.additionalPaths 'additionalPaths'
  foreach ($path in $state.additionalPaths) { $null = Resolve-Project $path }
  $seen = @{}
  foreach ($doc in $state.inventory) {
    if ($doc -isnot [Collections.IDictionary]) { throw 'STATE: Invalid inventory.' }
    $key = Normalize-Path $doc.path; $null = Resolve-Project $key
    if ($seen.ContainsKey($key)) { throw 'STATE: Duplicate inventory path.' }; $seen[$key]=$true
    Assert-Hash $doc.sha256 'STATE'
  }
  Assert-Hash $state.indexSha256 'STATE'
  foreach ($id in $state.reviews.Keys) {
    Assert-Scope $id; $entry=$state.reviews[$id]
    if ($entry -isnot [Collections.IDictionary] -or $entry.recordPath -cne "$governance/reviews/$id.json" -or $entry.reportPath -cne "$governance/reviews/$id.md") { throw 'REVIEW: Current review paths must match their governed scope.' }
    $null=Resolve-Project $entry.recordPath; $null=Resolve-Project $entry.reportPath
    Assert-Hash $entry.recordSha256 'REVIEW'; Assert-Hash $entry.reportSha256 'REVIEW'
  }
  return $state
}
function Get-Inventory($State) {
  $paths=[Collections.Generic.List[string]]::new(); $observed=@{}
  function Visit([string]$Relative) {
    if ($Relative -eq $governance -or $Relative.StartsWith("$governance/",[StringComparison]::OrdinalIgnoreCase)) { return }
    if (Test-Excluded $Relative) { return }
    $absolute=Resolve-Project $Relative
    if (-not (Test-Path -LiteralPath $absolute)) { return }
    $item=Get-Item -LiteralPath $absolute -Force
    if ($item.PSIsContainer) {
      foreach ($child in @(Get-ChildItem -LiteralPath $absolute -Force | Sort-Object Name)) { Visit "$Relative/$($child.Name)" }
    } elseif (-not $observed.ContainsKey($Relative)) { $observed[$Relative]=$true; $paths.Add($Relative) }
  }
  Visit $DocsRoot
  foreach ($path in @('README.md','AGENTS.md')) { Visit $path }
  $extras = if ($null -ne $State) { @($State.additionalPaths) } else { @($AdditionalPaths) }
  foreach ($path in $extras) { $normalized=Normalize-Path $path; Visit $normalized }
  return @($paths | Sort-Object | ForEach-Object {
    $path=Resolve-Project $_
    @{path=$_;sha256=Get-Hash $path;kind=if ([IO.Path]::GetExtension($path) -match '^\.(md|mdx|txt|rst|json|yaml|yml|toml|xml|html|csv)$') {'text'} else {'attachment'}}
  })
}
function Get-Delta($State,$Inventory) {
  $old=@{}; if ($null -ne $State) { foreach ($doc in $State.inventory) { $old[$doc.path]=$doc.sha256 } }
  $now=@{}; foreach ($doc in $Inventory) { $now[$doc.path]=$doc.sha256 }
  return @{added=@($now.Keys | Where-Object { -not $old.ContainsKey($_) } | Sort-Object);changed=@($now.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $now[$_] } | Sort-Object);removed=@($old.Keys | Where-Object { -not $now.ContainsKey($_) } | Sort-Object)}
}
function Get-Dependencies($Paths,[switch]$ForFreshness) {
  $seen=@{}; $result=@()
  foreach ($path in $Paths) {
    $key=Normalize-Path $path; $absolute=Resolve-Project $key
    if ($key -eq $governance -or $key.StartsWith("$governance/",[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Governance records cannot be their own dependencies.' }
    if ($seen.ContainsKey($key)) { throw 'REVIEW: Duplicate dependency.' }; $seen[$key]=$true
    if (Test-Path -LiteralPath $absolute -PathType Container) {
      if (-not $ForFreshness) { throw 'REVIEW: Dependencies must name files, including expected absent files.' }
      $result+=@{path=$key;exists=$true;sha256=$null;kind='directory'}
      continue
    }
    $exists=Test-Path -LiteralPath $absolute -PathType Leaf
    $result+=@{path=$key;exists=[bool]$exists;sha256=if ($exists) { Get-Hash $absolute } else { $null }}
  }
  return @($result | Sort-Object { $_.path })
}
# Structural constraints never convert an agent's inference into a confirmed decision.
function Assert-Assessment($Review,$Inventory) {
  if ($Review.schemaVersion -ne 1) { throw 'REVIEW: Unsupported input schema.' }
  Assert-Scope $Review.scope
  foreach ($name in @('task','summary','report')) { Assert-String $Review[$name] $name }
  if ($Review.outcome -notin @('ready','partial','blocked')) { throw 'REVIEW: Unsupported outcome.' }
  foreach ($name in @('documents','dependencies','evidence','findings','runnableWork','coverage')) { Assert-Array $Review[$name] $name }
  if (@($Review.evidence).Count -eq 0) { throw 'REVIEW: Inspected/confirmed evidence is required.' }
  foreach ($value in $Review.evidence) { Assert-String $value 'evidence' }
  $known=@{}; foreach ($doc in $Inventory) { $known[$doc.path]=$true }
  $classified=@{}; $unavailable=[Collections.Generic.List[string]]::new()
  foreach ($doc in $Review.documents) {
    if ($doc -isnot [Collections.IDictionary]) { throw 'REVIEW: Invalid document classification.' }
    $key=Normalize-Path $doc.path
    if (-not $known.ContainsKey($key) -or $classified.ContainsKey($key)) { throw 'REVIEW: Classification must match inventory exactly once.' }
    $classified[$key]=$true
    if ($doc.category -notin ($categories + @('reference')) -or $doc.lifecycle -notin @('active','draft','reference','historical') -or $doc.authority -notin @('prd','supporting','reference') -or $doc.disposition -notin @('read','unrelated','historical','unavailable')) { throw 'REVIEW: Unsupported classification.' }
    Assert-String $doc.reason 'classification reason'
    $applicability=if ($doc.Contains('applicability')) { $doc.applicability } elseif ($doc.disposition -eq 'unrelated') { 'unrelated' } else { 'applicable' }
    if ($applicability -notin @('applicable','unrelated')) { throw 'REVIEW: Unsupported document applicability.' }
    if ($key.StartsWith("$DocsRoot/legacy/",[StringComparison]::OrdinalIgnoreCase) -and ($doc.lifecycle -ne 'historical' -or $doc.disposition -ne 'historical' -or $doc.authority -eq 'prd')) { throw 'REVIEW: Legacy material cannot claim current authority.' }
    if ($doc.authority -eq 'prd' -and ($doc.lifecycle -ne 'active' -or $doc.disposition -ne 'read' -or $applicability -ne 'applicable')) { throw 'READINESS: Applicable PRD authority must be active and read.' }
    if ($doc.lifecycle -eq 'historical' -and $doc.authority -eq 'prd') { throw 'REVIEW: Historical material cannot be current PRD authority.' }
    if ($doc.disposition -eq 'unavailable' -and $applicability -eq 'applicable') {
      if ($Review.outcome -eq 'ready') { throw 'READINESS: Ready cannot include unavailable applicable sources.' }
      $unavailable.Add($key)
    }
  }
  if ($classified.Count -ne $known.Count) { throw 'REVIEW: Every inventoried document needs a classification.' }
  $covered=@{}
  foreach ($item in $Review.coverage) {
    if ($item -isnot [Collections.IDictionary] -or $item.category -notin $categories -or $covered.ContainsKey($item.category) -or $item.decision -notin @('required','conditional','not applicable')) { throw 'REVIEW: Invalid coverage decision.' }
    $covered[$item.category]=$true; Assert-String $item.reason 'coverage reason'; Assert-Array $item.evidence 'coverage evidence'
    if (@($item.evidence).Count -eq 0) { throw 'REVIEW: Coverage decisions need evidence.' }
    foreach ($value in $item.evidence) { Assert-String $value 'coverage evidence' }
  }
  if ($covered.Count -ne $categories.Count) { throw 'REVIEW: All seven information dimensions need decisions.' }
  $runnable=@{}; foreach ($id in $Review.runnableWork) { Assert-String $id 'work ID'; if ($runnable.ContainsKey($id)) { throw 'REVIEW: Duplicate runnable work.' }; $runnable[$id]=$true }
  $blocked=@{}; $findingIds=@{}
  foreach ($finding in $Review.findings) {
    if ($finding -isnot [Collections.IDictionary]) { throw 'REVIEW: Invalid finding.' }
    Assert-String $finding.id 'finding ID'
    if ($findingIds.ContainsKey($finding.id)) { throw 'REVIEW: Duplicate finding ID.' }; $findingIds[$finding.id]=$true
    if ($finding.kind -notin @('ambiguous','conflict','missing','unavailable') -or $finding.severity -notin @('blocking','nonblocking') -or $finding.resolution -isnot [Collections.IDictionary] -or $finding.resolution.state -notin @('pending','resolved')) { throw 'REVIEW: Invalid finding decision.' }
    Assert-Array $finding.affectedWork 'affected work'; Assert-Array $finding.evidence 'finding evidence'
    if (@($finding.affectedWork).Count -eq 0 -or @($finding.evidence).Count -eq 0) { throw 'REVIEW: Findings need affected work and concrete source evidence.' }
    foreach ($value in $finding.evidence) { Assert-String $value 'finding evidence' }
    foreach ($value in $finding.affectedWork) { Assert-String $value 'affected work' }
    Assert-String $finding.recommendation 'finding recommendation'
    if ($finding.kind -in @('ambiguous','conflict')) {
      Assert-String $finding.question 'user question'
      if ($finding.severity -ne 'blocking') { throw 'READINESS: Ambiguity/conflict cannot bypass user decisions by lowering severity.' }
    }
    if ($finding.resolution.state -eq 'resolved') {
      Assert-String $finding.resolution.evidence 'resolution evidence'
      if ($finding.kind -in @('ambiguous','conflict') -and $finding.resolution.evidence -notmatch '(?i)user') { throw 'REVIEW: Semantic decisions must reference actual user evidence; it is not authenticated by this script.' }
    } elseif ($finding.severity -eq 'blocking') { foreach ($id in $finding.affectedWork) { $blocked[$id]=$true } }
  }
  foreach ($path in $unavailable) {
    $coveredUnavailable=@($Review.findings | Where-Object {
      $_.kind -eq 'unavailable' -and $_.severity -eq 'blocking' -and $_.resolution.state -eq 'pending' -and @($_.evidence | Where-Object { $_ -ceq $path -or $_.StartsWith("${path}:",[StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    })
    if (-not $coveredUnavailable.Count) { throw 'READINESS: Applicable unavailable sources need explicit blocking findings and affected work.' }
  }
  if ($Review.outcome -eq 'ready' -and $blocked.Count) { throw 'READINESS: Pending blockers cannot be ready.' }
  if ($Review.outcome -eq 'blocked' -and -not $blocked.Count) { throw 'READINESS: Blocked requires a concrete unresolved blocker.' }
  if ($Review.outcome -eq 'partial') {
    if (-not $runnable.Count -or -not $blocked.Count) { throw 'READINESS: Partial needs runnable work and concrete blockers.' }
    foreach ($id in $runnable.Keys) { if ($blocked.ContainsKey($id)) { throw 'READINESS: Runnable work must be disjoint from blockers.' } }
  }
}
function Assert-OwnedIndex($State) {
  if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf) -or (Get-Hash $indexPath) -cne $State.indexSha256) { throw 'REVIEW: Index is missing or externally modified; inspect before replacing.' }
}
function Read-OwnedReview($State,[string]$Id) {
  $entry=$State.reviews[$Id]
  if ($null -eq $entry) { throw 'UNCHECKED: No current review for this scope.' }
  $recordPath=Resolve-Project $entry.recordPath; $reportPath=Resolve-Project $entry.reportPath
  if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf) -or -not (Test-Path -LiteralPath $reportPath -PathType Leaf) -or (Get-Hash $recordPath) -cne $entry.recordSha256 -or (Get-Hash $reportPath) -cne $entry.reportSha256) { throw 'REVIEW: Current record/report was externally modified or is missing.' }
  $record=Read-Json $recordPath 'REVIEW'
  if ($record.schemaVersion -ne 1 -or $record.scope -cne $Id -or $record.assessment.scope -cne $Id -or $record.policyVersion -isnot [long] -and $record.policyVersion -isnot [int] -or $record.policyVersion -gt $policyVersion -or $record.policyVersion -lt 0) { throw 'REVIEW: Invalid review metadata.' }
  Assert-Array $record.inventory 'review inventory'; Assert-Array $record.dependencies 'recorded dependencies'
  # Fingerprints bind classifications, task, inventory and code baselines to this report.
  if ($record.fingerprints.task -cne (Get-TextHash $record.assessment.task) -or $record.fingerprints.inventory -cne (Fingerprint $record.inventory) -or $record.fingerprints.dependencies -cne (Fingerprint $record.dependencies) -or $record.fingerprints.classifications -cne (Fingerprint $record.assessment.documents) -or $record.reportSha256 -cne $entry.reportSha256 -or (Get-TextHash $record.assessment.report) -cne $entry.reportSha256) { throw 'REVIEW: Review fingerprints disagree with evidence.' }
  Assert-Assessment $record.assessment $record.inventory
  foreach ($dependency in $record.dependencies) {
    $null=Resolve-Project $dependency.path
    if ($dependency.exists -isnot [bool] -or ($dependency.exists -and $dependency.sha256 -notmatch '^[a-f0-9]{64}$') -or (-not $dependency.exists -and $null -ne $dependency.sha256)) { throw 'REVIEW: Invalid dependency baseline.' }
  }
  $declaredPaths=@($record.assessment.dependencies | ForEach-Object { Normalize-Path $_ } | Sort-Object)
  $recordedPaths=@($record.dependencies | ForEach-Object { Normalize-Path $_.path } | Sort-Object)
  if ((Fingerprint $declaredPaths) -cne (Fingerprint $recordedPaths)) { throw 'REVIEW: Dependency declaration/baseline mismatch.' }
  return $record
}
function Render-Index($State,$Assessment=$null) {
  $lines=[Collections.Generic.List[string]]::new()
  $lines.Add('# Documentation index'); $lines.Add(''); $lines.Add('Generated navigation, not a project-wide readiness claim. Inspect task reviews and unresolved decisions before development.'); $lines.Add('')
  $byPath=@{}
  if ($null -ne $Assessment) {
    $lines.Add("Classification context: scope $($Assessment.scope), task $($Assessment.task.Replace("`n",' ').Replace("`r",' ')). These classifications are scoped, not universal authority or a freshness result.")
    $lines.Add('')
    foreach ($classification in $Assessment.documents) { $byPath[$classification.path]=$classification }
  }
  $lines.Add('| Document | Kind | Category | Lifecycle | Authority | Applicability / disposition | Reason |'); $lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
  foreach ($doc in $State.inventory) {
    $classified=$byPath[$doc.path]
    if ($null -eq $classified) { $lines.Add("| $($doc.path.Replace('|','\|')) | $($doc.kind) | unclassified | unclassified | unclassified | unreviewed | Initial inventory only. |") }
    else {
      $applicability=if ($classified.Contains('applicability')) { $classified.applicability } elseif ($classified.disposition -eq 'unrelated') { 'unrelated' } else { 'applicable' }
      $reason=$classified.reason.Replace('|','\|').Replace("`n",' ').Replace("`r",' ')
      $lines.Add("| $($doc.path.Replace('|','\|')) | $($doc.kind) | $($classified.category) | $($classified.lifecycle) | $($classified.authority) | $applicability / $($classified.disposition) | $reason |")
    }
  }
  $lines.Add(''); $lines.Add('## Current scoped assessments'); $lines.Add('')
  foreach ($id in @($State.reviews.Keys | Sort-Object)) { $lines.Add("- $id`: $($State.reviews[$id].reportPath)") }
  if (-not $State.reviews.Count) { $lines.Add('No task has been assessed yet.') }
  return ($lines -join "`n") + "`n"
}
function Atomic-Text([string]$Relative,[string]$Content) {
  if (-not $Relative.StartsWith("$governance/",[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Writes must stay within governance.' }
  $absolute=Resolve-Project $Relative
  $null=New-Item -ItemType Directory -Path (Split-Path -Parent $absolute) -Force
  $temporary=$absolute+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try { [IO.File]::WriteAllText($temporary,$Content,[Text.UTF8Encoding]::new($false)); Assert-Plain $absolute; [IO.File]::Move($temporary,$absolute,$true) }
  finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}
function Acquire-Lock {
  $directory=Resolve-Project $governance; $null=New-Item -ItemType Directory -Path $directory -Force
  $path=Resolve-Project "$governance/.documentation.lock"
  try { return [IO.FileStream]::new($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None,4096,[IO.FileOptions]::DeleteOnClose) }
  catch { throw 'STATE: Another documentation writer holds the local lock.' }
}
# Marker is published last. A durable journal blocks all reads after hard interruption.
# Ordinary errors restore exact previous bytes; never silently reset an unknown record.
function Commit-Files($Files) {
  $before=@{}; foreach ($relative in $Files.Keys) { $absolute=Resolve-Project $relative; $before[$relative]=if (Test-Path -LiteralPath $absolute) { [IO.File]::ReadAllBytes($absolute) } else { $null } }
  $journal=@{schemaVersion=1;operation='documentation';paths=@($Files.Keys);startedAt=[DateTime]::UtcNow.ToString('o')}
  Atomic-Text "$governance/.pending.json" ($journal | ConvertTo-Json -Depth 20)
  try {
    foreach ($relative in @($Files.Keys | Where-Object { $_ -ne $stateRelative } | Sort-Object)) { Atomic-Text $relative $Files[$relative] }
    Atomic-Text $stateRelative $Files[$stateRelative]
    Remove-Item -LiteralPath $pendingPath -Force
  } catch {
    $errorRecord=$_; $recoveryFailure=$null
    foreach ($relative in $before.Keys) {
      try {
        $absolute=Resolve-Project $relative
        if ($null -eq $before[$relative]) { if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Force } }
        else { [IO.File]::WriteAllBytes($absolute,$before[$relative]) }
      } catch { $recoveryFailure=$_ }
    }
    if ($null -eq $recoveryFailure) { Remove-Item -LiteralPath $pendingPath -Force; throw $errorRecord }
    throw 'STATE: Documentation write/recovery incomplete; preserved pending marker must be inspected.'
  }
}

try {
  $state=Read-State
  $inventory=@(Get-Inventory $state)
  if ($Action -in @('Scan','Status')) {
    $delta=Get-Delta $state $inventory
    @{action=$Action.ToLowerInvariant();adopted=($null -ne $state);policyVersion=$policyVersion;recordedPolicyVersion=if ($state) {$state.policyVersion} else {$null};docsRoot=$DocsRoot;documents=$inventory;added=$delta.added;changed=$delta.changed;removed=$delta.removed;reviews=if ($state) {@($state.reviews.Keys | Sort-Object)} else {@()};boundaries=@{documentRoot=$DocsRoot;additionalPaths=if ($state) {@($state.additionalPaths)} else {@($AdditionalPaths)};rootDocuments=@('README.md','AGENTS.md');excluded=@('governance records','credentials','dependency trees','generated output');attachments='Inventoried, not interpreted or presumed read.'};limitation='Inventory and fingerprints do not prove semantic sufficiency or user approval.'} | ConvertTo-Json -Depth 30
    return
  }
  if ($Action -eq 'Initialize') {
    if ($null -ne $state -or (Test-Path -LiteralPath $indexPath)) { throw 'EXISTS: Existing governance must be inspected, not overwritten.' }
    $lock=Acquire-Lock
    if ((Test-Path -LiteralPath $statePath) -or (Test-Path -LiteralPath $indexPath) -or (Test-Path -LiteralPath $pendingPath)) { throw 'EXISTS: Existing/concurrent governance must be inspected.' }
    $inventory=@(Get-Inventory $null)
    $state=@{schemaVersion=1;policyVersion=$policyVersion;kitVersion=$kitVersion;docsRoot=$DocsRoot;additionalPaths=@($AdditionalPaths | ForEach-Object { Normalize-Path $_ });indexPath=$indexRelative;inventory=$inventory;reviews=@{};initializedAt=[DateTime]::UtcNow.ToString('o')}
    $index=Render-Index $state; $state.indexSha256=Get-TextHash $index
    Commit-Files @{$indexRelative=$index;$stateRelative=($state | ConvertTo-Json -Depth 50)}
    @{action='initialized';adopted=$true;marker=$stateRelative;ready=$false} | ConvertTo-Json
    return
  }
  if ($null -eq $state) { throw 'UNCHECKED: Initialize and author a scoped review before development.' }
  if ($Action -eq 'Validate') {
    Assert-Scope $Scope; Assert-String $Task 'current task'
    Assert-OwnedIndex $state; $record=Read-OwnedReview $state $Scope
    if ($state.policyVersion -ne $policyVersion -or $record.policyVersion -ne $policyVersion -or $Task -cne $record.assessment.task -or (Fingerprint $inventory) -cne $record.fingerprints.inventory -or (Fingerprint @(Get-Dependencies $record.assessment.dependencies -ForFreshness)) -cne $record.fingerprints.dependencies) { throw 'STALE: Task, policy, document inventory or declared code baseline changed; author a fresh impact assessment.' }
    if ($record.assessment.outcome -eq 'blocked') { throw 'BLOCKED: Dependent work awaits recorded decisions.' }
    if ($record.assessment.outcome -eq 'partial' -and ([string]::IsNullOrWhiteSpace($WorkItem) -or $WorkItem -cnotin $record.assessment.runnableWork)) { throw 'BLOCKED: Partial review permits only explicitly named independent work.' }
    @{action='validated';scope=$Scope;outcome=$record.assessment.outcome;workItem=$WorkItem;reportPath=$state.reviews[$Scope].reportPath;semanticApproval='Lead required'} | ConvertTo-Json
    return
  }
  # An authored review is not a command to rewrite product requirements or archive docs.
  $inputPath=Resolve-Project $ReviewInput
  if ($ReviewInput.Replace('\','/').StartsWith("$governance/",[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Authored inputs must not be stored with current governed deliverables.' }
  $review=Read-Json $inputPath 'REVIEW'; $inputHash=Get-Hash $inputPath
  Assert-Assessment $review $inventory
  $dependencies=@(Get-Dependencies $review.dependencies)
  $stateHash=Get-Hash $statePath
  $lock=Acquire-Lock
  $fresh=Read-State
  if ((Get-Hash $statePath) -cne $stateHash -or (Get-Hash $inputPath) -cne $inputHash -or (Fingerprint @(Get-Inventory $fresh)) -cne (Fingerprint $inventory) -or (Fingerprint @(Get-Dependencies $review.dependencies)) -cne (Fingerprint $dependencies)) { throw 'STALE: Evidence or registry changed during review publication.' }
  Assert-OwnedIndex $fresh
  # Protect every registered record, including other scopes, from silent replacement.
  foreach ($id in $fresh.reviews.Keys) { $null=Read-OwnedReview $fresh $id }
  $id=$review.scope; $recordRelative="$governance/reviews/$id.json"; $reportRelative="$governance/reviews/$id.md"
  if (-not $fresh.reviews.Contains($id) -and ((Test-Path -LiteralPath (Resolve-Project $recordRelative)) -or (Test-Path -LiteralPath (Resolve-Project $reportRelative)))) { throw 'EXISTS: Unowned scope files cannot be overwritten.' }
  $report=$review.report
  $record=@{schemaVersion=1;policyVersion=$policyVersion;kitVersion=$kitVersion;scope=$id;createdAt=[DateTime]::UtcNow.ToString('o');assessment=$review;inventory=$inventory;dependencies=$dependencies;reportSha256=Get-TextHash $report;fingerprints=@{task=Get-TextHash $review.task;inventory=Fingerprint $inventory;dependencies=Fingerprint $dependencies;classifications=Fingerprint $review.documents}}
  $recordText=$record | ConvertTo-Json -Depth 50
  $files=@{$recordRelative=$recordText;$reportRelative=$report}
  if ($fresh.reviews.Contains($id)) {
    $archive="$governance/reviews/archive/$id-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmss'))-$([guid]::NewGuid().ToString('N'))"
    $files["$archive.json"]=Get-Content -LiteralPath (Resolve-Project $recordRelative) -Raw
    $files["$archive.md"]=Get-Content -LiteralPath (Resolve-Project $reportRelative) -Raw
  }
  $fresh.policyVersion=$policyVersion; $fresh.kitVersion=$kitVersion; $fresh.inventory=$inventory; $fresh.updatedAt=[DateTime]::UtcNow.ToString('o')
  $fresh.reviews[$id]=@{recordPath=$recordRelative;recordSha256=Get-TextHash $recordText;reportPath=$reportRelative;reportSha256=Get-TextHash $report}
  $index=Render-Index $fresh $review; $fresh.indexSha256=Get-TextHash $index
  $files[$indexRelative]=$index; $files[$stateRelative]=$fresh | ConvertTo-Json -Depth 50
  # Recheck at publication, after rendering/ownership validation. A local writer lock
  # serializes this tool, but other editors can still change evidence while it runs.
  if ((Get-Hash $statePath) -cne $stateHash -or (Get-Hash $inputPath) -cne $inputHash -or (Fingerprint @(Get-Inventory $fresh)) -cne (Fingerprint $inventory) -or (Fingerprint @(Get-Dependencies $review.dependencies)) -cne (Fingerprint $dependencies)) { throw 'STALE: Evidence changed before publication.' }
  Assert-OwnedIndex $state
  foreach ($otherId in $state.reviews.Keys) { $null=Read-OwnedReview $state $otherId }
  Commit-Files $files
  @{action='recorded';scope=$id;outcome=$review.outcome;recordPath=$recordRelative;reportPath=$reportRelative;semanticApproval='Lead required'} | ConvertTo-Json
} finally { if ($null -ne $lock) { $lock.Dispose() } }
