# Exercise the real read-only instruction discovery command in disposable targets.
# These checks prove filesystem/JSON behavior, not Agent authorization or live loading.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $repo 'skills/team-core/scripts/project-rules.ps1'
$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('/','\')
$sandbox=Join-Path $parent ('codex-project-rules-test-'+[guid]::NewGuid().ToString('N'))
# Assertion failures preserve the observable mismatch in runner output.
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
# Invoke only the production command, never execute discovered instructions/commands.
function Discover([hashtable]$Extra=@{}) { & $runtime -ProjectRoot $sandbox @Extra | ConvertFrom-Json }
# Accept only an actual contract rejection, not any unrelated exception.
function Reject([hashtable]$Extra,[string]$Pattern) {
  try { Discover $Extra | Out-Null } catch { if ($_.Exception.Message -notmatch $Pattern) { throw "Expected $Pattern; got $_" }; return }
  throw "Expected rejection: $Pattern"
}
# Record full disposable file/directory identity; discovery must not create, remove or edit files.
function Snapshot {
  @((Get-ChildItem -LiteralPath $sandbox -Recurse -Force | Sort-Object FullName) | ForEach-Object {
    $relative=[IO.Path]::GetRelativePath($sandbox,$_.FullName).Replace('\','/')
    if ($_.PSIsContainer) { "$relative/" } else { "$relative=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
  }) -join "`n"
}
try {
  New-Item -ItemType Directory -Path $sandbox | Out-Null
  # Scenario: blank target. Expected: no selected instructions, all root candidates tracked, no mutation or live-loading claim.
  $before=Snapshot
  $scan=Discover
  Assert ($scan.schemaVersion -eq 1 -and $scan.workingDirectory -eq '.' -and $scan.runtimeLoaded -eq 'unknown') 'Wrong default/loading contract.'
  Assert ($scan.selectedPaths.Count -eq 0 -and $scan.directories.Count -eq 1 -and $scan.totalSelectedBytes -eq 0) 'Blank target selection wrong.'
  Assert ($scan.dependencyPaths -contains 'AGENTS.override.md' -and $scan.dependencyPaths -contains 'AGENTS.md') 'Absent instruction dependencies missing.'
  Assert ((Snapshot) -ceq $before) 'Blank discovery wrote files.'

  # Scenario: user-owned root instructions. Expected: exact hash/size selected with unchanged bytes and no descendant recursion.
  [IO.File]::WriteAllText("$sandbox/AGENTS.md",'# User-owned rules',[Text.UTF8Encoding]::new($false))
  New-Item -ItemType Directory -Path "$sandbox/app/ui","$sandbox/unrelated" -Force | Out-Null
  Set-Content "$sandbox/unrelated/AGENTS.md" '# Unrelated subtree'
  $before=Snapshot; $scan=Discover
  Assert (($scan.selectedPaths -join ',') -ceq 'AGENTS.md') 'Root selection wrong.'
  $candidate=$scan.candidates | Where-Object path -eq 'AGENTS.md'
  Assert ($candidate.sha256 -eq (Get-FileHash "$sandbox/AGENTS.md").Hash -and $candidate.sizeBytes -eq (Get-Item "$sandbox/AGENTS.md").Length) 'Incorrect content provenance.'
  Assert ($scan.dependencyPaths -notcontains 'unrelated/AGENTS.md') 'Unrelated descendant traversed.'
  Assert ((Snapshot) -ceq $before) 'User-owned target mutated.'

  # Scenario: instruction text contains an executable-looking command. Expected: hash metadata only, no execution or leaked absolute project path/content.
  $inertCommand="Set-Content -LiteralPath '$sandbox/execution-marker.txt' UNTRUSTED"
  [IO.File]::WriteAllText("$sandbox/AGENTS.md",$inertCommand,[Text.UTF8Encoding]::new($false))
  $before=Snapshot; $scan=Discover
  $serialized=$scan | ConvertTo-Json -Depth 20
  Assert (-not (Test-Path "$sandbox/execution-marker.txt") -and (Snapshot) -ceq $before) 'Instruction contents executed or target mutated.'
  Assert (-not $serialized.Contains('UNTRUSTED') -and -not $serialized.Contains($sandbox) -and -not $serialized.Contains($sandbox.Replace('\','\\'))) 'Discovery leaked instruction content or private absolute path.'

  # Scenario: root override, whitespace nested override and explicit fallback. Expected: first nonempty per chain level; lower nonempty shadowed.
  Set-Content "$sandbox/AGENTS.override.md" '# Root override'
  Set-Content "$sandbox/app/AGENTS.override.md" '  '
  Set-Content "$sandbox/app/AGENTS.md" '# App rules'
  Set-Content "$sandbox/app/ui/TEAM.md" '# UI fallback'
  Set-Content "$sandbox/app/ui/OTHER.md" '# Lower fallback'
  $before=Snapshot
  $scan=Discover @{WorkingDirectory='app/ui';FallbackNames=@('TEAM.md','OTHER.md')}
  Assert (($scan.directories -join ',') -ceq '.,app,app/ui') 'Wrong root-to-working-directory chain.'
  Assert (($scan.selectedPaths -join ',') -ceq 'AGENTS.override.md,app/AGENTS.md,app/ui/TEAM.md') 'Wrong override/fallback precedence.'
  Assert (($scan.candidates | Where-Object path -eq 'AGENTS.md').status -eq 'shadowed') 'Root shadowing omitted.'
  Assert (($scan.candidates | Where-Object path -eq 'app/AGENTS.override.md').status -eq 'empty') 'Whitespace override selected.'
  Assert (($scan.candidates | Where-Object path -eq 'app/ui/OTHER.md').status -eq 'shadowed') 'Fallback shadowing omitted.'
  Assert ($scan.dependencyPaths.Count -eq 12 -and $scan.dependencyPaths -contains 'app/ui/AGENTS.override.md') 'Absent/shadowed dependencies missing.'
  Assert ((Snapshot) -ceq $before) 'Chain discovery mutated files.'

  # Scenario: byte limit exactly met then one byte exceeded. Expected: exact aggregate diagnostic, no false loading/truncation guarantee.
  $exact=$scan.totalSelectedBytes
  $fit=Discover @{WorkingDirectory='app/ui';FallbackNames=@('TEAM.md','OTHER.md');MaxBytes=$exact}
  $over=Discover @{WorkingDirectory='app/ui';FallbackNames=@('TEAM.md','OTHER.md');MaxBytes=($exact-1)}
  Assert (-not $fit.exceedsMaxBytes -and $over.exceedsMaxBytes -and $over.warnings.Count -gt 0) 'Byte-bound diagnosis incorrect.'
  Assert ($over.totalSelectedBytes -eq $exact -and $over.runtimeLoaded -eq 'unknown') 'Overflow fabricated loaded chain.'

  # Scenario: unsafe working directories/fallback filenames or invalid limit. Expected: contract rejection, target unchanged.
  $before=Snapshot
  foreach ($directory in @('../outside','app/../ui','app/./ui',"$sandbox/app",'.git','node_modules')) {
    Reject @{WorkingDirectory=$directory} 'PATH|directory|relative|excluded|unsafe|exist'
  }
  foreach ($fallback in @('../RULES.md','sub/RULES.md','C:/RULES.md','AGENTS.md','.env')) {
    Reject @{FallbackNames=@($fallback)} 'PATH|fallback|name|unsafe|duplicate|sensitive'
  }
  Reject @{FallbackNames=@('TEAM.md','team.md')} 'fallback|duplicate'
  Reject @{MaxBytes=0} 'MaxBytes|range|positive|validation'
  Assert ((Snapshot) -ceq $before) 'Rejected parameters mutated target.'

  # Scenario: an instruction candidate is a directory. Expected: reject, not classify a directory as absent text.
  Remove-Item -LiteralPath "$sandbox/app/AGENTS.override.md"
  New-Item -ItemType Directory -Path "$sandbox/app/AGENTS.override.md" | Out-Null
  Reject @{WorkingDirectory='app'} 'PATH|directory|file'
  Remove-Item -LiteralPath "$sandbox/app/AGENTS.override.md"

  # Scenario: malformed UTF8 instruction bytes. Expected: fail visibly instead of silently replacing bytes and certifying evidence.
  [IO.File]::WriteAllBytes("$sandbox/app/AGENTS.override.md",[byte[]]@(0xC3,0x28))
  Reject @{WorkingDirectory='app'} 'READ|UTF|decode|encoding'
  Remove-Item -LiteralPath "$sandbox/app/AGENTS.override.md"

  # Scenario: BOM-only override. Expected: treat as empty and select existing AGENTS.md.
  [IO.File]::WriteAllBytes("$sandbox/app/AGENTS.override.md",[byte[]]@(0xEF,0xBB,0xBF))
  $scan=Discover @{WorkingDirectory='app'}
  Assert (($scan.candidates | Where-Object path -eq 'app/AGENTS.override.md').status -eq 'empty') 'BOM-only file selected.'
  Assert ($scan.selectedPaths -contains 'app/AGENTS.md') 'BOM-only override blocked root candidate.'

  # Scenario: Windows junction in requested scope. Expected: reject traversal; preserve linked target bytes; never recurse into it.
  if ($IsWindows) {
    $link="$sandbox/linked-app"
    try {
      New-Item -ItemType Junction -Path $link -Target "$sandbox/app" | Out-Null
      Reject @{WorkingDirectory='linked-app'} 'PATH|reparse|link'
      Assert ((Get-Content "$sandbox/app/AGENTS.md" -Raw).Trim() -eq '# App rules') 'Linked target modified.'
    } finally { if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force } }

    # Scenario: junction target disappears. Expected: still reject the linked path rather than treat broken-link candidates as ordinary absence.
    $dangling="$sandbox/dangling-app"; $danglingTarget="$sandbox/dangling-target"
    try {
      New-Item -ItemType Directory -Path $danglingTarget | Out-Null
      New-Item -ItemType Junction -Path $dangling -Target $danglingTarget | Out-Null
      Remove-Item -LiteralPath $danglingTarget
      Reject @{WorkingDirectory='dangling-app'} 'PATH|reparse|link'
    } finally {
      if ($null -ne (Get-Item -LiteralPath $dangling -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $dangling -Force }
    }
  }
  Write-Host 'Project instruction discovery tests passed.'
} finally {
  if (Test-Path -LiteralPath $sandbox) {
    $resolved=(Resolve-Path -LiteralPath $sandbox).Path
    if ((Split-Path -Parent $resolved) -ne $parent -or (Split-Path -Leaf $resolved) -notmatch '^codex-project-rules-test-[a-f0-9]{32}$') { throw 'Unsafe cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    Assert (-not (Test-Path -LiteralPath $resolved)) 'Test cleanup failed.'
    Write-Host 'Isolated project instruction directory removed.'
  }
}
