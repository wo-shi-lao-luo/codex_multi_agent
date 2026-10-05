#requires -Version 7.0
<#
Validate optional prototype definitions and retain bounded authored input/output
evidence. This helper never calls a model, executes a tool, scores a case or grants
production acceptance. Hashes detect accidental corruption, not malicious writers
who can recompute them; shared files and native actor contexts are not a sandbox.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Validate','InitializeRun','RecordCall','Status')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRoot,
  [Parameter(Mandatory)][string]$DefinitionPath,
  [string]$WorkPath,
  [string]$RunId,
  [string]$CallInput
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/','\')
if ($root -eq [IO.Path]::GetPathRoot($root).TrimEnd('/','\')) { throw 'PATH: A filesystem root cannot be a simulation project.' }
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'PATH: ProjectRoot must exist.' }

# Linked ancestors are rejected even when a missing leaf would otherwise be safe.
function Assert-Plain([string]$Path) {
  $cursor=$Path
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'PATH: Linked paths are unsupported.' }
    }
    $next=Split-Path -Parent $cursor; if ($next -eq $cursor) { break }; $cursor=$next
  }
}
# Resolve literal repository paths only, without expansion or traversal aliases.
function Resolve-Relative([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or [IO.Path]::IsPathRooted($Value)) { throw 'PATH: Require repository-relative paths.' }
  $value=$Value.Replace('\','/')
  foreach ($part in ($value -split '/')) {
    if ($part -in @('','.','..') -or $part -match '[<>:"|?*\[\]#\x00-\x1f]' -or $part -match '[ .]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)' -or $part -match '^(\.git|\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|\.venv|venv)$') { throw 'PATH: Unsafe path segment.' }
  }
  $path=[IO.Path]::GetFullPath((Join-Path $root $value))
  if (-not $path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Path leaves project.' }
  Assert-Plain $path
  return $path
}
# Schema objects use exact fields: unknown extensions require a schema revision.
function Assert-Fields($Object,[string[]]$Fields) {
  if ($Object -isnot [Collections.IDictionary]) { throw 'SCHEMA: Require an object.' }
  foreach ($field in $Fields) { if (-not $Object.Contains($field)) { throw "SCHEMA: Missing $field." } }
  foreach ($field in $Object.Keys) { if ($field -cnotin $Fields) { throw "SCHEMA: Unknown field $field." } }
}
function Assert-Text($Value,[bool]$Nullable=$false) {
  if ($Nullable -and $null -eq $Value) { return }
  if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { throw 'SCHEMA: Require nonempty text.' }
}
function Assert-Id($Value) {
  Assert-Text $Value
  if ($Value -cnotmatch '^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$' -or $Value.Length -gt 64) { throw 'SCHEMA: Require a bounded lowercase identifier.' }
}
function Assert-Integer($Value,[int]$Minimum,[int]$Maximum) {
  if ($Value -isnot [long] -and $Value -isnot [int]) { throw 'SCHEMA: Require an integer.' }
  if ($Value -lt $Minimum -or $Value -gt $Maximum) { throw 'SCHEMA: Integer exceeds supported bounds.' }
}
function Assert-Array($Value,[int]$Maximum=100) {
  if ($Value -isnot [array] -or $Value.Count -gt $Maximum) { throw 'SCHEMA: Require a bounded array.' }
}
# Canonicalize a bounded decimal token for exact-value comparison without binary
# floating point. Representation changes (exponent/zero formatting) are harmless;
# changed numeric value or unsupported precision is rejected, never silently rounded.
function Normalize-Number([string]$Token) {
  if ($Token.Length -gt 128 -or $Token -cnotmatch '^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$') { throw 'INPUT: Numeric token exceeds supported decimal representation.' }
  $sign=$Matches[1]; $digits=$Matches[2]+$Matches[3]; $fraction=$Matches[3].Length; $power=0
  if ($Matches[4] -and (-not [int]::TryParse($Matches[4],[ref]$power) -or [Math]::Abs([long]$power) -gt 1000)) { throw 'INPUT: Numeric exponent exceeds supported bounds.' }
  $digits=$digits.TrimStart('0')
  if (-not $digits) { return '0' }
  $short=$digits.TrimEnd('0'); $power=$power-$fraction+$digits.Length-$short.Length
  return "$sign$short`e$power"
}
# Decode JSON without date coercion or duplicate-key last-wins ambiguity. Recursive
# construction preserves JSON string values and exact case-sensitive field names.
function Convert-Element([Text.Json.JsonElement]$Element,[int]$Depth=0) {
  if ($Depth -gt 80) { throw 'INPUT: JSON nesting exceeds supported depth.' }
  switch ($Element.ValueKind.ToString()) {
    Object {
      $map=[ordered]@{}
      $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($property in $Element.EnumerateObject()) {
        if (-not $seen.Add($property.Name)) { throw 'INPUT: Duplicate or case-ambiguous JSON field.' }
        $map[$property.Name]=Convert-Element $property.Value ($Depth+1)
      }
      return $map
    }
    Array { $items=@(); foreach ($item in $Element.EnumerateArray()) { $items+=,(Convert-Element $item ($Depth+1)) }; return ,$items }
    String { return $Element.GetString() }
    Number {
      $integer=0L; if ($Element.TryGetInt64([ref]$integer)) { return $integer }
      $raw=$Element.GetRawText(); $decimal=0D
      if (-not [decimal]::TryParse($raw,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$decimal)) { throw 'INPUT: Number is outside supported exact decimal range.' }
      if ((Normalize-Number $raw) -cne (Normalize-Number $decimal.ToString([Globalization.CultureInfo]::InvariantCulture))) { throw 'INPUT: Number requires unsupported precision.' }
      return $decimal
    }
    True { return $true }
    False { return $false }
    Null { return $null }
    default { throw 'INPUT: Unsupported JSON value.' }
  }
}
# Read bounded strict UTF-8 JSON without reporting potentially private contents.
function Read-Json([string]$Path,[int]$Maximum=1048576) {
  Assert-Plain $Path
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -gt $Maximum) { throw 'INPUT: Missing or oversized JSON file.' }
  $document=$null
  try {
    $text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($Path)).TrimStart([char]0xfeff)
    $options=[Text.Json.JsonDocumentOptions]::new(); $options.MaxDepth=80
    $document=[Text.Json.JsonDocument]::Parse($text,$options)
    return Convert-Element $document.RootElement
  } catch { throw 'INPUT: Invalid, ambiguous or overly nested UTF-8 JSON.' }
  finally { if ($document) { $document.Dispose() } }
}
function Json($Object) { return ConvertTo-Json -InputObject $Object -Depth 100 -Compress }
function Digest([string]$Text) {
  # Use APIs available in PowerShell 7.0 rather than newer static hashing helpers.
  $algorithm=[Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-','').ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}
function File-Digest([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

# Definitions constrain context transfer and mocked capabilities, not real inference.
function Assert-Definition($Definition) {
  Assert-Fields $Definition @('schemaVersion','flowId','revision','contextPolicyPath','rules','nodes','cases','models','budget')
  Assert-Integer $Definition.schemaVersion 1 1
  if ($Definition.schemaVersion -ne 1) { throw 'SCHEMA: Unsupported definition version.' }
  Assert-Id $Definition.flowId; Assert-Text $Definition.revision
  $null=Resolve-Relative $Definition.contextPolicyPath
  if ([IO.Path]::GetExtension($Definition.contextPolicyPath) -cne '.md') { throw 'SCHEMA: Context policy must be Markdown.' }
  Assert-Array $Definition.rules
  foreach ($rule in $Definition.rules) { $null=Resolve-Relative $rule; if ([IO.Path]::GetExtension($rule) -cne '.md') { throw 'SCHEMA: Rules must be Markdown.' } }
  Assert-Fields $Definition.models @('target','simulation')
  Assert-Fields $Definition.models.target @('name','provider')
  Assert-Text $Definition.models.target.name; Assert-Text $Definition.models.target.provider
  Assert-Fields $Definition.models.simulation @('requestedModel','requestedEffort','relation')
  Assert-Text $Definition.models.simulation.requestedModel
  if ($Definition.models.simulation.requestedEffort -cnotin @('low','medium','high','xhigh','max','ultra') -or $Definition.models.simulation.relation -cnotin @('proxy','same-model')) { throw 'SCHEMA: Invalid model expectation.' }
  Assert-Fields $Definition.budget @('maxCalls','maxCallsPerCase','maxRecordBytes')
  Assert-Integer $Definition.budget.maxCalls 1 1000
  Assert-Integer $Definition.budget.maxCallsPerCase 1 $Definition.budget.maxCalls
  Assert-Integer $Definition.budget.maxRecordBytes 1024 1048576
  Assert-Array $Definition.nodes; Assert-Array $Definition.cases
  if (-not $Definition.nodes.Count -or -not $Definition.cases.Count) { throw 'SCHEMA: Nodes and cases cannot be empty.' }
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($node in $Definition.nodes) {
    Assert-Fields $node @('id','kind','promptPath','context','mockTools')
    Assert-Id $node.id; if (-not $seen.Add($node.id)) { throw 'SCHEMA: Duplicate node.' }
    if ($node.kind -cnotin @('model','agent')) { throw 'SCHEMA: Unknown node kind.' }
    $null=Resolve-Relative $node.promptPath
    if ([IO.Path]::GetExtension($node.promptPath) -cne '.md') { throw 'SCHEMA: Prompts must be Markdown.' }
    Assert-Fields $node.context @('mode','historyPolicy','maxHistoryTurns','upstreamFields','stateFields','resetBetweenCases','retryPolicy')
    if ($node.context.mode -cnotin @('stateless','dialogue','workflow-node','agent') -or $node.context.historyPolicy -cnotin @('none','recent','summary','full') -or $node.context.retryPolicy -cnotin @('fresh','same-context') -or $node.context.resetBetweenCases -isnot [bool] -or -not $node.context.resetBetweenCases) { throw 'SCHEMA: Invalid context policy.' }
    Assert-Integer $node.context.maxHistoryTurns 0 1000
    foreach ($field in @('upstreamFields','stateFields')) {
      Assert-Array $node.context[$field]
      $unique=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($name in $node.context[$field]) { Assert-Id $name; if (-not $unique.Add($name)) { throw 'SCHEMA: Duplicate allowed field.' } }
    }
    Assert-Array $node.mockTools
    $tools=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($tool in $node.mockTools) { Assert-Id $tool; if (-not $tools.Add($tool)) { throw 'SCHEMA: Duplicate mock tool.' } }
    if ($node.context.historyPolicy -eq 'none' -and $node.context.maxHistoryTurns -ne 0) { throw 'SCHEMA: No-history policy requires zero retained turns.' }
    if ($node.context.mode -in @('stateless','workflow-node') -and $node.context.historyPolicy -ne 'none') { throw 'SCHEMA: This mode cannot retain dialogue history.' }
    if ($node.context.mode -eq 'stateless' -and ($node.context.upstreamFields.Count -or $node.context.stateFields.Count -or $node.mockTools.Count)) { throw 'SCHEMA: Stateless input cannot carry upstream, state or tools.' }
  }
  $seen.Clear()
  foreach ($case in $Definition.cases) {
    Assert-Fields $case @('id','description','input','expectedCriteria')
    Assert-Id $case.id; if (-not $seen.Add($case.id)) { throw 'SCHEMA: Duplicate case.' }
    Assert-Text $case.description; Assert-Array $case.expectedCriteria
    if (-not $case.expectedCriteria.Count) { throw 'SCHEMA: Expected criteria cannot be empty.' }
    foreach ($criterion in $case.expectedCriteria) { Assert-Text $criterion }
  }
}
# Observe only declared keys; a free-form currentInput remains caller-redacted data.
function Assert-AllowedFields($Object,[array]$Allowed) {
  if ($Object -isnot [Collections.IDictionary]) { throw 'SCHEMA: Context state must be an object.' }
  foreach ($key in $Object.Keys) { if ($key -cnotin $Allowed) { throw 'CONTEXT: Undeclared field.' } }
}
# Record contracts distinguish authored packets from unknown host-added context.
function Assert-Call($Call,$Definition,[string]$ExpectedRun) {
  Assert-Fields $Call @('schemaVersion','runId','callId','caseId','nodeId','sequence','suppliedInput','stateBefore','stateAfter','observedOutput','routing','actualMetadata','assessmentScope')
  Assert-Integer $Call.schemaVersion 1 1
  if ($Call.schemaVersion -ne 1 -or $Call.runId -cne $ExpectedRun -or $Call.assessmentScope -cne 'prototype') { throw 'SCHEMA: Invalid call identity or scope.' }
  Assert-Id $Call.callId; Assert-Id $Call.caseId; Assert-Id $Call.nodeId; Assert-Integer $Call.sequence 1 1000
  $node=@($Definition.nodes | Where-Object { $_.id -ceq $Call.nodeId })
  if ($node.Count -ne 1 -or $Call.caseId -cnotin @($Definition.cases.id)) { throw 'SCHEMA: Unknown case or node.' }; $node=$node[0]
  $input=$Call.suppliedInput
  Assert-Fields $input @('mode','instructions','currentInput','history','summary','upstream','state','toolResults')
  Assert-Text $input.instructions
  if ($input.mode -cne $node.context.mode) { throw 'CONTEXT: Mode differs from frozen node.' }
  Assert-Array $input.history 1000; Assert-Text $input.summary $true
  foreach ($turn in $input.history) {
    Assert-Fields $turn @('role','content'); Assert-Text $turn.content
    if ($turn.role -cnotin @('user','assistant','tool')) { throw 'CONTEXT: Invalid history role.' }
  }
  switch ($node.context.historyPolicy) {
    none { if ($input.history.Count -or $null -ne $input.summary) { throw 'CONTEXT: History not permitted.' } }
    recent { if ($input.history.Count -gt $node.context.maxHistoryTurns -or $null -ne $input.summary) { throw 'CONTEXT: Recent history exceeds policy.' } }
    summary { if ($input.history.Count -or $null -eq $input.summary) { throw 'CONTEXT: Summary policy requires summary only.' } }
    full { if ($input.history.Count -gt $node.context.maxHistoryTurns -or $null -ne $input.summary) { throw 'CONTEXT: Full history exceeds bounded policy.' } }
  }
  Assert-AllowedFields $input.upstream $node.context.upstreamFields
  foreach ($state in @($input.state,$Call.stateBefore,$Call.stateAfter)) { Assert-AllowedFields $state $node.context.stateFields }
  Assert-Array $input.toolResults
  foreach ($tool in $input.toolResults) { Assert-Fields $tool @('name','result'); if ($tool.name -cnotin $node.mockTools) { throw 'CONTEXT: Undeclared mock result.' } }
  Assert-Fields $Call.observedOutput @('status','response','mockToolRequests','error')
  if ($Call.observedOutput.status -cnotin @('completed','error','stopped')) { throw 'SCHEMA: Unknown observed status.' }
  Assert-Text $Call.observedOutput.error $true
  if ($Call.observedOutput.status -eq 'error' -and $null -eq $Call.observedOutput.error) { throw 'SCHEMA: Error status needs observed error.' }
  Assert-Array $Call.observedOutput.mockToolRequests
  foreach ($tool in $Call.observedOutput.mockToolRequests) { Assert-Fields $tool @('name','arguments'); if ($tool.name -cnotin $node.mockTools -or $tool.arguments -isnot [Collections.IDictionary]) { throw 'CONTEXT: Undeclared or malformed mock request.' } }
  Assert-Fields $Call.routing @('nextNodeId','reason'); Assert-Text $Call.routing.reason
  if ($null -ne $Call.routing.nextNodeId -and $Call.routing.nextNodeId -cnotin @($Definition.nodes.id)) { throw 'SCHEMA: Unknown routing node.' }
  Assert-Fields $Call.actualMetadata @('actualModel','actualEffort','evidence','elapsedMs','usage')
  foreach ($field in @('actualModel','actualEffort','evidence')) { Assert-Text $Call.actualMetadata[$field] $true }
  if (($null -ne $Call.actualMetadata.actualModel -or $null -ne $Call.actualMetadata.actualEffort) -and $null -eq $Call.actualMetadata.evidence) { throw 'METADATA: Actual identity needs host evidence.' }
  if ($null -ne $Call.actualMetadata.elapsedMs -and ($Call.actualMetadata.elapsedMs -isnot [ValueType] -or $Call.actualMetadata.elapsedMs -is [bool] -or $Call.actualMetadata.elapsedMs -lt 0)) { throw 'METADATA: Invalid elapsed time.' }
  if ($null -ne $Call.actualMetadata.usage -and $Call.actualMetadata.usage -isnot [Collections.IDictionary]) { throw 'METADATA: Usage must be observed object or null.' }
  if ([Text.Encoding]::UTF8.GetByteCount((Json $Call)) -gt $Definition.budget.maxRecordBytes) { throw 'BUDGET: Call exceeds byte ceiling.' }
}
# Publish one new immutable JSON file; existing files are never overwritten.
function Publish-Json([string]$Path,$Value) {
  $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try { [IO.File]::WriteAllText($temp,(Json $Value),[Text.UTF8Encoding]::new($false)); [IO.File]::Move($temp,$Path,$false) }
  finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
}
# Replace only the validated, helper-owned terminal anchor while holding its lock.
# Call and head cannot be committed together: an interrupted pair blocks further
# use rather than recovering automatically or replenishing the consumed budget.
function Replace-Head([string]$Path,$Value) {
  Assert-Plain $Path
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'INTEGRITY: Terminal anchor is missing.' }
  $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try { [IO.File]::WriteAllText($temp,(Json $Value),[Text.UTF8Encoding]::new($false)); [IO.File]::Move($temp,$Path,$true) }
  finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
}
Assert-Plain $root
$definitionFull=Resolve-Relative $DefinitionPath
if ([IO.Path]::GetExtension($DefinitionPath) -cne '.json') { throw 'SCHEMA: Definition must be a JSON file.' }
if ($Action -eq 'Validate' -or $Action -eq 'InitializeRun') {
  $definition=Read-Json $definitionFull; Assert-Definition $definition
  $sources=@($DefinitionPath,$definition.contextPolicyPath)+@($definition.rules)+@($definition.nodes.promptPath)
  $sources=@($sources | Select-Object -Unique)
  $total=0
  foreach ($source in $sources) {
    $path=Resolve-Relative $source
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 1048576) { throw 'INPUT: Missing or oversized declared source.' }
    try { $null=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($path)) } catch { throw 'INPUT: Declared source must be UTF-8 text.' }
    $total+=(Get-Item -LiteralPath $path).Length
  }
  if ($total -gt 8388608) { throw 'BUDGET: Declared snapshots exceed eight MiB.' }
  if ($Action -eq 'Validate') { Json @{schemaVersion=1;status='valid';assessmentScope='prototype';acceptance='not-assessed'}; return }
}
Assert-Id $RunId
if ($WorkPath -cnotmatch '^_work/ai-sim-[a-z][a-z0-9]*(?:-[a-z0-9]+)*$' -or $WorkPath.Length -gt 86) { throw 'PATH: Require an exact _work/ai-sim-<slug> work path.' }
$workFull=Resolve-Relative $WorkPath
$runFull=Resolve-Relative "$WorkPath/runs/$RunId"
$protection=Join-Path $PSScriptRoot 'generated-artifacts.ps1'
if ($Action -eq 'InitializeRun') {
  # Foreign directories are never adopted just because their names match a run.
  if (Test-Path -LiteralPath $runFull) { throw 'OWNERSHIP: Run already exists; choose a new ID.' }
  if (Test-Path -LiteralPath $workFull) {
    if (-not (Test-Path -LiteralPath (Join-Path $workFull '.ai-simulation-owner.json') -PathType Leaf)) { throw 'OWNERSHIP: Existing work directory is not helper-owned.' }
    $owner=Read-Json (Join-Path $workFull '.ai-simulation-owner.json')
    if ($owner.schemaVersion -ne 1 -or $owner.workPath -cne $WorkPath) { throw 'OWNERSHIP: Invalid work ownership.' }
  }
  $policy=(& $protection -Action Protect -ProjectRoot $root -Profile Work -WorkPath $WorkPath) | ConvertFrom-Json
  if ($policy.decisionRequired -or $policy.violations.Count) { throw 'GIT: Artifact protection requires a user decision.' }
  [IO.Directory]::CreateDirectory($workFull) | Out-Null
  $ownerPath=Join-Path $workFull '.ai-simulation-owner.json'
  if (-not (Test-Path -LiteralPath $ownerPath)) { Publish-Json $ownerPath @{schemaVersion=1;workPath=$WorkPath;owner='codex-ai-simulation'} }
}
# CreateNew + DeleteOnClose gives fail-closed mutual exclusion without stale locks
# after normal exceptions. Records and counts are derived under the same lock.
$lockPath=Join-Path $workFull '.ai-simulation.lock'
Assert-Plain $lockPath
if (-not (Test-Path -LiteralPath $workFull -PathType Container)) { throw 'OWNERSHIP: Run work directory is missing.' }
$lock=$null
try {
  if ($Action -eq 'Status') {
    if (Test-Path -LiteralPath $lockPath) { throw 'CONCURRENCY: Writer active; retry status after it finishes.' }
  } else {
    $lock=[IO.FileStream]::new($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None,4096,[IO.FileOptions]::DeleteOnClose)
  }
  if ($Action -eq 'InitializeRun') {
    if (Test-Path -LiteralPath $runFull) { throw 'OWNERSHIP: Concurrent initialization already created run.' }
    [IO.Directory]::CreateDirectory((Join-Path $runFull 'snapshots')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $runFull 'calls')) | Out-Null
    $snapshots=@(); $number=0; $frozenBytes=0
    foreach ($source in $sources) {
      $number++; $path=Resolve-Relative $source
      $bytes=[IO.File]::ReadAllBytes($path)
      $frozenBytes+=$bytes.Length
      if ($bytes.Length -gt 1048576 -or $frozenBytes -gt 8388608) { throw 'DRIFT: Source grew beyond snapshot byte ceiling.' }
      try { $null=[Text.UTF8Encoding]::new($false,$true).GetString($bytes) } catch { throw 'INPUT: Snapshot source is no longer UTF-8.' }
      $name=('snapshots/{0:D3}{1}' -f $number,[IO.Path]::GetExtension($source))
      [IO.File]::WriteAllBytes((Join-Path $runFull $name),$bytes)
      $snapshots+=@{source=$source;path=$name;sha256=File-Digest (Join-Path $runFull $name)}
    }
    # Revalidate the frozen definition, not a live source reread after snapshotting.
    $frozen=Read-Json (Join-Path $runFull $snapshots[0].path); Assert-Definition $frozen
    if ((Json $frozen) -cne (Json $definition)) { throw 'DRIFT: Definition changed during initialization.' }
    $manifest=@{schemaVersion=1;kitVersion='1.0.1';runId=$RunId;workPath=$WorkPath;definitionPath=$DefinitionPath;definition=$frozen;snapshots=$snapshots;createdAt=[DateTime]::UtcNow.ToString('o');assessmentScope='prototype';hostAddedContext='unknown';modelRequestParameters='unknown'}
    Publish-Json (Join-Path $runFull 'manifest.json') $manifest
    Publish-Json (Join-Path $runFull 'head.json') @{schemaVersion=1;runId=$RunId;sequence=0;lastEnvelopeSha256=$null}
    Publish-Json (Join-Path $runFull 'ownership.json') @{schemaVersion=1;manifestSha256=File-Digest (Join-Path $runFull 'manifest.json');runId=$RunId}
    Json @{schemaVersion=1;status='initialized';runId=$RunId;assessmentScope='prototype';acceptance='not-assessed'}; return
  }
  $policy=(& $protection -Action Check -ProjectRoot $root -Profile Work -WorkPath $WorkPath) | ConvertFrom-Json
  if ($policy.decisionRequired -or $policy.violations.Count) { throw 'GIT: Artifact staging policy requires a user decision.' }
  $manifest=Read-Json (Join-Path $runFull 'manifest.json') 16777216
  $ownership=Read-Json (Join-Path $runFull 'ownership.json')
  if ($ownership.runId -cne $RunId -or $ownership.manifestSha256 -cne (File-Digest (Join-Path $runFull 'manifest.json')) -or $manifest.runId -cne $RunId -or $manifest.workPath -cne $WorkPath -or $manifest.definitionPath -cne $DefinitionPath) { throw 'INTEGRITY: Manifest or ownership mismatch.' }
  $definition=$manifest.definition; Assert-Definition $definition
  $headPath=Join-Path $runFull 'head.json'
  $head=Read-Json $headPath
  Assert-Fields $head @('schemaVersion','runId','sequence','lastEnvelopeSha256')
  Assert-Integer $head.schemaVersion 1 1; Assert-Integer $head.sequence 0 1000
  if ($head.runId -cne $RunId -or ($head.sequence -eq 0 -and $null -ne $head.lastEnvelopeSha256) -or ($head.sequence -gt 0 -and ($head.lastEnvelopeSha256 -isnot [string] -or $head.lastEnvelopeSha256 -cnotmatch '^[a-f0-9]{64}$'))) { throw 'INTEGRITY: Invalid terminal anchor.' }
  $known=@('manifest.json','ownership.json','head.json')
  $sourceDrift=@()
  foreach ($snapshot in $manifest.snapshots) {
    if ($snapshot.path -cnotmatch '^snapshots/[0-9]{3}\.[a-zA-Z0-9]+$') { throw 'INTEGRITY: Invalid snapshot path.' }
    $path=Resolve-Relative "$WorkPath/runs/$RunId/$($snapshot.path)"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (File-Digest $path) -cne $snapshot.sha256) { throw 'INTEGRITY: Frozen snapshot changed.' }
    $known+=$snapshot.path
    $source=Resolve-Relative $snapshot.source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (File-Digest $source) -cne $snapshot.sha256) { $sourceDrift+=$snapshot.source }
  }
  $callDirectory=Resolve-Relative "$WorkPath/runs/$RunId/calls"
  if (-not (Test-Path -LiteralPath $callDirectory -PathType Container)) { throw 'INTEGRITY: Calls directory is missing.' }
  $records=@(); $previous=$null; $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($file in @(Get-ChildItem -LiteralPath $callDirectory -File -Force | Sort-Object Name)) {
    Assert-Plain $file.FullName
    $envelope=Read-Json $file.FullName 2097152
    Assert-Fields $envelope @('schemaVersion','record','recordSha256','previousSha256')
    Assert-Call $envelope.record $definition $RunId
    if ($envelope.schemaVersion -ne 1 -or $envelope.record.sequence -ne ($records.Count+1) -or $file.Name -cne ('{0:D4}-{1}.json' -f $envelope.record.sequence,$envelope.record.callId) -or -not $seen.Add($envelope.record.callId) -or $envelope.previousSha256 -cne $previous -or $envelope.recordSha256 -cne (Digest (Json $envelope.record))) { throw 'INTEGRITY: Record sequence or digest mismatch.' }
    $records+=,$envelope.record; $previous=File-Digest $file.FullName; $known+='calls/'+$file.Name
  }
  # A prefix hash chain alone cannot detect deletion of its final records. The
  # independent terminal anchor prevents truncation from reopening call budgets.
  if ($head.sequence -ne $records.Count -or $head.lastEnvelopeSha256 -cne $previous) { throw 'INTEGRITY: Terminal anchor differs from retained records.' }
  foreach ($file in @(Get-ChildItem -LiteralPath $runFull -Recurse -Force)) {
    Assert-Plain $file.FullName
    $relative=[IO.Path]::GetRelativePath($runFull,$file.FullName).Replace('\','/')
    if (($file.PSIsContainer -and $relative -cnotin @('snapshots','calls')) -or (-not $file.PSIsContainer -and $relative -cnotin $known)) { throw 'INTEGRITY: Unexpected or partial run artifact.' }
  }
  foreach ($case in $definition.cases) { if (@($records | Where-Object { $_.caseId -ceq $case.id }).Count -gt $definition.budget.maxCallsPerCase) { throw 'INTEGRITY: Existing case budget exceeded.' } }
  if ($records.Count -gt $definition.budget.maxCalls) { throw 'INTEGRITY: Existing global budget exceeded.' }
  if ($Action -eq 'Status') {
    # Status never writes a lock: detect overlapping writer activity and changed
    # record membership rather than reporting a knowingly mixed observation.
    if ((Test-Path -LiteralPath $lockPath) -or @(Get-ChildItem -LiteralPath $callDirectory -File -Force).Count -ne $records.Count) { throw 'CONCURRENCY: Evidence changed during status; retry after writers finish.' }
    $cases=@(); foreach ($case in $definition.cases) { $count=@($records | Where-Object { $_.caseId -ceq $case.id }).Count; $cases+=@{caseId=$case.id;callCount=$count;remainingCalls=$definition.budget.maxCallsPerCase-$count} }
    Json @{schemaVersion=1;status='intact';runId=$RunId;callCount=$records.Count;remainingCalls=$definition.budget.maxCalls-$records.Count;caseCounts=$cases;budget=$definition.budget;unknownActualModelCount=@($records | Where-Object { $null -eq $_.actualMetadata.actualModel }).Count;sourceDrift=$sourceDrift;assessmentScope='prototype';acceptance='not-assessed';hostAddedContext='unknown'}; return
  }
  $call=Read-Json (Resolve-Relative $CallInput) $definition.budget.maxRecordBytes
  Assert-Call $call $definition $RunId
  if ($call.sequence -ne ($records.Count+1) -or $seen.Contains($call.callId)) { throw 'SEQUENCE: Call is duplicate or out of order.' }
  if ($records.Count -ge $definition.budget.maxCalls -or @($records | Where-Object { $_.caseId -ceq $call.caseId }).Count -ge $definition.budget.maxCallsPerCase) { throw 'BUDGET: Run or case call ceiling reached.' }
  # Check inspects conflicts but does not establish ignore coverage. Restore only
  # the declared exact subtree immediately before an otherwise valid new record;
  # rejected calls cannot edit Git policy, and explicit includes require approval.
  $policy=(& $protection -Action Protect -ProjectRoot $root -Profile Work -WorkPath $WorkPath) | ConvertFrom-Json
  if ($policy.decisionRequired -or $policy.violations.Count) { throw 'GIT: Artifact protection requires a user decision.' }
  $path=Join-Path $callDirectory ('{0:D4}-{1}.json' -f $call.sequence,$call.callId)
  Publish-Json $path @{schemaVersion=1;record=$call;recordSha256=Digest (Json $call);previousSha256=$previous}
  Replace-Head $headPath @{schemaVersion=1;runId=$RunId;sequence=$call.sequence;lastEnvelopeSha256=File-Digest $path}
  Json @{schemaVersion=1;status='recorded';runId=$RunId;callId=$call.callId;sequence=$call.sequence;assessmentScope='prototype';acceptance='not-assessed'}
} finally { if ($lock) { $lock.Dispose() } }
