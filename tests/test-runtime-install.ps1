# Exercise full installation only in disposable homes, with an official offline archive.
# No scenario downloads a runtime or changes the user's Node installation.
#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RuntimeArchivePath,
  [switch]$RedOnly,
  [switch]$LifecycleOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repo 'scripts/install-user.ps1'
$prefix = 'codex-runtime-install-'
$sandbox = Join-Path (Get-TestTemporaryParent) ($prefix + [Guid]::NewGuid().ToString('N'))
$shell = Get-TestPowerShell

function Assert-RuntimeInstall([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# Bound each owned installer process and its descendants; preserve literal argv and child PATH.
function Invoke-RuntimeTestProcess(
  [string]$FilePath, [string[]]$ArgumentList, [hashtable]$Environment = @{}
) {
  if ($ArgumentList -contains $installer -or
      $ArgumentList -contains (Join-Path $repo 'scripts/update-user.ps1')) {
    $ArgumentList += @('-SourceRoot', $source)
  }
  $start = [Diagnostics.ProcessStartInfo]::new($FilePath)
  $start.UseShellExecute = $false
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
  foreach ($name in $Environment.Keys) { $start.Environment[$name] = $Environment[$name] }
  $process = [Diagnostics.Process]::Start($start)
  try {
    $process.StandardInput.Close()
    $out = $process.StandardOutput.ReadToEndAsync()
    $err = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(1200000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw 'TEST_TIMEOUT: owned runtime fixture child exceeded 1200 seconds.'
    }
    return @{ Exit = $process.ExitCode; Out = $out.GetAwaiter().GetResult();
      Error = $err.GetAwaiter().GetResult() }
  } finally { $process.Dispose() }
}

# Supply real UTF-8 stdin to the installed wrapper and independently drain both streams.
function Invoke-LauncherInput([string[]]$Arguments, [string]$Json) {
  $start = [Diagnostics.ProcessStartInfo]::new($shell)
  $start.UseShellExecute = $false
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::Start($start)
  try {
    $out = $process.StandardOutput.ReadToEndAsync()
    $err = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($Json)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(30000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw 'Installed launcher stdin operation timed out after 30 seconds.'
    }
    return @{ Exit = $process.ExitCode; Out = $out.GetAwaiter().GetResult();
      Error = $err.GetAwaiter().GetResult() }
  } finally { $process.Dispose() }
}

# RI01: the actual full installer must expose dependency provisioning and offline selection.
# Expected: absent wire fails before fixtures or homes exist (genuine preimplementation Red).
$parameters = (Get-Command $installer).Parameters
foreach ($name in @('SourceRoot', 'GitRef', 'RuntimeArchivePath', 'Offline')) {
  Assert-RuntimeInstall ($parameters.ContainsKey($name)) "RI01 installer missing parameter $name"
}
if ($RedOnly) { Write-Output 'RI01 installer provisioning wire present.'; return }
Assert-RuntimeInstall (Test-Path -LiteralPath $RuntimeArchivePath -PathType Leaf) `
  'An explicitly supplied official runtime archive is required; no downloads are permitted.'

try {
  [IO.Directory]::CreateDirectory($sandbox) | Out-Null
  # Keep the complete actual Board and its manifest-verified source inputs. Only unrelated
  # Skill/agent units are omitted; the existing install-user suite proves the full payload.
  $source = Join-Path $sandbox 'source'
  $manifest = Get-Content (Join-Path $repo 'skills/team-core/runtime/task-board/manifest.json') -Raw |
    ConvertFrom-Json
  $requiredFiles = @($manifest.inputs.path) + @('agents/team-tester.toml',
    'skills/team-core/SKILL.md', 'skills/team-core/scripts/board-runtime.ps1',
    'skills/team-core/scripts/task-board.ps1', 'skills/team-core/runtime/node-runtime.json')
  foreach ($relative in $requiredFiles) {
    $destination = Join-Path $source $relative
    [IO.Directory]::CreateDirectory((Split-Path $destination)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $destination
  }
  $boardDestination = Join-Path $source 'skills/team-core/runtime/task-board'
  Copy-Item -LiteralPath (Join-Path $repo 'skills/team-core/runtime/task-board') `
    -Destination $boardDestination -Recurse
  $lock = Get-Content (Join-Path $source 'skills/team-core/runtime/node-runtime.json') -Raw |
    ConvertFrom-Json
  $codex = Join-Path $sandbox 'codex'
  $agents = Join-Path $sandbox 'agents'
  $base = @('-NoProfile', '-File', $installer, '-CodexHome', $codex,
    '-AgentsHome', $agents, '-Offline', '-RuntimeArchivePath', $RuntimeArchivePath)

  if (-not $LifecycleOnly) {
    # RI02: preview with unavailable Node must remain read-only.
    # Expected: no new homes, cache or scratch files; archive is not consumed during preview.
    $before = Get-TestFingerprint -Root $sandbox
    $preview = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList ($base + '-WhatIf')
    Assert-RuntimeInstall ($preview.Exit -eq 0) "RI02 preview failed: $($preview.Error)"
    Assert-RuntimeInstall ((Get-TestFingerprint -Root $sandbox) -ceq $before) `
      'RI02 WhatIf wrote to the isolated tree.'
    Assert-RuntimeInstall (-not (Test-Path $agents) -and -not (Test-Path $codex)) `
      'RI02 WhatIf created empty installation directories.'
    }

  # RI03: a full offline install must provision a pinned runtime despite unsupported PATH Node.
  # Expected: explicit completion, committed payload, and an installed working launcher.
  $installed = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList $base
  Assert-RuntimeInstall ($installed.Exit -eq 0) "RI03 offline install failed: $($installed.Out) $($installed.Error)"
  Assert-RuntimeInstall ($installed.Out -match '"installationComplete"\s*:\s*true') `
    'RI03 full install did not explicitly report completion.'
  $launcher = Join-Path $agents 'skills/team-core/scripts/task-board.ps1'
  $doctor = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    $launcher, '-AgentsHome', $agents, 'runtime-doctor')
  $report = $doctor.Out | ConvertFrom-Json
  Assert-RuntimeInstall ($doctor.Exit -eq 0 -and $report.result.available -eq $true) `
    "RI03 installed launcher cannot use real SQLite: $($doctor.Out) $($doctor.Error)"

  if (-not $LifecycleOnly) {
    # RI03b: Unicode stdin survives the installed launcher and creates a real Board database.
    # Expected: initialization succeeds and the session identity hash preserves exact Unicode IDs.
    $project = Join-Path $sandbox '项目'
    [IO.Directory]::CreateDirectory($project) | Out-Null
    $inputJson = @{ actorId = 'lead'; leadToken = ('a' * 64); operationId = 'initialize' } |
      ConvertTo-Json -Compress
    $initialized = Invoke-LauncherInput -Arguments @('-NoProfile', '-File', $launcher,
      '-AgentsHome', $agents, 'initialize', '--project-root', $project,
      '--board-path', '_work/board', '--stdin') -Json $inputJson
    Assert-RuntimeInstall ($initialized.Exit -eq 0 -and
      (Test-Path -LiteralPath (Join-Path $project '_work/board/board.sqlite'))) `
      "RI03b installed stdin SQLite initialization failed: $($initialized.Out) $($initialized.Error)"
    $identity = @{ hostId = '测试主机'; mainSessionId = '会话甲'; projectId = '项目一' }
    $located = Invoke-LauncherInput -Arguments @('-NoProfile', '-File', $launcher,
      '-AgentsHome', $agents, 'session-path', '--stdin') `
      -Json ($identity | ConvertTo-Json -Compress)
    $parts = @('codex-board-context-v1', $identity.hostId, $identity.mainSessionId, $identity.projectId)
    $expectedKey = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
      [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $parts -Compress)))).ToLowerInvariant()
    Assert-RuntimeInstall ($located.Exit -eq 0 -and
      ($located.Out | ConvertFrom-Json).result.sessionKey -ceq $expectedKey) `
      "RI03b Unicode stdin changed during forwarding: $($located.Out) $($located.Error)"

    # RI04: a damaged archive must fail before changing an already usable installation.
    # Expected: all existing bytes retained, with no staging residue under fake homes.
    $badArchive = Join-Path $sandbox 'bad.zip'
    [IO.File]::WriteAllText($badArchive, 'invalid archive')
    $before = Get-TestFingerprint -Root $agents
    $failed = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
      $installer, '-CodexHome', (Join-Path $sandbox 'failed-codex'),
      '-AgentsHome', (Join-Path $sandbox 'failed-agents'), '-Offline',
      '-RuntimeArchivePath', $badArchive)
    Assert-RuntimeInstall ($failed.Exit -ne 0) 'RI04 corrupted runtime archive accepted.'
    Assert-RuntimeInstall (-not (Test-Path (Join-Path $sandbox 'failed-codex/agents'))) `
      'RI04 corrupted archive committed agent payload.'
    Assert-RuntimeInstall (-not (Test-Path (Join-Path $sandbox 'failed-agents/skills'))) `
      'RI04 corrupted archive committed Skill payload.'
    if (Test-Path (Join-Path $sandbox 'failed-agents')) {
      Assert-RuntimeInstall (@(Get-ChildItem (Join-Path $sandbox 'failed-agents') -Recurse -File).Count -eq 0) `
        'RI04 corrupted archive left receipt/runtime/scratch residue.'
    }
  Assert-RuntimeInstall ((Get-TestFingerprint -Root $agents) -ceq $before) `
    'RI04 archive failure changed the existing installation.'
  # RI08: the trusted offline engine rejects an incorrect source digest before payload writes.
  # Expected: explicit digest failure and no installed Skill directory.
  $digestFailure = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    (Join-Path $repo 'scripts/deploy-user.ps1'), '-Action', 'Deploy', '-SourceRoot', $source,
    '-CodexHome', (Join-Path $sandbox 'digest-codex'),
    '-AgentsHome', (Join-Path $sandbox 'digest-agents'), '-ExpectedPackageDigest', ('0' * 64))
  Assert-RuntimeInstall ($digestFailure.Exit -ne 0 -and
    ($digestFailure.Out + $digestFailure.Error) -match 'PACKAGE_CHANGED') `
    'RI08 source digest mismatch was not explicitly rejected.'
  Assert-RuntimeInstall (-not (Test-Path (Join-Path $sandbox 'digest-agents/skills'))) `
    'RI08 source digest mismatch committed payload.'

  # RI05: a real compatible selected runtime is reused without private provisioning.
  # Expected: offline full installation completes without node.exe in either selected home.
  $lock = Get-Content (Join-Path $repo 'skills/team-core/runtime/node-runtime.json') -Raw |
    ConvertFrom-Json
  $selectedDirectory = Join-Path $sandbox 'selected-runtime'
  [IO.Directory]::CreateDirectory($selectedDirectory) | Out-Null
  $selectedNode = Join-Path $selectedDirectory 'node.exe'
  $zip = [IO.Compression.ZipFile]::OpenRead($RuntimeArchivePath)
  try {
    $entry = $zip.GetEntry($lock.platforms.'win32-x64'.nodeMember)
    Assert-RuntimeInstall ($null -ne $entry) 'RI05 official Node archive member missing.'
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $selectedNode)
  } finally { $zip.Dispose() }
  $reuseAgents = Join-Path $sandbox 'reuse-agents'
  $reused = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    $installer, '-CodexHome', (Join-Path $sandbox 'reuse-codex'), '-AgentsHome', $reuseAgents,
    '-Offline') -Environment @{ PATH = "$selectedDirectory$([IO.Path]::PathSeparator)$env:PATH" }
  Assert-RuntimeInstall ($reused.Exit -eq 0) "RI05 compatible runtime reuse failed: $($reused.Out) $($reused.Error)"
  Assert-RuntimeInstall (@(Get-ChildItem $reuseAgents -Recurse -Filter node.exe -File).Count -eq 0) `
    'RI05 compatible selected runtime unnecessarily provisioned a private Node.'

  # RI07: missing offline inputs cannot silently turn the full installation into a minimal one.
  # Expected: failure before payload commit, with no runtime acquisition from the network.
  $offlineMissing = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile',
    '-File', $installer, '-CodexHome', (Join-Path $sandbox 'offline-codex'),
    '-AgentsHome', (Join-Path $sandbox 'offline-agents'), '-Offline')
  Assert-RuntimeInstall ($offlineMissing.Exit -ne 0) 'RI07 offline install silently skipped runtime.'
  Assert-RuntimeInstall (-not (Test-Path (Join-Path $sandbox 'offline-agents/skills'))) `
    'RI07 missing offline dependency committed payload.'
  }

  # RI06: update reuses the verified cache without requiring another archive.
  # Expected: full completion and the installed launcher remains usable after snapshot restore.
  $updated = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    (Join-Path $repo 'scripts/update-user.ps1'), '-CodexHome', $codex,
    '-AgentsHome', $agents, '-Offline')
  Assert-RuntimeInstall ($updated.Exit -eq 0) "RI06 cached update failed: $($updated.Out) $($updated.Error)"
  foreach ($action in @('MarkStable', 'Restore')) {
    $restored = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
      (Join-Path $repo 'scripts/deploy-user.ps1'), '-Action', $action,
      '-CodexHome', $codex, '-AgentsHome', $agents)
    Assert-RuntimeInstall ($restored.Exit -eq 0) "RI06 $action failed: $($restored.Out) $($restored.Error)"
  }
  $afterRestore = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList @('-NoProfile', '-File',
    $launcher, '-AgentsHome', $agents, 'runtime-doctor')
  Assert-RuntimeInstall ($afterRestore.Exit -eq 0 -and
    ($afterRestore.Out | ConvertFrom-Json).result.available) 'RI06 restored launcher unavailable.'

  # RI05b: private cache ownership is enforced even when Force is requested.
  # Expected: altered bytes are not executed, overwritten or accepted as a usable cache.
  $privateNode = Join-Path $agents 'codex-multi-agent/runtimes/node/26.13.0/win32-x64/node.exe'
  $runtimeReceipt = Join-Path (Split-Path $privateNode) 'runtime-receipt.json'
  $receipt = Get-Content $runtimeReceipt -Raw | ConvertFrom-Json
  Assert-RuntimeInstall ($receipt.archiveSha256 -ceq $lock.platforms.'win32-x64'.sha256) `
    'RI05b private runtime receipt lacks the pinned archive identity.'
  $originalBytes = [IO.File]::ReadAllBytes($privateNode)
  try {
    [IO.File]::WriteAllText($privateNode, 'tampered runtime')
    $tampered = Invoke-RuntimeTestProcess -FilePath $shell -ArgumentList ($base + '-Force')
    Assert-RuntimeInstall ($tampered.Exit -ne 0 -and
      ($tampered.Out + $tampered.Error) -match 'RUNTIME_CONFLICT') `
      'RI05b Force accepted or replaced a modified private runtime.'
    Assert-RuntimeInstall ([IO.File]::ReadAllText($privateNode) -ceq 'tampered runtime') `
      'RI05b failed private runtime check overwrote unmanaged bytes.'
  } finally { [IO.File]::WriteAllBytes($privateNode, $originalBytes) }
  if ($LifecycleOnly) {
    Write-Output 'RI03 prerequisite and RI06 lifecycle/RI05b tamper checks passed.'
  } else { Write-Output 'Runtime installation integration checks passed.' }
} finally {
  Remove-TestSandbox -Path $sandbox -Prefix $prefix
}
