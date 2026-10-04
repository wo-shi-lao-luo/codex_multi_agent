# Exercise optional simulation packaging and local behavior; native AI decisions need runtime acceptance.
[CmdletBinding()]
param([switch]$DiscoveryOnly,[switch]$BehaviorOnly,[switch]$NumericRed)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-Condition {
  # Report an observable contract violation without swallowing failures.
  param([bool]$Condition,[string]$Message)
  if (-not $Condition) { throw $Message }
}
# SIM-01: the optional workflow is distributable. Expected: named roles, Skills and helper exist.
foreach ($relative in $(if ($BehaviorOnly) { @('skills/team-core/scripts/ai-simulation.ps1') } else { @('skills/team-ai-simulate/SKILL.md','skills/ai-engineering/SKILL.md','agents/team-ai-simulation-actor-basic.toml','agents/team-ai-simulation-actor-advanced.toml','agents/team-ai-architect.toml','agents/team-ai-engineer.toml','skills/team-core/scripts/ai-simulation.ps1') })) {
  Assert-Condition (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf) "SIM-01 missing packaged capability: $relative"
}
# SIM-08: the approved AI-only workflow and distinct model-agnostic roles replace obsolete names.
# Expected: no retired source assets, exactly approved default profiles and release line 1.0.0.
if(-not $BehaviorOnly){
  foreach($retired in 'skills/team-simulate','agents/team-simulation-actor.toml'){
    Assert-Condition (-not(Test-Path -LiteralPath (Join-Path $root $retired))) "Retired simulation source asset remains: $retired"
  }
  $profiles=@{'team-ai-simulation-actor-basic'=@('gpt-6-luna','medium');'team-ai-simulation-actor-advanced'=@('gpt-6.1-sol','medium');'team-ai-architect'=@('gpt-6.1-sol','xhigh')}
  foreach($role in $profiles.Keys){
    $profile=Get-Content -LiteralPath (Join-Path $root "agents/$role.toml") -Raw
    Assert-Condition ($profile -match ('(?m)^model = "'+[regex]::Escape($profiles[$role][0])+'"\r?$') -and $profile -match ('(?m)^model_reasoning_effort = "'+$profiles[$role][1]+'"\r?$')) "Unexpected default profile for $role"
    Assert-Condition ($profile -match '(?m)^sandbox_mode = "read-only"\r?$') "Readonly simulation/design role $role is writable."
  }
  Assert-Condition ((Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim() -eq '1.0.0') 'Approved release line is not 1.0.0.'
}
if ($DiscoveryOnly) { Write-Output 'AI simulation discovery checks passed.'; return }
$helper = Join-Path $root 'skills/team-core/scripts/ai-simulation.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
$fixture = Join-Path $tempParent ('codex-ai-simulation-test-' + [guid]::NewGuid().ToString('N'))
function Write-Json([string]$Relative,[object]$Value) {
  # Only fixture JSON is generated; never modify repository or installed source.
  $path = Join-Path $fixture $Relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
  $Value | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $path -Encoding utf8
}
function Invoke-Simulation([string]$Action,[string]$CallInput='',[string]$SelectedRun='run-one') {
  # Return the real helper's structured response; supplied paths stay fixture-relative.
  $args = @{ Action=$Action; ProjectRoot=$fixture; DefinitionPath='docs/ai-workflows/demo/definition.json'; WorkPath='_work/ai-sim-fixture'; RunId=$SelectedRun }
  if ($CallInput) { $args.CallInput=$CallInput }
  & $helper @args
}
function Fingerprint([string]$Path) {
  # Include names and hashes to detect partial evidence or overwritten records.
  (@(Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object { [IO.Path]::GetRelativePath($Path,$_.FullName)+':'+(Get-FileHash -LiteralPath $_.FullName).Hash } | Sort-Object) -join "`n")
}
function Assert-Rejected([scriptblock]$Run,[string]$Label) {
  # Every negative case checks unchanged disk evidence, not merely an exception.
  $before=Fingerprint $fixture; $failed=$false
  try { & $Run | Out-Null } catch { $failed=$true }
  Assert-Condition $failed "$Label was accepted."
  Assert-Condition ((Fingerprint $fixture) -eq $before) "$Label changed fixture evidence on rejection."
}
function New-Call([string]$Node,[int]$Sequence) {
  # Default call includes only approved stateless context and unknown host telemetry.
  @{schemaVersion=1;runId='run-one';callId="call-$Sequence";caseId='case-one';nodeId=$Node;sequence=$Sequence;
    suppliedInput=@{mode='stateless';instructions='Return a synthetic greeting.';currentInput='hello';history=@();summary=$null;upstream=@{};state=@{};toolResults=@()};
    stateBefore=@{};stateAfter=@{};observedOutput=@{status='completed';response='hello';mockToolRequests=@();error=$null};
    routing=@{nextNodeId=$null;reason='terminal'};actualMetadata=@{actualModel=$null;actualEffort=$null;evidence=$null;elapsedMs=$null;usage=$null};assessmentScope='prototype'}
}
function Canonical-Value($Value) {
  # Sort object keys recursively while preserving arrays and scalar values for record equality.
  if($Value -is [Collections.IDictionary]){
    $ordered=[ordered]@{};foreach($key in @($Value.Keys | Sort-Object -CaseSensitive)){$ordered[$key]=Canonical-Value $Value[$key]};return $ordered
  }
  if($Value -is [array]){$items=@();foreach($item in $Value){$items+=,(Canonical-Value $item)};return ,$items}
  return $Value
}
try {
  New-Item -ItemType Directory -Path $fixture | Out-Null
  & git -C $fixture init -q
  Assert-Condition ($LASTEXITCODE -eq 0) 'Fixture Git initialization failed.'
  $base='docs/ai-workflows/demo'
  New-Item -ItemType Directory -Path "$fixture/$base" -Force | Out-Null
  Set-Content -LiteralPath "$fixture/$base/context-policy.md" -Value 'Synthetic context only.'
  Set-Content -LiteralPath "$fixture/$base/rules.md" -Value 'Mock tools only; no production writes.'
  Set-Content -LiteralPath "$fixture/$base/prompt.md" -Value 'Return a synthetic greeting.'
  $nodes=@()
  foreach ($mode in 'stateless','dialogue','workflow-node','agent') {
    $nodes+=@{id=$mode;kind=$(if($mode -eq 'agent'){'agent'}else{'model'});promptPath="$base/prompt.md";context=@{mode=$mode;historyPolicy=$(if($mode -eq 'dialogue'){'recent'}else{'none'});maxHistoryTurns=$(if($mode -eq 'dialogue'){2}else{0});upstreamFields=@(if($mode -eq 'workflow-node'){'answer'});stateFields=@(if($mode -eq 'agent'){'step'});resetBetweenCases=$true;retryPolicy='fresh'};mockTools=@(if($mode -eq 'agent'){'lookup'})}
  }
  $definition=@{schemaVersion=1;flowId='demo';revision='v1';contextPolicyPath="$base/context-policy.md";rules=@("$base/rules.md");nodes=$nodes;cases=@(@{id='case-one';description='Synthetic greeting';input='hello';expectedCriteria=@('greeting')});models=@{target=@{name='flash-like';provider='prototype'};simulation=@{requestedModel='gpt-6-luna';requestedEffort='medium';relation='proxy'}};budget=@{maxCalls=6;maxCallsPerCase=4;maxRecordBytes=16384}}
  Write-Json "$base/definition.json" $definition
  # SIM-02: valid definition validation is read-only; initialization protects bounded raw evidence.
  # Expected: validation leaves the tree unchanged and Git ignores the exact work path, not all _work.
  $before=Fingerprint $fixture
  Invoke-Simulation Validate | Out-Null
  Assert-Condition ((Fingerprint $fixture) -eq $before) 'Validate wrote files.'
  Invoke-Simulation InitializeRun | Out-Null
  # SIM-08: new local run metadata identifies the same release as the shipped package.
  # Expected: manifest kitVersion equals VERSION, without claiming actual model identity.
  $releaseManifest=Get-Content -LiteralPath "$fixture/_work/ai-sim-fixture/runs/run-one/manifest.json" -Raw | ConvertFrom-Json
  Assert-Condition ($releaseManifest.kitVersion -eq (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()) 'Run manifest release does not match package VERSION.'
  # SIM-04 precision regression: authored raw JSON numbers must never be silently rounded.
  # Expected: supported Decimal values preserve exact value; harmless lexical .0 is allowed.
  Invoke-Simulation InitializeRun '' 'run-numeric' | Out-Null
  $numericCall=New-Call stateless 1
  $numericCall.runId='run-numeric'
  $rawNumeric=($numericCall | ConvertTo-Json -Depth 40) -replace '"currentInput"\s*:\s*"hello"','"currentInput":{"accountId":99999999999999999999,"balance":0.12345678901234567890}'
  Set-Content -LiteralPath "$fixture/call.json" -Value $rawNumeric -Encoding utf8
  Invoke-Simulation RecordCall 'call.json' 'run-numeric' | Out-Null
  {
    $numericFile=Get-ChildItem -LiteralPath "$fixture/_work/ai-sim-fixture/runs/run-numeric/calls" -File | Select-Object -First 1
    $numericDoc=[Text.Json.JsonDocument]::Parse((Get-Content -LiteralPath $numericFile.FullName -Raw))
    try {
      $inputObject=$numericDoc.RootElement.GetProperty('record').GetProperty('suppliedInput').GetProperty('currentInput')
      $expectedId=[decimal]::Parse('99999999999999999999',[Globalization.CultureInfo]::InvariantCulture)
      $expectedBalance=[decimal]::Parse('0.12345678901234567890',[Globalization.CultureInfo]::InvariantCulture)
      Assert-Condition ($inputObject.GetProperty('accountId').GetDecimal() -eq $expectedId -and $inputObject.GetProperty('balance').GetDecimal() -eq $expectedBalance) 'Raw JSON numeric input was accepted but rounded.'
    } finally {$numericDoc.Dispose()}
  }.Invoke()
  # SIM-04 precision boundary: values beyond supported Decimal range/precision fail before writes.
  # Expected: neither invalid number is rounded into an immutable second observation.
  foreach($literal in '999999999999999999999999999999999','0.123456789012345678901234567890123456789'){
    $unsupported=New-Call stateless 2; $unsupported.runId='run-numeric'
    $unsupportedJson=($unsupported | ConvertTo-Json -Depth 40) -replace '"currentInput"\s*:\s*"hello"',('"currentInput":'+$literal)
    Set-Content -LiteralPath "$fixture/call.json" -Value $unsupportedJson -Encoding utf8
    Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-numeric'} 'Unsupported numeric precision'
  }
  if($NumericRed){Write-Output 'Numeric fidelity checks passed.';return}
  # SIM-03/SIM-04 follow-up: unsafe paths/IDs and a reused run must not alter any files.
  # Expected: reject before protection writes, preserve the original initialized run.
  Assert-Rejected {Invoke-Simulation InitializeRun} 'Duplicate run initialization'
  Assert-Rejected {& $helper -Action Validate -ProjectRoot $fixture -DefinitionPath '../outside.json'} 'Traversing definition path'
  Assert-Rejected {& $helper -Action InitializeRun -ProjectRoot $fixture -DefinitionPath "$base/definition.json" -WorkPath '_work/../outside' -RunId 'safe'} 'Traversing work path'
  Assert-Rejected {Invoke-Simulation InitializeRun '' '../escape'} 'Traversing run ID'
  $foreign="$fixture/_work/ai-sim-fixture/runs/foreign-run"
  New-Item -ItemType Directory -Path $foreign | Out-Null
  Set-Content -LiteralPath "$foreign/user-owned.txt" -Value 'Preserve this unrelated file.'
  Assert-Rejected {Invoke-Simulation InitializeRun '' 'foreign-run'} 'Foreign run initialization'
  # SIM-03 follow-up: a linked path inside a project is not a trustworthy plain source ancestor.
  # Expected: refuse the junction path before writes; inability to create one is reported, not passed.
  $junctionCreated=$false
  try { New-Item -ItemType Junction -Path "$fixture/docs/ai-workflows/linked" -Target "$fixture/$base" -ErrorAction Stop | Out-Null; $junctionCreated=$true }
  catch { Write-Output 'Junction fixture unavailable; linked-path check not executed.' }
  if($junctionCreated){Assert-Rejected {& $helper -Action Validate -ProjectRoot $fixture -DefinitionPath 'docs/ai-workflows/linked/definition.json'} 'Reparse definition ancestor'}
  & git -C $fixture check-ignore --quiet --no-index '_work/ai-sim-fixture/probe.json'
  Assert-Condition ($LASTEXITCODE -eq 0) 'Run work path not ignored.'
  & git -C $fixture check-ignore --quiet --no-index '_work/unrelated/probe.json'
  Assert-Condition ($LASTEXITCODE -ne 0) 'Unrelated work path was broadly ignored.'
  # SIM-03: unknown IDs, traversal, wrong context/history, tools and oversized input are invalid.
  # Expected: each rejected record leaves all existing evidence unchanged.
  foreach ($mutation in @(
    {param($c)$c.nodeId='missing'}, {param($c)$c.callId='../escape'},
    {param($c)$c.suppliedInput.history=@(@{role='user';content='leaked'})},
    {param($c)$c.suppliedInput.mode='agent'},
    {param($c)$c.suppliedInput.toolResults=@(@{name='real-network';result='unsafe'})},
    {param($c)$c.suppliedInput.currentInput=('x'*20000)},
    {param($c)$c.actualMetadata.actualModel='gpt-6-luna'},
    {param($c)$c.suppliedInput.Remove('instructions')},
    {param($c)$c.suppliedInput.history=$null}
  )) { $bad=New-Call stateless 1; & $mutation $bad; Write-Json 'call.json' $bad; Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Invalid supplied call' }
  # SIM-02: all four approved modes can record one complete observed call each.
  # Expected: selected dialogue/upstream/state/mock inputs are retained without target acceptance.
  $sequence=0
  $expectedCalls=@{}
  foreach ($mode in 'stateless','dialogue','workflow-node','agent') {
    $sequence++; $call=New-Call $mode $sequence; $call.suppliedInput.mode=$mode
    if ($mode -eq 'dialogue') {$call.suppliedInput.history=@(@{role='user';content='prior synthetic turn'})}
    if ($mode -eq 'workflow-node') {$call.suppliedInput.upstream=@{answer='selected'};$call.routing=@{nextNodeId='agent';reason='Selected upstream result requests mock lookup.'}}
    if ($mode -eq 'agent') {$call.suppliedInput.state=@{step=1};$call.stateBefore=@{step=0};$call.stateAfter=@{step=2};$call.suppliedInput.toolResults=@(@{name='lookup';result=@{value='synthetic'}});$call.observedOutput.mockToolRequests=@(@{name='lookup';arguments=@{key='synthetic'}})}
    $expectedCalls[$call.callId]=$call | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
    Write-Json 'call.json' $call; Invoke-Simulation RecordCall 'call.json' | Out-Null
    Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Duplicate call'
  }
  # SIM-04: per-case hard budget is exhausted after four valid observations.
  # Expected: a fifth call cannot add evidence even though global budget remains.
  Write-Json 'call.json' (New-Call stateless 5)
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Exhausted per-case budget'
  $status=Invoke-Simulation Status | ConvertFrom-Json
  Assert-Condition ($null -ne $status) 'Status returned no structured evidence.'
  Assert-Condition ($status.status -eq 'intact' -and $status.callCount -eq 4 -and $status.unknownActualModelCount -eq 4) 'Status counts or unknown model labels are wrong.'
  Assert-Condition ($status.assessmentScope -eq 'prototype' -and $status.acceptance -eq 'not-assessed') 'Status scope promoted prototype evidence into acceptance.'
  Assert-Condition (($status | ConvertTo-Json -Depth 30) -notmatch '"(passed|accepted)"\s*:\s*true') 'Status fabricated acceptance.'
  # SIM-02/SIM-06: retained complete records must equal supplied data and distinguish proxy/unknown.
  # Expected: four immutable envelopes preserve the exact instructions/input without inferred metadata.
  $callFiles=@(Get-ChildItem -LiteralPath "$fixture/_work/ai-sim-fixture/runs/run-one/calls" -File | Sort-Object Name)
  Assert-Condition ($callFiles.Count -eq 4) 'Call file count differs from actual observations.'
  # SIM-04 regression: deleting an immutable suffix cannot replenish history or call budget.
  # Expected: both Status and a replacement call reject missing tail; restore exact bytes afterward.
  $tail=$callFiles[-1]; $tailBytes=[IO.File]::ReadAllBytes($tail.FullName)
  Remove-Item -LiteralPath $tail.FullName -Force
  Assert-Rejected {Invoke-Simulation Status} 'Deleted call tail status'
  Write-Json 'call.json' (New-Call stateless 4)
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Deleted call tail replacement'
  [IO.File]::WriteAllBytes($tail.FullName,$tailBytes)
  # SIM-04 regression: deleting the complete call set must not turn an observed run into a new one.
  # Expected: independent head history detects an empty ledger and rejects budget reset.
  $savedCalls=@{}; foreach($file in $callFiles){$savedCalls[$file.FullName]=[IO.File]::ReadAllBytes($file.FullName);Remove-Item -LiteralPath $file.FullName -Force}
  Assert-Rejected {Invoke-Simulation Status} 'Deleted complete ledger status'
  Write-Json 'call.json' (New-Call stateless 1)
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Deleted complete ledger replacement'
  foreach($path in $savedCalls.Keys){[IO.File]::WriteAllBytes($path,$savedCalls[$path])}
  foreach ($file in $callFiles) {
    $saved=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    Assert-Condition ($saved.record.suppliedInput.instructions -eq 'Return a synthetic greeting.' -and $saved.record.suppliedInput.currentInput -eq 'hello') 'Saved input differs from supplied instructions/current input.'
    Assert-Condition ($null -eq $saved.record.actualMetadata.actualModel -and $null -eq $saved.record.actualMetadata.usage) 'Unknown model or usage invented in saved call.'
    $savedMap=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
    $expectedJson=Canonical-Value $expectedCalls[$saved.record.callId] | ConvertTo-Json -Depth 40 -Compress
    $actualJson=Canonical-Value $savedMap.record | ConvertTo-Json -Depth 40 -Compress
    Assert-Condition ($actualJson -ceq $expectedJson) 'Complete observed record differs from authored input/history/state/tools/output/routing.'
  }
  # SIM-04: source edits after initialization do not silently mutate the frozen run.
  # Expected: Status reports source drift separately while original snapshots remain intact.
  Add-Content -LiteralPath "$fixture/$base/prompt.md" -Value 'A later source revision.'
  $drift=Invoke-Simulation Status | ConvertFrom-Json
  Assert-Condition ($drift.status -eq 'intact' -and @($drift.sourceDrift).Count -gt 0) 'Source drift not distinguished from historical integrity.'
  # SIM-04: editing an immutable observed call breaks its integrity chain.
  # Expected: status rejects corruption, then exact original-byte restoration recovers integrity.
  $originalBytes=[IO.File]::ReadAllBytes($callFiles[0].FullName)
  Add-Content -LiteralPath $callFiles[0].FullName -Value 'tampered'
  Assert-Rejected {Invoke-Simulation Status} 'Tampered call status'
  [IO.File]::WriteAllBytes($callFiles[0].FullName,$originalBytes)
  Invoke-Simulation Status | Out-Null
  Write-Output 'Simulation checkpoint: four context modes, per-case budget, input integrity and source drift passed.'
  # SIM-04 follow-up: freeze a second run, edit its source, then record a valid frozen call.
  # Expected: source drift is reported, not used to change the historical runtime contract.
  $definition.cases+=@{id='case-two';description='Second synthetic greeting';input='hello';expectedCriteria=@('greeting')}
  $definition.budget.maxCalls=2; $definition.budget.maxCallsPerCase=2
  Write-Json "$base/definition.json" $definition
  Invoke-Simulation InitializeRun '' 'run-global' | Out-Null
  Add-Content -LiteralPath "$fixture/$base/rules.md" -Value 'Later source-only revision.'
  # SIM-04 follow-up: stopped and failed observed attempts consume the global call allocation.
  # Expected: two cases each consume one, then a third cannot exceed the global two-call budget.
  foreach ($n in 1,2) {
    $call=New-Call stateless $n; $call.runId='run-global'
    if($n -eq 2){$call.caseId='case-two'}
    $call.observedOutput.status=$(if($n -eq 1){'stopped'}else{'error'})
    $call.observedOutput.response=$null; $call.observedOutput.error='Synthetic observed stop/failure.'
    Write-Json 'call.json' $call; Invoke-Simulation RecordCall 'call.json' 'run-global' | Out-Null
  }
  $call=New-Call stateless 3; $call.runId='run-global'; Write-Json 'call.json' $call
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-global'} 'Exhausted global budget'
  $globalStatus=Invoke-Simulation Status '' 'run-global' | ConvertFrom-Json
  Assert-Condition ($globalStatus.callCount -eq 2 -and @($globalStatus.sourceDrift).Count -gt 0) 'Failed/stopped calls or frozen source drift not retained.'
  # SIM-04 follow-up: corrupting a manifest blocks read status and new record publication.
  # Expected: no repaired/overwritten evidence is silently produced; byte restoration recovers.
  $manifest="$fixture/_work/ai-sim-fixture/runs/run-global/manifest.json"
  $manifestBytes=[IO.File]::ReadAllBytes($manifest)
  Add-Content -LiteralPath $manifest -Value 'tampered'
  Assert-Rejected {Invoke-Simulation Status '' 'run-global'} 'Tampered manifest status'
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-global'} 'Tampered manifest new call'
  [IO.File]::WriteAllBytes($manifest,$manifestBytes)
  Write-Output 'Simulation checkpoint: global stopped/error budget and manifest integrity passed.'
  # SIM-03 follow-up: summary/full retention and selected state/upstream fields are explicit.
  # Expected: reject over-retention, absent summaries and undeclared fields; accept bounded policies.
  $summaryNode=$nodes[1].Clone(); $summaryNode.id='dialogue-summary'; $summaryNode.context=$nodes[1].context.Clone(); $summaryNode.context.historyPolicy='summary'; $summaryNode.context.maxHistoryTurns=0
  $fullNode=$nodes[1].Clone(); $fullNode.id='dialogue-full'; $fullNode.context=$nodes[1].context.Clone(); $fullNode.context.historyPolicy='full'
  $definition.nodes=@($nodes)+@($summaryNode,$fullNode); $definition.budget.maxCalls=10; $definition.budget.maxCallsPerCase=10
  Write-Json "$base/definition.json" $definition
  Invoke-Simulation InitializeRun '' 'run-context' | Out-Null
  foreach ($spec in @(
    @{node='dialogue';change={param($c)$c.suppliedInput.history=@(@{role='user';content='one'},@{role='assistant';content='two'},@{role='user';content='three'})}},
    @{node='dialogue-summary';change={param($c)$c.suppliedInput.summary=$null}},
    @{node='dialogue-full';change={param($c)$c.suppliedInput.summary='Undeclared summary.'}},
    @{node='workflow-node';change={param($c)$c.suppliedInput.upstream=@{undeclared='leak'}}},
    @{node='agent';change={param($c)$c.suppliedInput.state=@{undeclared='leak'}}},
    @{node='agent';change={param($c)$c.stateAfter=@{undeclared='leak'}}}
  )) {
    $call=New-Call $spec.node 1; $call.runId='run-context'; $call.suppliedInput.mode=$(if($spec.node.StartsWith('dialogue')){'dialogue'}else{$spec.node})
    & $spec.change $call; Write-Json 'call.json' $call
    Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-context'} 'Invalid retained/named context'
  }
  $call=New-Call dialogue-summary 1; $call.runId='run-context'; $call.suppliedInput.mode='dialogue'; $call.suppliedInput.summary='Observed synthetic summary.'
  Write-Json 'call.json' $call; Invoke-Simulation RecordCall 'call.json' 'run-context' | Out-Null
  $call=New-Call dialogue-full 2; $call.runId='run-context'; $call.suppliedInput.mode='dialogue'; $call.suppliedInput.history=@(@{role='user';content='one'},@{role='assistant';content='two'})
  Write-Json 'call.json' $call; Invoke-Simulation RecordCall 'call.json' 'run-context' | Out-Null
  $contextStatus=Invoke-Simulation Status '' 'run-context' | ConvertFrom-Json
  Assert-Condition ($contextStatus.callCount -eq 2) 'Valid summary/full policies did not record both calls.'
  # SIM-03 follow-up: duplicate/case-ambiguous JSON fields cannot select a last-wins identity.
  # Expected: reject both encodings unchanged before any evidence publication.
  $call=New-Call stateless 3; $call.runId='run-context'; $call.suppliedInput.currentInput='2026-10-05T00:00:00Z'
  Write-Json 'call.json' $call
  $cleanCall=Get-Content -LiteralPath "$fixture/call.json" -Raw
  foreach($name in 'runId','RunId') {
    $ambiguous=[regex]::Replace($cleanCall,'"runId"\s*:\s*"run-context"',('"runId":"run-context","'+$name+'":"run-context"'))
    Set-Content -LiteralPath "$fixture/call.json" -Value $ambiguous -Encoding utf8
    Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-context'} 'Ambiguous JSON identity'
  }
  Set-Content -LiteralPath "$fixture/call.json" -Value $cleanCall -Encoding utf8
  # SIM-03 follow-up: forced staging and explicit include are human-decision conflicts.
  # Expected: reject valid records without altering the index or raw run evidence.
  $trackedRelative='_work/ai-sim-fixture/runs/run-context/manifest.json'
  & git -C $fixture add -f -- $trackedRelative
  Assert-Condition ($LASTEXITCODE -eq 0) 'Controlled forced-stage fixture failed.'
  $indexBefore=(& git -C $fixture ls-files --stage) -join "`n"
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-context'} 'Tracked raw evidence'
  Assert-Condition (((& git -C $fixture ls-files --stage) -join "`n") -eq $indexBefore) 'Record rejection changed Git index.'
  & git -C $fixture rm --cached --quiet -- $trackedRelative
  Assert-Condition ($LASTEXITCODE -eq 0) 'Controlled forced-stage fixture restoration failed.'
  $ignoreBytes=[IO.File]::ReadAllBytes("$fixture/.gitignore")
  Add-Content -LiteralPath "$fixture/.gitignore" -Value '!/_work/ai-sim-fixture/'
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-context'} 'Explicit raw include'
  [IO.File]::WriteAllBytes("$fixture/.gitignore",$ignoreBytes)
  Write-Output 'Simulation checkpoint: retained context, duplicate JSON and raw Git conflicts passed.'
  # SIM-03 follow-up: removed protection on a nonempty run needs a human ownership/policy decision.
  # Expected: fail closed without raw append or index change, preserve unrelated ignore.
  Set-Content -LiteralPath "$fixture/.gitignore" -Value '/unrelated-cache/'
  $indexBefore=(& git -C $fixture ls-files --stage) -join "`n"
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json' 'run-context'} 'Removed raw ignore protection'
  Assert-Condition (((& git -C $fixture ls-files --stage) -join "`n") -eq $indexBefore) 'Missing-protection rejection changed index.'
  Assert-Condition ((Get-Content -LiteralPath "$fixture/.gitignore" -Raw).Trim() -eq '/unrelated-cache/') 'Missing-protection rejection silently restored user policy.'
  [IO.File]::WriteAllBytes("$fixture/.gitignore",$ignoreBytes)
  # SIM-03 follow-up: restored exact protection permits an otherwise valid date-looking input.
  # Expected: preserve string bytes and keep unrelated Work paths versionable.
  Invoke-Simulation RecordCall 'call.json' 'run-context' | Out-Null
  & git -C $fixture check-ignore --quiet --no-index '_work/ai-sim-fixture/probe.json'
  Assert-Condition ($LASTEXITCODE -eq 0) 'Record did not restore exact work protection.'
  & git -C $fixture check-ignore --quiet --no-index '_work/unrelated/probe.json'
  Assert-Condition ($LASTEXITCODE -ne 0) 'Record restored an overbroad work ignore.'
  $dateFile=Get-ChildItem -LiteralPath "$fixture/_work/ai-sim-fixture/runs/run-context/calls" -File | Sort-Object Name | Select-Object -Last 1
  $dateRecord=[Text.Json.JsonDocument]::Parse((Get-Content -LiteralPath $dateFile.FullName -Raw))
  try { Assert-Condition ($dateRecord.RootElement.GetProperty('record').GetProperty('suppliedInput').GetProperty('currentInput').GetString() -ceq '2026-10-05T00:00:00Z') 'ISO-looking supplied input was date-coerced.' }
  finally {$dateRecord.Dispose()}
  # SIM-04: immutable snapshot tampering must prevent both status and new calls.
  # Expected: detected corruption, never a misleading complete/passing summary.
  $snapshots=@(Get-ChildItem -LiteralPath "$fixture/_work/ai-sim-fixture/runs/run-one" -File -Recurse | Where-Object {$_.Extension -eq '.md'})
  Assert-Condition ($snapshots.Count -gt 0) 'No frozen rule/prompt/context snapshots.'
  Add-Content -LiteralPath $snapshots[0].FullName -Value 'tampered'
  Assert-Rejected {Invoke-Simulation Status} 'Tampered snapshot status'
  Assert-Rejected {Invoke-Simulation RecordCall 'call.json'} 'Tampered snapshot new call'
  Write-Output 'AI simulation behavioral checks passed.'
} finally {
  # Delete only this exact resolved owned fixture beneath the OS temporary parent.
  $resolved=[IO.Path]::GetFullPath($fixture)
  Assert-Condition ((Split-Path -Parent $resolved).TrimEnd('\','/') -eq $tempParent -and (Split-Path -Leaf $resolved).StartsWith('codex-ai-simulation-test-')) 'Unsafe cleanup target.'
  if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
  Assert-Condition (-not(Test-Path -LiteralPath $resolved)) 'Simulation fixture cleanup failed.'
  Write-Output 'Isolated simulation fixture removed.'
}
