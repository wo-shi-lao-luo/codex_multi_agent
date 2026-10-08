# Public-command tests for documentation adoption, scoped readiness and change invalidation.
# Every write stays in a generated temporary project; no real installation or network is used.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$script=Join-Path $repo 'skills/team-core/scripts/documentation.ps1'
$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('/','\')
$sandbox=Join-Path $parent ('codex-doc-test-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
# Fail only for the expected contract error, rather than any incidental exception.
function Reject([scriptblock]$Run,[string]$Pattern) {
  try { & $Run | Out-Null } catch { if ($_.Exception.Message -notmatch $Pattern) { throw "Expected $Pattern; got $_" }; return }
  throw "Expected failure: $Pattern"
}
# A scoped review distinguishes read authority, unrelated references and required/not-applicable information.
function New-Review {
  $scan=& $script -Action Scan -ProjectRoot $sandbox | ConvertFrom-Json
  return @{
    schemaVersion=1; scope='login'; task='Add login'; outcome='ready'; summary='Login requirements and existing implementation were inspected.'
    documents=@($scan.documents | ForEach-Object {
      @{path=$_.path;category='requirements';lifecycle=if ($_.path -like 'docs/legacy/*') {'historical'} else {'active'};disposition=if ($_.path -like 'docs/legacy/*') {'historical'} else {'read'};reason='Inspected for this scope.';authority=if ($_.path -like 'docs/PRD/*') {'prd'} else {'supporting'}}
    }); dependencies=@('src/login.ts'); evidence=@('src/login.ts: observed baseline','user: approved login scope'); findings=@(); runnableWork=@('login')
    coverage=@('requirements','architecture','interfaces-data','ui-ux','runtime','testing-acceptance','security-migration' | ForEach-Object { @{category=$_;decision=if ($_ -eq 'requirements') {'required'} else {'not applicable'};reason='Bounded fixture scope; existing baseline is sufficient.';evidence=@('user: approved scope')} })
    report='# Login documentation review'+"`n`n"+'The PRD and current login baseline were read. No pending product decisions. Automated readiness is a freshness check, not proof of semantic quality.'
  }
}
# Supply authored evidence explicitly; the runtime does not infer requirements or resolve ambiguity.
function Record($Review) {
  $Review | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath "$sandbox/review-input.json" -Encoding utf8
  & $script -Action RecordReview -ProjectRoot $sandbox -ReviewInput 'review-input.json' | Out-Null
}
try {
  New-Item -ItemType Directory -Path "$sandbox/docs/PRD","$sandbox/docs/legacy","$sandbox/src" -Force | Out-Null
  Set-Content "$sandbox/docs/PRD/product.md" '# Login requirements'
  Set-Content "$sandbox/docs/legacy/old.md" '# Superseded login'
  Set-Content "$sandbox/src/login.ts" '// existing login'
  # Scenario: read-only discovery before adoption. Expected: no governance files or optional category folders.
  $scan=& $script -Action Scan -ProjectRoot $sandbox | ConvertFrom-Json
  # Scenario: the expanded checking contract is distributed. Expected: public discovery reports policy3.
  Assert ($scan.policyVersion -eq 3) 'Documentation.Policy3: expected checking policy3.'
  Assert ($scan.adopted -eq $false -and $scan.documents.Count -eq 2) 'Wrong discovery.'
  Assert (-not (Test-Path "$sandbox/docs/governance")) 'Scan wrote files.'
  # Scenario: first adoption. Expected: existing docs/source unchanged; marker alone is not ready.
  $baselineSource=Get-Content "$sandbox/src/login.ts" -Raw
  $baselinePrd=Get-Content "$sandbox/docs/PRD/product.md" -Raw
  $baselineLegacy=Get-Content "$sandbox/docs/legacy/old.md" -Raw
  # Scenario: an existing policy2 adoption has extra document paths and a published review.
  # Expected: policy3 marks it stale, then fresh assessment upgrades without losing configuration/history.
  New-Item -ItemType Directory -Path "$sandbox/notes","$sandbox/runtime" | Out-Null
  Set-Content "$sandbox/notes/extra.md" '# Extra inspected login notes'
  $currentScript=$script
  $legacyScript=Join-Path $sandbox 'runtime/documentation.ps1'
  $legacySource=(Get-Content -LiteralPath $currentScript -Raw).Replace(
    '$policyVersion = 3', '$policyVersion = 2'
  )
  Set-Content -LiteralPath $legacyScript -Value $legacySource -Encoding utf8
  Copy-Item -LiteralPath (Join-Path (Split-Path $currentScript) 'generated-artifacts.ps1') `
    -Destination "$sandbox/runtime/generated-artifacts.ps1"
  $script=$legacyScript
  & $script -Action Initialize -ProjectRoot $sandbox -AdditionalPaths 'notes' | Out-Null
  Assert ((Get-Content "$sandbox/docs/PRD/product.md" -Raw) -ceq $baselinePrd) 'Adoption changed PRD.'
  Assert ((Get-Content "$sandbox/docs/legacy/old.md" -Raw) -ceq $baselineLegacy) 'Adoption changed legacy docs.'
  Assert ((Get-Content "$sandbox/src/login.ts" -Raw) -ceq $baselineSource) 'Adoption changed source.'
  Assert (-not (Test-Path "$sandbox/docs/architecture")) 'Initialization imposed optional docs.'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'UNCHECKED'
  Reject { & $script -Action Initialize -ProjectRoot $sandbox } 'EXISTS'
  Record (New-Review)
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  $legacyState=Get-Content "$sandbox/docs/governance/documentation.json" -Raw | ConvertFrom-Json
  Assert ($legacyState.policyVersion -eq 2) 'Legacy fixture did not publish a policy2 assessment.'
  $legacyReportHash=(Get-FileHash "$sandbox/docs/governance/reviews/login.md").Hash
  $legacyRecordHash=(Get-FileHash "$sandbox/docs/governance/reviews/login.json").Hash
  $legacyIndexHash=(Get-FileHash "$sandbox/docs/governance/doc-index.md").Hash
  $script=$currentScript
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Assert ((Get-FileHash "$sandbox/docs/governance/reviews/login.md").Hash -eq $legacyReportHash) `
    'Stale validation changed the prior report.'
  Assert ((Get-FileHash "$sandbox/docs/governance/doc-index.md").Hash -eq $legacyIndexHash) `
    'Stale validation changed the navigation index.'
  Record (New-Review)
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  $freshState=Get-Content "$sandbox/docs/governance/documentation.json" -Raw | ConvertFrom-Json
  Assert ($freshState.policyVersion -eq 3 -and $freshState.schemaVersion -eq 1) `
    'Fresh review did not preserve schema1 while upgrading policy3.'
  Assert ($freshState.initializedAt -ceq $legacyState.initializedAt) 'Upgrade reset adoption.'
  Assert (($freshState.additionalPaths -join ',') -ceq 'notes') 'Upgrade reset AdditionalPaths.'
  $freshScan=& $script -Action Scan -ProjectRoot $sandbox | ConvertFrom-Json
  Assert ('notes/extra.md' -in $freshScan.documents.path) 'Configured extra document disappeared.'
  $archives=@(Get-ChildItem "$sandbox/docs/governance/reviews/archive" -File)
  Assert (@($archives | Where-Object {
    (Get-FileHash -LiteralPath $_.FullName).Hash -eq $legacyReportHash
  }).Count -eq 1) 'Legacy report bytes were not retained.'
  Assert (@($archives | Where-Object {
    (Get-FileHash -LiteralPath $_.FullName).Hash -eq $legacyRecordHash
  }).Count -eq 1) 'Legacy review record bytes were not retained.'
  # Scenario: higher-priority root instructions appear after review. Expected: inventory includes override, old review stale, bytes untouched.
  Set-Content "$sandbox/AGENTS.override.md" '# User-owned override policy'
  $overrideScan=& $script -Action Scan -ProjectRoot $sandbox | ConvertFrom-Json
  Assert (@($overrideScan.documents | Where-Object path -eq 'AGENTS.override.md').Count -eq 1) 'Root override not inventoried.'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Record (New-Review)
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  Set-Content "$sandbox/AGENTS.override.md" '# Changed override policy'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Assert ((Get-Content "$sandbox/AGENTS.override.md" -Raw).Trim() -eq '# Changed override policy') 'Runtime rewrote override policy.'
  Remove-Item -LiteralPath "$sandbox/AGENTS.override.md"
  Record (New-Review)
  # Scenario: a scoped chain review tracks an absent nested override. Expected: later creation invalidates even outside default doc inventory.
  New-Item -ItemType Directory -Path "$sandbox/app" | Out-Null
  $chainReview=New-Review; $chainReview.dependencies=@('src/login.ts','app/AGENTS.override.md')
  Record $chainReview
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  Set-Content "$sandbox/app/AGENTS.override.md" '# Newly effective nested rules'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Remove-Item -LiteralPath "$sandbox/app/AGENTS.override.md"
  Remove-Item -LiteralPath "$sandbox/app"
  Record (New-Review)
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Remove login' } 'STALE'
  # Scenario: an assessment is replaced after genuine re-review. Expected: retain previous report bytes outside current pointers.
  $initialReport=Get-ChildItem -LiteralPath "$sandbox/docs/governance/reviews" -File -Filter '*.md' | Select-Object -First 1
  $initialReportHash=(Get-FileHash -LiteralPath $initialReport.FullName -Algorithm SHA256).Hash
  Record (New-Review)
  $archivedReports=@(Get-ChildItem -LiteralPath "$sandbox/docs/governance/reviews/archive" -Recurse -File -Filter '*.md')
  Assert (@($archivedReports | Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $initialReportHash }).Count -gt 0) 'Previous assessment bytes not archived.'
  # Scenario: another scope is reviewed, then docs change and only login is reassessed. Expected: logout remains stale.
  $other=New-Review; $other.scope='logout'; $other.task='Audit logout'; $other.runnableWork=@('logout')
  Record $other
  # Scenario: new, changed, deleted docs or changed code baseline. Expected: each invalidates, never auto-clears.
  Set-Content "$sandbox/docs/new.md" 'New proposal'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  $scan=& $script -Action Scan -ProjectRoot $sandbox | ConvertFrom-Json
  Assert ('docs/new.md' -in $scan.added) 'New document not reported.'
  Record (New-Review)
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope logout -Task 'Audit logout' } 'STALE'
  Set-Content "$sandbox/docs/PRD/product.md" 'Changed product intent'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Record (New-Review)
  Remove-Item -LiteralPath "$sandbox/docs/new.md"
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Record (New-Review)
  Set-Content "$sandbox/src/login.ts" '// changed implementation'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Record (New-Review)
  # Scenario: unresolved ambiguity. Expected: cannot label ready or silently resolve; partial permits only disjoint work.
  $review=New-Review
  $review.findings=@(@{id='DOC-1';kind='ambiguous';severity='blocking';affectedWork=@('login');evidence=@('docs/PRD/product.md');question='Which timeout is intended?';recommendation='Keep the confirmed baseline.';resolution=@{state='pending';evidence=''}})
  Reject { Record $review } 'READINESS'
  $review.outcome='partial'; $review.runnableWork=@('styles')
  Record $review
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'BLOCKED'
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' -WorkItem styles | Out-Null
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' -WorkItem login } 'BLOCKED'
  # Scenario: a same-scope PRD/guide conflict remains pending; independent styling is approved.
  # Expected: ready cannot hide it, partial allows only styling and leaves both competing sources intact.
  Set-Content "$sandbox/docs/PRD/product.md" 'Login session timeout: 10 minutes in production.'
  Set-Content "$sandbox/notes/extra.md" 'Login session timeout: 30 minutes in production.'
  $review=New-Review
  $review.findings=@(@{
    id='DOC-CONFLICT';kind='conflict';severity='blocking';affectedWork=@('login')
    evidence=@('docs/PRD/product.md','notes/extra.md')
    question='Which login condition is intended under the same scope?'
    recommendation='Ask the user through Lead; preserve both claims until decided.'
    resolution=@{state='pending';evidence=''}
  })
  $conflictPrdHash=(Get-FileHash "$sandbox/docs/PRD/product.md").Hash
  $conflictGuideHash=(Get-FileHash "$sandbox/notes/extra.md").Hash
  Reject { Record $review } 'READINESS'
  $review.outcome='partial';$review.runnableWork=@('styles')
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' `
    -WorkItem styles | Out-Null
  Reject {
    & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' -WorkItem login
  } 'BLOCKED'
  Assert ((Get-FileHash "$sandbox/docs/PRD/product.md").Hash -eq $conflictPrdHash) `
    'Conflict publication changed the original PRD.'
  Assert ((Get-FileHash "$sandbox/notes/extra.md").Hash -eq $conflictGuideHash) `
    'Conflict publication changed the original guide.'
  # Scenario: a current PRD was never read. Expected: no ready claim, even when its category is present.
  $review=New-Review
  ($review.documents | Where-Object authority -eq prd).disposition='unavailable'
  Reject { Record $review } 'READINESS'
  # Scenario: PRD covers a different approved scope. Expected: explicit unrelated/reference classification can allow login.
  $review=New-Review
  $prd=$review.documents | Where-Object authority -eq prd
  $prd.authority='reference'; $prd.disposition='unrelated'; $prd.reason='Applies only to analytics; explicitly excluded from the approved login task.'
  $review.report+="`n`nPRD applicability: docs/PRD/product.md is analytics-only reference material and is unrelated to the confirmed login scope; it is not used as authority."
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  # Scenario: unread attachment is explicitly irrelevant. Expected: readiness can pass without pretending the attachment was read.
  Set-Content "$sandbox/docs/reference.pdf" 'Fixture attachment: no content reading is claimed.'
  $review=New-Review
  $attachment=$review.documents | Where-Object path -eq 'docs/reference.pdf'
  $attachment.category='reference'; $attachment.authority='reference'; $attachment.disposition='unavailable'; $attachment.applicability='unrelated'
  $attachment.reason='Unrelated to login; inaccessible reference retained in the inventory, never claimed as read.'
  $review.report+="`n`nUnread attachment: docs/reference.pdf is unrelated reference material; no dependency or requirement uses it."
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  # Scenario: the same unavailable attachment is required. Expected: partial requires a blocker naming the source and affected work.
  $attachment.applicability='applicable'; $attachment.reason='Login depends on this unavailable reference.'
  $review.outcome='partial'; $review.runnableWork=@('styles')
  Reject { Record $review } 'READINESS|REVIEW'
  $review.findings=@(@{id='DOC-3';kind='unavailable';severity='blocking';affectedWork=@('login');evidence=@('docs/reference.pdf');question='Can the login reference be supplied in readable form?';recommendation='Provide the reference before dependent login work.';resolution=@{state='pending';evidence=''}})
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' -WorkItem styles | Out-Null
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' -WorkItem login } 'BLOCKED'
  Remove-Item -LiteralPath "$sandbox/docs/reference.pdf"
  # Scenario: incomplete classification or information decisions. Expected: reject omitted inventory/category, not infer it.
  $review=New-Review
  $review.documents=@($review.documents | Where-Object path -notlike 'docs/legacy/*')
  Reject { Record $review } 'REVIEW'
  $review=New-Review
  $review.coverage=@($review.coverage | Where-Object category -ne 'architecture')
  Reject { Record $review } 'REVIEW'
  # Scenario: historical source claims current PRD authority. Expected: reject despite a read claim; preserve legacy bytes.
  $review=New-Review
  $historical=$review.documents | Where-Object path -like 'docs/legacy/*'
  $historical.lifecycle='active'; $historical.disposition='read'; $historical.authority='prd'
  Reject { Record $review } 'READINESS|REVIEW'
  Assert ((Get-Content "$sandbox/docs/legacy/old.md" -Raw).Trim() -eq '# Superseded login') 'Rejected review altered legacy docs.'
  # Scenario: ambiguous finding is labeled nonblocking. Expected: still block affected work instead of using severity as a bypass.
  $review=New-Review
  $review.findings=@(@{id='DOC-2';kind='ambiguous';severity='nonblocking';affectedWork=@('login');evidence=@('docs/PRD/product.md');question='Which login rule is intended?';recommendation='Ask user.';resolution=@{state='pending';evidence=''}})
  Reject { Record $review } 'READINESS|REVIEW'
  # Scenario: partial lists the blocked work, or resolution has no actual evidence. Expected: reject invalid readiness claims.
  $review.outcome='partial'; $review.runnableWork=@('login')
  Reject { Record $review } 'READINESS|REVIEW'
  $review.outcome='ready'; $review.findings[0].resolution.state='resolved'
  Reject { Record $review } 'READINESS|REVIEW'
  # Scenario: declared expected dependency is absent, then created. Expected: absent baseline can be recorded; creation invalidates it.
  $review=New-Review; $review.dependencies=@('src/login.ts','src/future.ts')
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  Set-Content "$sandbox/src/future.ts" '// newly introduced dependency'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Remove-Item -LiteralPath "$sandbox/src/future.ts"
  # Scenario: expected absent file becomes a directory. Expected: stale baseline rather than treating new shape as inspected.
  New-Item -ItemType Directory -Path "$sandbox/src/future.ts" | Out-Null
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Remove-Item -LiteralPath "$sandbox/src/future.ts"
  # Scenario: an inspected source file is deleted or replaced by a directory. Expected: stale, while a fresh actual-file review is publishable.
  $sourceBytes=[IO.File]::ReadAllBytes("$sandbox/src/login.ts")
  Remove-Item -LiteralPath "$sandbox/src/login.ts"
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  New-Item -ItemType Directory -Path "$sandbox/src/login.ts" | Out-Null
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Set-Content "$sandbox/src/replacement.ts" '// inspected replacement'
  $review=New-Review; $review.dependencies=@('src/replacement.ts')
  Record $review
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  Remove-Item -LiteralPath "$sandbox/src/login.ts"
  [IO.File]::WriteAllBytes("$sandbox/src/login.ts",$sourceBytes)
  Remove-Item -LiteralPath "$sandbox/src/replacement.ts"
  # Scenario: old rules or edited review metadata. Expected: re-review, never marker-only supervision claims.
  Record (New-Review)
  $statePath="$sandbox/docs/governance/documentation.json"
  $state=Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable
  $state.policyVersion=0
  $state | ConvertTo-Json -Depth 30 | Set-Content $statePath
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'STALE'
  Record (New-Review)
  $state=Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable
  $reportPath=Join-Path $sandbox $state.reviews.login.reportPath
  $reportBytes=[IO.File]::ReadAllBytes($reportPath)
  Add-Content $reportPath 'unreviewed edit'
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'REVIEW'
  # Scenario: a system-owned report was externally edited. Expected: re-recording refuses to overwrite that edit.
  Reject { Record (New-Review) } 'REVIEW'
  [IO.File]::WriteAllBytes($reportPath,$reportBytes)
  # Scenario: Kit provenance changes without a policy change. Expected: model/toolkit release alone does not force semantic re-review.
  Record (New-Review)
  $state=Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable
  $state.kitVersion='999.0.0'
  $state | ConvertTo-Json -Depth 30 | Set-Content $statePath
  & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' | Out-Null
  # Scenario: recorded report path escapes the repository. Expected: reject without creating or following an outside review.
  $state.reviews.login.reportPath='../outside.md'
  $state | ConvertTo-Json -Depth 30 | Set-Content $statePath
  Reject { & $script -Action Validate -ProjectRoot $sandbox -Scope login -Task 'Add login' } 'PATH|STATE|REVIEW'
  # Repair only the disposable malformed pointer from an explicitly preserved valid state for the remaining corruption checks.
  $state.reviews.login.reportPath='docs/governance/reviews/login.md'
  $state | ConvertTo-Json -Depth 30 | Set-Content $statePath
  # Scenario: doc discovery encounters a Windows junction. Expected: reject link traversal and leave its target intact.
  $junctionPath=Join-Path $sandbox 'docs/link'
  $junctionTarget=Join-Path $sandbox 'link-target'
  New-Item -ItemType Directory -Path $junctionTarget | Out-Null
  Set-Content (Join-Path $junctionTarget 'reference.md') 'Do not traverse this linked document.'
  try {
    New-Item -ItemType Junction -Path $junctionPath -Target $junctionTarget | Out-Null
    Reject { & $script -Action Scan -ProjectRoot $sandbox } 'PATH'
    Assert (Test-Path -LiteralPath (Join-Path $junctionTarget 'reference.md')) 'Scan changed the junction target.'
  } finally { if (Test-Path -LiteralPath $junctionPath) { Remove-Item -LiteralPath $junctionPath -Force } }
  # Scenario: traversal or malformed state. Expected: no writes outside project and no reset to assumed ownership.
  Reject { & $script -Action RecordReview -ProjectRoot $sandbox -ReviewInput '../outside.json' } 'PATH'
  Set-Content $statePath '{invalid'
  Reject { & $script -Action Scan -ProjectRoot $sandbox } 'STATE'
  Assert ((Get-Content "$sandbox/docs/legacy/old.md" -Raw).Trim() -eq '# Superseded login') 'Runtime altered legacy docs.'
  Write-Host 'Documentation tests passed.'
} finally {
  if (Test-Path -LiteralPath $sandbox) {
    $resolved=(Resolve-Path -LiteralPath $sandbox).Path
    if ((Split-Path -Parent $resolved) -ne $parent -or (Split-Path -Leaf $resolved) -notmatch '^codex-doc-test-[a-f0-9]{32}$') { throw 'Unsafe cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    if (Test-Path -LiteralPath $resolved) { throw 'Test cleanup failed.' }
    Write-Host 'Isolated documentation directory removed.'
  }
}
