# Exercise public Git protection against real disposable repositories. Production callers
# own artifact creation; these tests only create fixtures and inspect Git-visible outcomes.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly, [switch]$NestedWorkOnly, [switch]$BundleRedOnly, [switch]$BundleConflictOnly, [switch]$BundleCloneOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $repo 'skills/team-core/scripts/generated-artifacts.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$sandbox = Join-Path $tempParent ('codex-artifacts-test-' + [guid]::NewGuid().ToString('N'))
$priorGitGlobal = $env:GIT_CONFIG_GLOBAL
$priorGitSystem = $env:GIT_CONFIG_NOSYSTEM
$env:GIT_CONFIG_GLOBAL = '/dev/null'
$env:GIT_CONFIG_NOSYSTEM = '1'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
# Run Git only in owned disposable projects; native failures must not masquerade as passes.
function Git([string]$Root, [string[]]$Arguments) {
  $output = & git.exe -c core.excludesFile= -c core.hooksPath= -C $Root @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Git failed: $output" }
  return @($output | ForEach-Object { [string]$_ })
}
# Each file is fixture data, never a production source or an existing user artifact.
function Fixture([string]$Root, [string]$Path, [string]$Body = 'fixture') {
  $target = Join-Path $Root $Path
  New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
  [IO.File]::WriteAllText($target, $Body)
}
# A unique real repository lets staging prove which files ignore rules actually protect.
function New-Repo([string]$Name) {
  $root = Join-Path $sandbox $Name
  New-Item -ItemType Directory -Force $root | Out-Null
  Git $root @('init', '--quiet', '--template=') | Out-Null
  return $root
}
# Expected rejection must name its contract category and preserve evidence for diagnosis.
function Reject([scriptblock]$Run, [string]$Pattern) {
  try { & $Run | Out-Null } catch {
    Assert ($_.Exception.Message -match $Pattern) "Expected $Pattern, got $_"
    return
  }
  throw "Expected failure: $Pattern"
}
# CASE-GA-06d: an ancestor already protects a nested project's nonempty owned work tree.
# Expected: Protect reuses that exact effective policy with no parent or child ignore writes.
function Test-NestedWorkReuse {
  $root = New-Repo 'nested-work-reuse'
  $project = Join-Path $root 'nested'
  Fixture $root '.gitignore' "/nested/_work/task/`n"
  Fixture $project '_work/task/existing.png'
  $hash = (Get-FileHash "$root/.gitignore").Hash
  & $helper -Action Protect -ProjectRoot $project -Profile Work -WorkPath '_work/task' | Out-Null
  Assert ((Get-FileHash "$root/.gitignore").Hash -eq $hash -and -not (Test-Path "$project/.gitignore")) 'Nested Work reuse mutated ancestor/child policy.'
}
# Author a scoped review fixture from the real discovery result, including all required
# coverage decisions. The input stays outside the runtime-owned governance bundle.
function Write-ReviewInput([string]$Root) {
  $documentation = Join-Path $repo 'skills/team-core/scripts/documentation.ps1'
  $scan = & $documentation -Action Scan -ProjectRoot $Root | ConvertFrom-Json
  $review = @{
    schemaVersion=1; scope='fixture'; task='Protect generated review'; outcome='ready'; summary='Fixture requirement inspected.'
    documents=@($scan.documents | ForEach-Object { @{path=$_.path;category='requirements';lifecycle='active';disposition='read';reason='Fixture requirement read.';authority='prd'} })
    dependencies=@(); evidence=@('fixture: requirement read'); findings=@(); runnableWork=@('fixture')
    coverage=@('requirements','architecture','interfaces-data','ui-ux','runtime','testing-acceptance','security-migration' | ForEach-Object { @{category=$_;decision=if ($_ -eq 'requirements') {'required'} else {'not applicable'};reason='Bounded fixture; no product implementation.';evidence=@('fixture: inspected requirement')} })
    report='# Fixture review' + "`n" + 'Requirement was read; no ambiguity.'
  }
  Fixture $Root '_work/review-input.json' ($review | ConvertTo-Json -Depth 20)
}
# CASE-GA-14: every newly-local current bundle member is already staged or explicitly included.
# Expected: Check names the policy/index risk; Protect rejects before changing user bytes/index.
function Test-BundleConflicts {
  $ordinal = 0
  foreach ($path in @('docs/governance/reviews/current.md','docs/governance/documentation.json','docs/governance/doc-index.md')) {
    $ordinal++
    $root = New-Repo "tracked-bundle-$ordinal"
    Fixture $root $path
    Git $root @('add', '--all') | Out-Null
    $indexHash = (Get-FileHash "$root/.git/index").Hash
    $fileHash = (Get-FileHash (Join-Path $root $path)).Hash
    $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
    Assert (@($check.violations | Where-Object { $_.path -eq $path -and $_.reason -eq 'indexed-local-artifact' }).Count -gt 0) "CASE-GA-14: tracked current bundle risk omitted: $path"
    Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'ARTIFACTS'
    Assert ((Get-FileHash "$root/.git/index").Hash -eq $indexHash -and (Get-FileHash (Join-Path $root $path)).Hash -eq $fileHash -and -not (Test-Path "$root/.gitignore")) 'Tracked bundle rejection changed index/disk/policy.'

    # Parameter row: the same bundle member has a user-authored explicit include.
    # Expected: report explicit-include-policy and preserve its original ignore bytes.
    $root = New-Repo "included-bundle-$ordinal"
    Fixture $root '.gitignore' "!/$path`n"
    Fixture $root $path
    $ignoreHash = (Get-FileHash "$root/.gitignore").Hash
    $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
    Assert ($check.decisionRequired -and @($check.violations | Where-Object reason -eq 'explicit-include-policy').Count -gt 0) "CASE-GA-14: included current bundle policy omitted: $path"
    Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'ARTIFACTS'
    Assert ((Get-FileHash "$root/.gitignore").Hash -eq $ignoreHash) 'Included bundle user policy rewritten.'
  }
}
# CASE-GA-13: a no-network local clone contains durable source but no ignored runtime state.
# Expected: Scan is unadopted and read-only; initialize/scoped review recreates a valid local bundle.
function Test-BundleClone {
  $source = New-Repo 'bundle-clone-source'
  $documentation = Join-Path $repo 'skills/team-core/scripts/documentation.ps1'
  Fixture $source 'docs/PRD/product.md' '# Requirement'
  Fixture $source 'docs/governance/guide.md' '# User-authored governance guide'
  & $documentation -Action Initialize -ProjectRoot $source | Out-Null
  Write-ReviewInput $source
  & $documentation -Action RecordReview -ProjectRoot $source -ReviewInput '_work/review-input.json' | Out-Null
  Git $source @('add', '--all') | Out-Null
  Git $source @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'durable fixture') | Out-Null
  $clone = Join-Path $sandbox 'fresh local clone'
  Git $sandbox @('clone', '--quiet', '--template=', '--no-hardlinks', '--', $source, $clone) | Out-Null
  foreach ($path in @('docs/governance/documentation.json','docs/governance/doc-index.md','docs/governance/reviews')) {
    Assert (-not (Test-Path (Join-Path $clone $path))) "CASE-GA-13: local runtime state leaked into fresh clone: $path"
  }
  $ignoreHash = (Get-FileHash "$clone/.gitignore").Hash
  $scan = & $documentation -Action Scan -ProjectRoot $clone | ConvertFrom-Json
  Assert (-not $scan.adopted -and -not (Test-Path "$clone/docs/governance/documentation.json")) 'Fresh clone Scan inferred stale adoption or wrote state.'
  Assert ((Get-FileHash "$clone/.gitignore").Hash -eq $ignoreHash) 'Fresh clone Scan changed policy.'
  & $documentation -Action Initialize -ProjectRoot $clone | Out-Null
  Write-ReviewInput $clone
  & $documentation -Action RecordReview -ProjectRoot $clone -ReviewInput '_work/review-input.json' | Out-Null
  & $documentation -Action Validate -ProjectRoot $clone -Scope fixture -Task 'Protect generated review' | Out-Null
  foreach ($path in @('docs/governance/documentation.json','docs/governance/doc-index.md','docs/governance/reviews/fixture.json','docs/governance/reviews/fixture.md')) {
    Assert (Test-Path (Join-Path $clone $path)) "Fresh clone did not recreate local runtime state: $path"
  }
  Git $clone @('add', '--all') | Out-Null
  $indexed = Git $clone @('ls-files', '--cached')
  Assert (@($indexed | Where-Object { $_ -like 'docs/governance/reviews/*' -or $_ -in @('docs/governance/documentation.json','docs/governance/doc-index.md') }).Count -eq 0) 'Recreated clone runtime state entered index.'
  Assert ('docs/governance/guide.md' -in $indexed -and 'docs/PRD/product.md' -in $indexed) 'Clone lost durable user guidance or requirements.'
}
try {
  New-Item -ItemType Directory $sandbox | Out-Null
  if ($BundleCloneOnly) { Test-BundleClone; Write-Host 'PASS: CASE-GA-13 fresh local clone reconstruction.'; return }
  if ($BundleConflictOnly) { Test-BundleConflicts; Write-Host 'PASS: CASE-GA-14 runtime bundle conflicts.'; return }
  if ($BundleRedOnly) {
    # CASE-GA-12: real Initialize and RecordReview create the entire local runtime bundle.
    # Expected: ordinary staging omits marker, index and both current review records.
    $root = New-Repo 'red-local-bundle'
    $documentation = Join-Path $repo 'skills/team-core/scripts/documentation.ps1'
    Fixture $root 'docs/PRD/product.md' '# Requirement'
    & $documentation -Action Initialize -ProjectRoot $root | Out-Null
    Write-ReviewInput $root
    & $documentation -Action RecordReview -ProjectRoot $root -ReviewInput '_work/review-input.json' | Out-Null
    Git $root @('add', '--all') | Out-Null
    $staged = Git $root @('diff', '--cached', '--name-only')
    $local = @('docs/governance/documentation.json','docs/governance/doc-index.md','docs/governance/reviews/fixture.json','docs/governance/reviews/fixture.md')
    $leaked = @($local | Where-Object { $_ -in $staged })
    Assert ($leaked.Count -eq 0) "CASE-GA-12: approved local runtime bundle staged: $($leaked -join ', ')"
    return
  }
  if ($NestedWorkOnly) { Test-NestedWorkReuse; Write-Host 'PASS: CASE-GA-06d nested Work reuse.'; return }
  if ($RedOnly) {
    # CASE-GA-01 Red: existing documentation adoption precedes generated local output.
    # Expected: default protection keeps generated archive out of git add --all.
    $root = New-Repo 'red-default'
    & (Join-Path $repo 'skills/team-core/scripts/documentation.ps1') -Action Initialize -ProjectRoot $root | Out-Null
    Fixture $root 'docs/governance/reviews/archive/old.json'
    Git $root @('add', '--all') | Out-Null
    $staged = Git $root @('diff', '--cached', '--name-only')
    Assert ('docs/governance/reviews/archive/old.json' -notin $staged) 'CASE-GA-01: documentation default protection missing; generated archive was staged.'
    return
  }
  # CASE-GA-01: default profile protects generated archive and runtime controls.
  # Expected: git add --all omits the entire runtime bundle, keeping formal/user evidence.
  Assert (Test-Path -LiteralPath $helper) 'CASE-GA-01: public generated-artifacts helper is missing.'
  $root = New-Repo 'default'
  $protection = & $helper -Action Protect -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  Assert ($protection.schemaVersion -eq 1 -and $protection.status -eq 'protected' -and -not $protection.decisionRequired) 'Unexpected public protection receipt.'
  $local = @('docs/governance/reviews/archive/old.json', 'docs/governance/reviews/current.md', 'docs/governance/reviews/current.json', 'docs/governance/reviews/nested/any-output.png', 'docs/governance/documentation.json', 'docs/governance/doc-index.md', 'docs/governance/.documentation.lock', 'docs/governance/.pending.json', 'docs/governance/documentation.json.0123456789abcdef0123456789abcdef.tmp')
  $durable = @('docs/governance/guide.md', 'docs/governance/.lock', 'docs/governance/documentation.json.user.tmp', 'docs/architecture.md', 'docs/architecture/project-blueprint.md', 'docs/verification/active/stage.md', 'docs/verification/archive/accepted.md', 'docs/PRD/product.md', 'docs/legacy/reference.md', 'docs/images/diagram.png', 'openspec/specs/access/spec.md', 'archive/user.md', '_work/user.md')
  foreach ($path in @($local) + @($durable)) { Fixture $root $path }
  Git $root @('add', '--all') | Out-Null
  $staged = Git $root @('diff', '--cached', '--name-only')
  foreach ($path in $local) { Assert ($path -notin $staged) "Local output staged: $path" }
  foreach ($path in $durable) { Assert ($path -in $staged) "Durable evidence hidden: $path" }

  # CASE-GA-02: existing UTF8 BOM/CRLF rules and negations survive protection and repeat calls.
  # Expected: original bytes remain a prefix and the second Protect leaves the file byte-identical.
  $root = New-Repo 'encoding'
  $ignore = Join-Path $root '.gitignore'
  $original = [Text.UTF8Encoding]::new($true).GetPreamble() + [Text.Encoding]::UTF8.GetBytes("# 用户规则`r`n*.log`r`n!important.log`r`n")
  [IO.File]::WriteAllBytes($ignore, $original)
  & $helper -Action Protect -ProjectRoot $root -Profile Documentation | Out-Null
  $bytes = [IO.File]::ReadAllBytes($ignore)
  Assert ([Convert]::ToBase64String($bytes[0..($original.Length-1)]) -eq [Convert]::ToBase64String($original)) 'Existing ignore bytes changed.'
  $hash = (Get-FileHash $ignore).Hash
  & $helper -Action Protect -ProjectRoot $root -Profile Documentation | Out-Null
  Assert ((Get-FileHash $ignore).Hash -eq $hash) 'Protection is not idempotent.'

  # CASE-GA-03: project and configured docs live below the Git root and contain spaces.
  # Expected: exact nested runtime bundle is ignored; sibling project and formal docs stage.
  $root = New-Repo 'nested space'
  $project = Join-Path $root 'app space'
  New-Item -ItemType Directory $project | Out-Null
  & $helper -Action Protect -ProjectRoot $project -DocsRoot 'design docs' -Profile Documentation | Out-Null
  Assert ((Test-Path "$project/.gitignore") -and -not (Test-Path "$root/.gitignore")) 'Nested protection wrote ancestor instead of project ignore.'
  Fixture $root 'app space/design docs/governance/reviews/archive/old.md'
  Fixture $root 'app space/design docs/governance/reviews/current.md'
  Fixture $root 'app space/design docs/governance/documentation.json'
  Fixture $root 'app space/design docs/governance/doc-index.md'
  Fixture $root 'app space/design docs/governance/guide.md'
  Fixture $root 'other/design docs/governance/reviews/archive/user.md'
  Git $root @('add', '--all') | Out-Null
  $staged = Git $root @('diff', '--cached', '--name-only')
  Assert ('app space/design docs/governance/reviews/archive/old.md' -notin $staged) 'Nested custom docs not protected.'
  foreach ($path in @('app space/design docs/governance/reviews/current.md','app space/design docs/governance/documentation.json','app space/design docs/governance/doc-index.md')) { Assert ($path -notin $staged) "Nested runtime bundle staged: $path" }
  Assert ('app space/design docs/governance/guide.md' -in $staged -and 'other/design docs/governance/reviews/archive/user.md' -in $staged) 'Nested scope swallowed durable/sibling evidence.'

  # CASE-GA-03b: an ancestor repository explicitly includes a nested local artifact.
  # Expected: protection reports that policy and preserves parent bytes without child override.
  $root = New-Repo 'ancestor-include'
  $project = Join-Path $root 'nested'
  Fixture $root '.gitignore' "!/nested/docs/governance/reviews/archive/keep.json`n"
  Fixture $project 'docs/governance/reviews/archive/keep.json'
  $parentHash = (Get-FileHash "$root/.gitignore").Hash
  Reject { & $helper -Action Protect -ProjectRoot $project -Profile Documentation } 'ARTIFACTS'
  $check = & $helper -Action Check -ProjectRoot $project -Profile Documentation | ConvertFrom-Json
  Assert ($check.decisionRequired -and @($check.violations | Where-Object reason -eq 'explicit-include-policy').Count -gt 0) 'Ancestor include policy omitted.'
  Assert ((Get-FileHash "$root/.gitignore").Hash -eq $parentHash -and -not (Test-Path "$project/.gitignore")) 'Ancestor policy silently overridden.'

  # CASE-GA-04: an already staged artifact cannot be made safe by ignore rules.
  # Expected: Check reports the tracked/index risk and neither operation removes the staged file.
  $root = New-Repo 'tracked'
  Fixture $root 'docs/governance/reviews/archive/old.json'
  Git $root @('add', '--all') | Out-Null
  $index = Join-Path $root '.git/index'
  $indexHash = (Get-FileHash $index).Hash
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'ARTIFACTS'
  $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  Assert (($check | ConvertTo-Json -Depth 15) -match 'docs/governance/reviews/archive/old.json') 'Check omitted staged artifact risk.'
  Assert ((Get-FileHash $index).Hash -eq $indexHash) 'Protection/Check mutated Git index.'
  # CASE-GA-04b: user explicitly removes an artifact from the disposable index only.
  # Expected: cached deletion is not still treated as tracked; retained local bytes stay intact.
  Git $root @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture') | Out-Null
  $fileHash = (Get-FileHash "$root/docs/governance/reviews/archive/old.json").Hash
  Git $root @('rm', '--cached', 'docs/governance/reviews/archive/old.json') | Out-Null
  & $helper -Action Protect -ProjectRoot $root -Profile Documentation | Out-Null
  $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  Assert (-not $check.decisionRequired -and @($check.violations).Count -eq 0) 'Cached deletion incorrectly treated as tracked.'
  Assert ((Get-FileHash "$root/docs/governance/reviews/archive/old.json").Hash -eq $fileHash) 'Index-only removal changed local bytes.'

  # CASE-GA-05: no repository exists. Expected: no Git init and no ignore file is created.
  $root = Join-Path $sandbox 'nongit'
  New-Item -ItemType Directory $root | Out-Null
  $protection = & $helper -Action Protect -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  Assert ($protection.status -eq 'not-git' -and $check.status -eq 'not-git') 'Nonrepo status not explicit.'
  Assert (-not (Test-Path "$root/.git") -and -not (Test-Path "$root/.gitignore")) 'Nonrepo silently adopted.'

  # CASE-GA-05b: Git executable is unavailable to the public helper.
  # Expected: dependency failure is explicit and creates no ignore policy.
  $root = New-Repo 'missing-git'
  $priorPath = $env:PATH
  try {
    $env:PATH = ''
    Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'DEPENDENCY'
  } finally { $env:PATH = $priorPath }
  Assert (-not (Test-Path "$root/.gitignore")) 'Missing Git caused ignore mutation.'

  # CASE-GA-05c: metadata exists but points at a missing Git control directory.
  # Expected: reject broken Git rather than treating the project as safely unadopted.
  $root = Join-Path $sandbox 'broken-git'
  Fixture $root '.git' 'gitdir: missing-control-directory'
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'GIT'
  Reject { & $helper -Action Check -ProjectRoot $root -Profile Documentation } 'GIT'
  Assert (-not (Test-Path "$root/.gitignore")) 'Broken Git caused ignore mutation.'

  # CASE-GA-06: only the exact task-owned work subtree is protected.
  # Expected: user work and durable evidence stay stageable; unsafe traversal is rejected.
  $root = New-Repo 'work'
  & $helper -Action Protect -ProjectRoot $root -Profile Work -WorkPath '_work/generated-artifacts' | Out-Null
  Fixture $root '_work/generated-artifacts/render.png'
  Fixture $root '_work/user/reference.png'
  Git $root @('add', '--all') | Out-Null
  $staged = Git $root @('diff', '--cached', '--name-only')
  Assert ('_work/generated-artifacts/render.png' -notin $staged -and '_work/user/reference.png' -in $staged) 'Work ignore scope wrong.'
  $hash = (Get-FileHash "$root/.gitignore").Hash
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Work -WorkPath '../outside' } 'PATH|UNSAFE|outside|escape|relative'
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Work -WorkPath '_work' } 'PATH|UNSAFE|bounded|task|scope|ARTIFACTS'
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation -DocsRoot '../outside' } 'PATH|UNSAFE|outside|escape|relative'
  Assert ((Get-FileHash "$root/.gitignore").Hash -eq $hash) 'Rejected unsafe path changed ignore file.'

  # CASE-GA-06b: a nonempty work subtree has no existing ownership/protection policy.
  # Expected: request a decision before silently claiming or ignoring the existing files.
  $root = New-Repo 'uncertain-work'
  Fixture $root '_work/generated-artifacts/existing.png'
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Work -WorkPath '_work/generated-artifacts' } 'ARTIFACTS'
  Assert (-not (Test-Path "$root/.gitignore")) 'Uncertain Work ownership wrote policy.'
  # CASE-GA-06c: the user already protects that exact nonempty work subtree.
  # Expected: reuse the effective narrow rule without touching user policy bytes.
  Fixture $root '.gitignore' "/_work/generated-artifacts/`n"
  $hash = (Get-FileHash "$root/.gitignore").Hash
  & $helper -Action Protect -ProjectRoot $root -Profile Work -WorkPath '_work/generated-artifacts' | Out-Null
  Assert ((Get-FileHash "$root/.gitignore").Hash -eq $hash) 'Exact Work ignore reuse changed user bytes.'
  Test-NestedWorkReuse

  # CASE-GA-07: a child ignore file explicitly re-includes generated files.
  # Expected: Check reports the conflict instead of silently claiming full protection.
  $root = New-Repo 'conflict'
  Fixture $root 'docs/governance/reviews/.gitignore' "!archive/`n!archive/**`n"
  Fixture $root 'docs/governance/reviews/archive/old.md'
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'ARTIFACTS'
  $check = & $helper -Action Check -ProjectRoot $root -Profile Documentation | ConvertFrom-Json
  Assert ($check.decisionRequired -and @($check.violations).Count -gt 0) 'Child ignore override not reported.'
  Assert ((Get-Content "$root/docs/governance/reviews/.gitignore" -Raw) -eq "!archive/`n!archive/**`n") 'User child ignore rewritten.'

  # CASE-GA-08: Check inspects an existing repository without writing ignore or index bytes.
  # Expected: ignore policy, index and retained recovery output remain byte-identical on disk.
  $root = New-Repo 'readonly'
  Fixture $root 'docs/governance/.pending.json' 'recovery-evidence'
  Fixture $root '.gitignore' '# user only'
  Fixture $root 'source.txt'
  Git $root @('add', 'source.txt') | Out-Null
  $before = @((Get-FileHash "$root/.gitignore").Hash, (Get-FileHash "$root/.git/index").Hash, (Get-FileHash "$root/docs/governance/.pending.json").Hash)
  & $helper -Action Check -ProjectRoot $root -Profile Documentation | Out-Null
  $after = @((Get-FileHash "$root/.gitignore").Hash, (Get-FileHash "$root/.git/index").Hash, (Get-FileHash "$root/docs/governance/.pending.json").Hash)
  Assert (($before -join ',') -eq ($after -join ',')) 'Check wrote ignore, index or recovery artifact.'

  # CASE-GA-09a: real documentation lifecycle protects before creating/replacing a review.
  # Expected: repeated RecordReview retains all local bundle bytes; formal user records stage.
  $root = New-Repo 'doc-caller'
  $documentation = Join-Path $repo 'skills/team-core/scripts/documentation.ps1'
  Fixture $root 'docs/PRD/product.md' '# Requirement'
  Fixture $root 'docs/governance/guide.md' '# User-authored governance guide'
  # CASE-GA-09a invalid input: adoption is requested with an escaped extra source path.
  # Expected: reject before creating ignore rules or governance state.
  Reject { & $documentation -Action Initialize -ProjectRoot $root -AdditionalPaths '../outside' } 'PATH'
  Assert (-not (Test-Path "$root/.gitignore") -and -not (Test-Path "$root/docs/governance/documentation.json")) 'Invalid documentation input caused mutation.'
  $before = @(Get-ChildItem $root -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash $_.FullName).Hash }) -join ','
  & $documentation -Action Scan -ProjectRoot $root | Out-Null
  $after = @(Get-ChildItem $root -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash $_.FullName).Hash }) -join ','
  Assert ($before -eq $after -and -not (Test-Path "$root/.gitignore")) 'Unadopted Scan mutated repository.'
  & $documentation -Action Initialize -ProjectRoot $root | Out-Null
  Write-ReviewInput $root
  & $documentation -Action RecordReview -ProjectRoot $root -ReviewInput '_work/review-input.json' | Out-Null
  & $documentation -Action RecordReview -ProjectRoot $root -ReviewInput '_work/review-input.json' | Out-Null
  $archived = @(Get-ChildItem "$root/docs/governance/reviews/archive" -File)
  Assert ($archived.Count -ge 2) 'Repeated review did not retain historical evidence.'
  $before = @(Get-ChildItem $root -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash $_.FullName).Hash }) -join ','
  & $documentation -Action Scan -ProjectRoot $root | Out-Null
  & $documentation -Action Status -ProjectRoot $root | Out-Null
  & $documentation -Action Validate -ProjectRoot $root -Scope fixture -Task 'Protect generated review' | Out-Null
  $after = @(Get-ChildItem $root -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash $_.FullName).Hash }) -join ','
  Assert ($before -eq $after) 'Readonly documentation calls mutated files.'
  # Checkpoint: ordinary staging changes only the index; all generated local bytes survive.
  $bundleHashes = @{}
  foreach ($path in @('docs/governance/documentation.json','docs/governance/doc-index.md','docs/governance/reviews/fixture.json','docs/governance/reviews/fixture.md')) { $bundleHashes[$path] = (Get-FileHash (Join-Path $root $path)).Hash }
  Git $root @('add', '--all') | Out-Null
  $staged = Git $root @('diff', '--cached', '--name-only')
  Assert (@($staged | Where-Object { $_ -like 'docs/governance/reviews/*' -or $_ -in @('docs/governance/documentation.json','docs/governance/doc-index.md') }).Count -eq 0) 'Runtime-generated bundle staged.'
  Assert ('docs/PRD/product.md' -in $staged -and 'docs/governance/guide.md' -in $staged) 'Formal requirement or user governance guide hidden.'
  foreach ($path in $bundleHashes.Keys) { Assert ((Get-FileHash (Join-Path $root $path)).Hash -eq $bundleHashes[$path]) "Staging lost/changed local bundle bytes: $path" }

  # CASE-GA-09b: a linked worktree has a .git file rather than a metadata directory.
  # Expected: protection belongs to that checkout only and staged paths remain exact.
  $root = New-Repo 'main-worktree'
  Fixture $root 'source.txt'
  Git $root @('add', '--all') | Out-Null
  Git $root @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'fixture') | Out-Null
  $worktree = Join-Path $sandbox 'linked worktree'
  Git $root @('worktree', 'add', '--quiet', '--detach', $worktree) | Out-Null
  & $helper -Action Protect -ProjectRoot $worktree -Profile Documentation | Out-Null
  Fixture $worktree 'docs/governance/reviews/archive/old.md'
  Fixture $worktree 'docs/governance/reviews/current.md'
  Fixture $worktree 'docs/governance/documentation.json'
  Fixture $worktree 'docs/governance/doc-index.md'
  Fixture $worktree 'docs/governance/guide.md'
  Fixture $worktree 'docs/PRD/product.md'
  Git $worktree @('add', '--all') | Out-Null
  $staged = Git $worktree @('diff', '--cached', '--name-only')
  Assert ('docs/governance/reviews/archive/old.md' -notin $staged -and 'docs/PRD/product.md' -in $staged) 'Linked worktree protection failed.'
  foreach ($path in @('docs/governance/reviews/current.md','docs/governance/documentation.json','docs/governance/doc-index.md')) { Assert ($path -notin $staged) "Linked worktree bundle staged: $path" }
  Assert ('docs/governance/guide.md' -in $staged) 'Linked worktree user governance guide hidden.'
  Assert (-not (Test-Path "$root/.gitignore")) 'Linked worktree mutated main checkout.'

  # CASE-GA-09c: a docs directory is a junction into an external fixture directory.
  # Expected: reject the linked ancestor before writing ignore or target artifacts.
  $root = New-Repo 'linked-path'
  $outside = Join-Path $sandbox 'junction-target'
  New-Item -ItemType Directory $outside | Out-Null
  New-Item -ItemType Junction -Path "$root/docs" -Target $outside | Out-Null
  Reject { & $helper -Action Protect -ProjectRoot $root -Profile Documentation } 'PATH|linked|reparse|unsafe'
  Assert (-not (Test-Path "$root/.gitignore") -and @(Get-ChildItem $outside -Force).Count -eq 0) 'Linked path rejection wrote files.'
  Remove-Item -LiteralPath "$root/docs" -Force
  Test-BundleConflicts
  Test-BundleClone
  Write-Host 'PASS: generated artifact Git boundaries (CASE-GA-01..09,12..14).'
} finally {
  $env:GIT_CONFIG_GLOBAL = $priorGitGlobal
  $env:GIT_CONFIG_NOSYSTEM = $priorGitSystem
  # Delete only this invocation's verified disposable root; preserve all actual project files.
  $resolved = [IO.Path]::GetFullPath($sandbox)
  if ($resolved.StartsWith($tempParent.TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'codex-artifacts-test-*') {
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  } else { throw 'Refusing unsafe fixture cleanup.' }
}
