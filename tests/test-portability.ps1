# Filesystem portability regressions through real public commands, using owned local fixtures.
# No provider calls, real installation, downloaded dependencies or live client sessions are used.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$parent = Get-TestTemporaryParent
$testRoot = Join-Path $parent ('codex-portability-test-' + [guid]::NewGuid().ToString('N') + ' space 中文')
$core = Join-Path $repo 'skills/team-core/scripts'
$blueprint = Join-Path $core 'project-blueprint.ps1'
$documentation = Join-Path $core 'documentation.ps1'
$commands = @(
  @{name='blueprint';script=$blueprint;link='docs';arguments=@{Action='Initialize'}},
  @{name='stage';script=(Join-Path $core 'stage-verification.ps1');link='docs';arguments=@{Action='Initialize';StageSlug='portability'}},
  @{name='documentation';script=$documentation;link='docs';arguments=@{Action='Scan'}},
  @{name='rules';script=(Join-Path $core 'project-rules.ps1');link='app';arguments=@{WorkingDirectory='app'}},
  @{name='openspec';script=(Join-Path $core 'openspec-adapter.ps1');link='openspec';arguments=@{Action='Doctor'}}
)
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Reject([scriptblock]$Run, [string]$Pattern) {
  # Require the intended boundary rejection, not a missing executable or arbitrary exception.
  try { & $Run | Out-Null } catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw "Expected $Pattern; got $_" }
    return
  }
  throw "Expected rejection: $Pattern"
}
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  $sensitive = Test-CaseSensitiveFixture $testRoot
  Write-Host "Fixture filesystem is case-sensitive: $sensitive"
  if ($sensitive) {
    # Scenario: traversal reaches a sibling whose name differs only by case.
    # Expected: initialization refuses before creating a file outside the selected root.
    $selected = Join-Path $testRoot 'case-root'
    $sibling = Join-Path $testRoot 'CASE-ROOT'
    New-Item -ItemType Directory -Path $selected,$sibling | Out-Null
    Reject { & $blueprint -Action Initialize -ProjectRoot $selected -BlueprintPath '../CASE-ROOT/escape.md' } 'PATH|inside|relative|unsafe'
    Assert (-not (Test-Path -LiteralPath "$sibling/escape.md")) 'Case-distinct traversal wrote outside ProjectRoot.'
    # Scenario: documents differing only by case are real independent files.
    # Expected: both are inventoried and later removal/change/addition remain distinct.
    $caseDocs = Join-Path $testRoot 'case-documents'
    New-Item -ItemType Directory -Path "$caseDocs/docs" | Out-Null
    Set-Content -LiteralPath "$caseDocs/docs/Guide.md" -Value 'Uppercase document'
    Set-Content -LiteralPath "$caseDocs/docs/guide.md" -Value 'Lowercase document'
    $scan = & $documentation -Action Scan -ProjectRoot $caseDocs | ConvertFrom-Json
    Assert ($scan.documents.Count -eq 2 -and $scan.documents.path -ccontains 'docs/Guide.md' -and $scan.documents.path -ccontains 'docs/guide.md') 'Case-distinct document inventory lost a file.'
    & $documentation -Action Initialize -ProjectRoot $caseDocs | Out-Null
    Set-Content -LiteralPath "$caseDocs/docs/guide.md" -Value 'Changed lowercase document'
    Remove-Item -LiteralPath "$caseDocs/docs/Guide.md"
    Set-Content -LiteralPath "$caseDocs/docs/third.md" -Value 'Added document'
    $scan = & $documentation -Action Scan -ProjectRoot $caseDocs | ConvertFrom-Json
    Assert ($scan.removed.Count -eq 1 -and $scan.removed -ccontains 'docs/Guide.md') 'Case-distinct removed document was not tracked.'
    Assert ($scan.changed.Count -eq 1 -and $scan.changed -ccontains 'docs/guide.md') 'Case-distinct changed document was not tracked.'
    Assert ($scan.added.Count -eq 1 -and $scan.added -ccontains 'docs/third.md') 'Added document was not tracked.'
    # Scenario: the local OpenSpec evidence snapshot contains case-distinct specification files.
    # Expected: both identities survive and modifying one does not hide or invalidate the other's hash.
    . (Join-Path $core 'openspec-common.ps1')
    $caseSpecs = Join-Path $testRoot 'case-specifications'
    New-Item -ItemType Directory -Path "$caseSpecs/openspec/specs" -Force | Out-Null
    Set-Content -LiteralPath "$caseSpecs/openspec/specs/Guide.md" -Value 'Uppercase specification'
    Set-Content -LiteralPath "$caseSpecs/openspec/specs/guide.md" -Value 'Lowercase specification'
    $before = Get-SpecSnapshot $caseSpecs 'portability'
    Assert ($before.Contains('openspec/specs/Guide.md') -and $before.Contains('openspec/specs/guide.md')) 'OpenSpec snapshot lost a case-distinct file.'
    Set-Content -LiteralPath "$caseSpecs/openspec/specs/Guide.md" -Value 'Changed uppercase specification'
    $after = Get-SpecSnapshot $caseSpecs 'portability'
    Assert ($before['openspec/specs/Guide.md'] -cne $after['openspec/specs/Guide.md']) 'OpenSpec snapshot missed the uppercase file change.'
    Assert ($before['openspec/specs/guide.md'] -ceq $after['openspec/specs/guide.md']) 'OpenSpec snapshot merged distinct file hashes.'
  } else { Write-Host 'NOT APPLICABLE: Case-distinct sibling/document scenarios require a case-sensitive fixture volume.' }

  foreach ($entry in $commands) {
    # Scenario: normal paths include spaces and Unicode. Expected: commands operate on the exact root.
    $project = Join-Path $testRoot ($entry.name + ' plain 中文')
    New-Item -ItemType Directory -Path $project | Out-Null
    if ($entry.name -eq 'rules') { New-Item -ItemType Directory -Path "$project/app" | Out-Null }
    $arguments = $entry.arguments.Clone()
    & $entry.script -ProjectRoot $project @arguments | Out-Null

    # Scenario: an explicitly selected project root is an arbitrary link.
    # Expected: reject it; only the separately tested macOS system aliases are permitted.
    $rootLink = Join-Path $testRoot ($entry.name + '-root-link')
    try {
      New-TestDirectoryLink -Path $rootLink -Target $project
      Reject { & $entry.script -ProjectRoot $rootLink @arguments } 'PATH|[Ll]ink'
    } finally { Remove-TestLink $rootLink }

    # Scenario: command defaults reach a linked descendant, then the link becomes dangling.
    # Expected: both reject without writing through the link or creating a missing target.
    $linkedProject = Join-Path $testRoot ($entry.name + '-linked-project')
    $target = Join-Path $testRoot ($entry.name + '-external-target')
    New-Item -ItemType Directory -Path $linkedProject,$target | Out-Null
    Set-Content -LiteralPath "$target/preserve.txt" -Value 'preserve linked target bytes'
    $link = Join-Path $linkedProject $entry.link
    try {
      New-TestDirectoryLink -Path $link -Target $target
      Reject { & $entry.script -ProjectRoot $linkedProject @arguments } 'PATH|[Ll]ink'
      Assert ((Get-Content -LiteralPath "$target/preserve.txt" -Raw).Trim() -eq 'preserve linked target bytes') "$($entry.name) modified a linked target."
      Assert (@(Get-ChildItem -LiteralPath $target -Force).Count -eq 1) "$($entry.name) wrote through a linked descendant."
      Remove-Item -LiteralPath $target -Recurse -Force
      Reject { & $entry.script -ProjectRoot $linkedProject @arguments } 'PATH|[Ll]ink'
      Assert (-not (Test-Path -LiteralPath $target)) "$($entry.name) recreated a dangling target."
    } finally { Remove-TestLink $link }
  }

  if (-not $IsWindows) {
    # Scenario: an ordinary Unix user cannot create files inside an owned read-only directory.
    # Expected: blueprint initialization reports access failure and preserves existing contents.
    # Probe enforcement first: privileged users/volumes that ignore modes do not establish this case.
    $chmod = Get-Command chmod -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($chmod) {
      $permissionRoot = Join-Path $testRoot 'permission-project'
      New-Item -ItemType Directory -Path $permissionRoot | Out-Null
      Set-Content -LiteralPath "$permissionRoot/preserve.txt" -Value 'preserve read-only root'
      & $chmod.Source '700' $permissionRoot
      Assert ($LASTEXITCODE -eq 0) 'Cannot establish owned permission fixture.'
      try {
        & $chmod.Source '500' $permissionRoot
        Assert ($LASTEXITCODE -eq 0) 'Cannot make permission fixture read-only.'
        $denied = $false
        $probe = Join-Path $permissionRoot 'write-probe'
        try { [IO.File]::WriteAllText($probe, 'owned permission probe') }
        catch [UnauthorizedAccessException] { $denied = $true }
        if ($denied) {
          Reject { & $blueprint -Action Initialize -ProjectRoot $permissionRoot } 'denied|[Aa]ccess|[Pp]ermission|[Uu]nauthorized'
          Assert (-not (Test-Path -LiteralPath "$permissionRoot/docs")) 'Denied initialization left a blueprint directory.'
          Assert ((Get-Content -LiteralPath "$permissionRoot/preserve.txt" -Raw).Trim() -eq 'preserve read-only root') 'Denied initialization altered existing content.'
        } else {
          Write-Host 'NOT APPLICABLE: This identity or filesystem bypasses Unix write modes; permission-denial behavior was not exercised.'
        }
      } finally {
        # Always restore the owned fixture before the suite's recursive cleanup, including on failure.
        & $chmod.Source '700' $permissionRoot
        Assert ($LASTEXITCODE -eq 0) 'Cannot restore permission fixture for cleanup.'
      }
    } else { Write-Host 'NOT APPLICABLE: chmod is unavailable; Unix permission-denial behavior was not exercised.' }
  } else { Write-Host 'NOT APPLICABLE: Unix permission-mode scenario is not a Windows ACL test.' }

  if ($IsMacOS) {
    # Scenario: normal macOS /var or /tmp spelling selects an existing physical fixture.
    # Expected: verified system aliases work for every public helper, with the same owned bytes.
    $aliasRoot = $null
    foreach ($alias in @('/var','/tmp')) {
      $physical = '/private' + $alias
      if ($testRoot.StartsWith($physical + '/', [StringComparison]::Ordinal)) { $aliasRoot = $alias + $testRoot.Substring($physical.Length) }
    }
    if ($aliasRoot) {
      foreach ($entry in $commands) {
        $physicalProject = Join-Path $testRoot ($entry.name + '-system-alias')
        $aliasProject = Join-Path $aliasRoot ($entry.name + '-system-alias')
        New-Item -ItemType Directory -Path $physicalProject | Out-Null
        if ($entry.name -eq 'rules') { New-Item -ItemType Directory -Path "$physicalProject/app" | Out-Null }
        $arguments = $entry.arguments.Clone()
        & $entry.script -ProjectRoot $aliasProject @arguments | Out-Null
        Assert (Test-Path -LiteralPath $physicalProject -PathType Container) 'System alias did not select the physical fixture.'
      }
    } else { Write-Host 'NOT APPLICABLE: Current macOS temporary directory does not use /var or /tmp; system-alias cases were not exercised.' }
  } else { Write-Host 'NOT APPLICABLE: Verified /var and /tmp system-alias scenarios are macOS-specific.' }
  Write-Host 'Filesystem portability tests passed.'
} finally {
  $resolved = [IO.Path]::GetFullPath($testRoot)
  if ((Split-Path -Parent $resolved) -cne $parent -or (Split-Path -Leaf $resolved) -notmatch '^codex-portability-test-[a-f0-9]{32} space 中文$') { throw 'Unsafe portability fixture cleanup target.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert (-not (Test-Path -LiteralPath $resolved)) 'Portability fixture cleanup failed.'
  Write-Host 'Isolated portability directory removed.'
}
