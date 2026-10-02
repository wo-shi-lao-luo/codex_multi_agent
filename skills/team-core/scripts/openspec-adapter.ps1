# Thin, opt-in CLI boundary. Never installs packages, imports upstream internals, or runs apply.
# Archive retains a local recovery snapshot on ambiguous/partial failure instead of retrying writes.
#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Doctor','Enable','Inspect','Prepare','Instructions','Validate','CloseCheck','Archive')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRoot,
  [ValidatePattern('^[a-z][a-z0-9-]{0,79}$')][string]$ChangeId,
  [ValidateSet('proposal','specs','design','tasks')][string]$Artifact = 'proposal',
  [string]$OpenSpecEntry,
  [ValidateRange(1,60)][int]$TimeoutSeconds = 60,
  [switch]$ConfirmArchive
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'openspec-common.ps1')
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$specRoot = Resolve-SpecPath $root 'openspec'
$marker = Resolve-SpecPath $root 'openspec/team-integration.json'
$enabled = Test-Path -LiteralPath $marker
if ($Action -eq 'Doctor' -and -not $enabled) {
  @{ enabled = $false; action = 'doctor'; reason = 'Explicit Enable required; no dependency probe performed.' } | ConvertTo-Json
  exit 0
}
if ($Action -ne 'Enable') { $null = Get-SpecIntegration $root }
elseif ($enabled) { throw 'ALREADY_ENABLED: Existing integration is not overwritten.' }
if ($Action -notin @('Enable','Doctor') -and -not $ChangeId) { throw 'CHANGE: ChangeId is required.' }

# Resolve the trusted npm entrypoint without executing a project-local shell shim or using npx.
# Callers may supply an explicit trusted installation path; project JSON never selects executable code.
if (-not $OpenSpecEntry) {
  $command = Get-Command openspec -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($command -and $command.Source) {
    $OpenSpecEntry = Join-Path (Split-Path -Parent $command.Source) 'node_modules/@fission-ai/openspec/bin/openspec.js'
  }
}
if (-not $OpenSpecEntry -or -not (Test-Path -LiteralPath $OpenSpecEntry -PathType Leaf)) { throw 'DEPENDENCY: Install trusted @fission-ai/openspec@1.13.2 separately, or supply -OpenSpecEntry.' }
$entry = (Resolve-Path -LiteralPath $OpenSpecEntry).Path
$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $node) { throw 'DEPENDENCY: Node.js 20.19+ is required by OpenSpec.' }

# Run fixed argument arrays in the exact project root. Separate stdout/stderr and bound execution;
# disabling telemetry is child-only and does not change any user-level configuration.
function Invoke-OpenSpec([string[]]$Arguments, [switch]$Text) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $node.Source
  $info.WorkingDirectory = $root
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.RedirectStandardInput = $true
  $info.ArgumentList.Add($entry)
  foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
  $info.Environment['OPENSPEC_TELEMETRY'] = '0'
  $info.Environment['DO_NOT_TRACK'] = '1'
  $info.Environment['CI'] = '1'
  $info.Environment['NO_COLOR'] = '1'
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $process.Kill($true); $process.WaitForExit()
      throw 'TIMEOUT: OpenSpec exceeded execution limit; inspect state before retrying a mutation.'
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errorText = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "UPSTREAM: OpenSpec exited $($process.ExitCode). $errorText $output" }
    if ($Text) { return $output.Trim() }
    try { $result = ConvertFrom-Json -InputObject $output -AsHashtable } catch { throw 'JSON: OpenSpec returned invalid JSON.' }
    if ($result -isnot [System.Collections.IDictionary]) { throw 'JSON: Expected an object response.' }
    return $result
  } finally { $process.Dispose() }
}
$version = Invoke-OpenSpec @('--version') -Text
if ($version -cne '1.13.2') { throw "VERSION: Expected OpenSpec 1.13.2; found $version. No automatic upgrade or fallback." }
if (Test-Path -LiteralPath (Resolve-SpecPath $root 'openspec/.team-recovery')) { throw 'RECOVERY: Inspect openspec/.team-recovery and reconcile interrupted archive before continuing.' }
$null = @(Get-SpecFiles $root 'openspec')

# The initial adapter supports an explicitly bounded native schema profile. Reject customization
# rather than silently forcing a different schema on an existing project.
$projectConfig = Resolve-SpecPath $root 'openspec/config.yaml'
if (Test-Path -LiteralPath $projectConfig) {
  $schemaLines = [regex]::Matches((Get-Content -LiteralPath $projectConfig -Raw), '(?m)^schema:[ \t]*([^\r\n]+)')
  if ($schemaLines.Count -ne 1 -or $schemaLines[0].Groups[1].Value.Trim() -notmatch '^[''\"]?spec-driven[''\"]?[ \t]*(#.*)?$') { throw 'SCHEMA: Existing config must explicitly select native spec-driven; review migration separately.' }
}
if (Test-Path -LiteralPath (Resolve-SpecPath $root 'openspec/schemas/spec-driven')) { throw 'SCHEMA: Project schema override is not supported; existing files were preserved.' }
$templates = Invoke-OpenSpec @('templates','--schema','spec-driven','--json')
foreach ($id in @('proposal','specs','design','tasks')) {
  if ($templates[$id].source -cne 'package') { throw 'SCHEMA: Expected upstream package templates, not global/project schema overrides.' }
}

if ($Action -eq 'Doctor') {
  @{ enabled = $true; action = 'doctor'; version = $version } | ConvertTo-Json
  exit 0
}
if ($Action -eq 'Enable') {
  # Explicit adoption adds no upstream Skills and never overwrites existing config or schema files.
  New-Item -ItemType Directory -Force $specRoot, "$specRoot/specs", "$specRoot/changes" | Out-Null
  $config = Resolve-SpecPath $root 'openspec/config.yaml'
  if (-not (Test-Path -LiteralPath $config)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../templates/openspec/config.yaml') -Destination $config
  }
  @{ schemaVersion = 1; enabled = $true; openSpecVersion = '1.13.2' } | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding utf8
  @{ action = 'enabled'; version = $version; existingConfigPreserved = $true } | ConvertTo-Json
  exit 0
}
$change = Resolve-SpecPath $root "openspec/changes/$ChangeId"
if ($Action -eq 'Prepare') {
  if (Test-Path -LiteralPath $change) { throw 'CHANGE: Existing change is not overwritten.' }
  Invoke-OpenSpec @('new','change',$ChangeId,'--schema','spec-driven','--json') | ConvertTo-Json -Depth 40
  exit 0
}
if (-not (Test-Path -LiteralPath $change -PathType Container)) { throw 'CHANGE: Active change does not exist; inspect archive instead of retrying.' }
$status = Invoke-OpenSpec @('status','--change',$ChangeId,'--json')
if ($status.schemaName -cne 'spec-driven' -or -not $status.Contains('artifacts')) { throw 'SCHEMA: v1 requires the native spec-driven schema; no custom schema is overwritten.' }
if ($status.root -and $status.root.path -and [IO.Path]::GetFullPath($status.root.path) -ne $root) { throw 'PATH: Upstream resolved a different project root.' }
if ($Action -eq 'Inspect') { $status | ConvertTo-Json -Depth 40; exit 0 }
if ($Action -eq 'Instructions') {
  Invoke-OpenSpec @('instructions',$Artifact,'--change',$ChangeId,'--json') | ConvertTo-Json -Depth 40
  exit 0
}

# Always retain native strict validation before applying our stronger evidence/acceptance gate.
$validation = Invoke-OpenSpec @('validate',$ChangeId,'--type','change','--strict','--json','--no-interactive')
$traceAction = if ($Action -eq 'Validate') { 'Validate' } else { 'CloseCheck' }
$trace = & (Join-Path $PSScriptRoot 'spec-traceability.ps1') -Action $traceAction -ProjectRoot $root -ChangeId $ChangeId | ConvertFrom-Json
if ($Action -ne 'Archive') {
  @{ action = $Action; upstream = $validation; traceability = $trace } | ConvertTo-Json -Depth 40
  exit 0
}
if (-not $ConfirmArchive) { throw 'APPROVAL: Archive requires explicit -ConfirmArchive after reviewing the close check.' }

# Only one kit archive can run at a time. External editors are not locked: callers must quiesce writers.
$lockPath = Resolve-SpecPath $root 'openspec/.team-archive.lock'
try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) } catch { throw 'LOCK: Another archive or stale lock exists; inspect before retrying.' }
$recovery = Resolve-SpecPath $root 'openspec/.team-recovery'
try {
  # Recheck after taking the lock; other kit archives may have changed the main specs.
  & (Join-Path $PSScriptRoot 'spec-traceability.ps1') -Action CloseCheck -ProjectRoot $root -ChangeId $ChangeId | Out-Null
  New-Item -ItemType Directory $recovery | Out-Null
  Copy-Item -LiteralPath "$specRoot/specs", "$specRoot/changes" -Destination $recovery -Recurse
  $archive = Invoke-OpenSpec @('archive',$ChangeId,'--yes','--json')
  $archived = @(Get-ChildItem -LiteralPath "$specRoot/changes/archive" -Directory | Where-Object Name -match ('^\d{4}-\d{2}-\d{2}-' + [regex]::Escape($ChangeId) + '$'))
  if ((Test-Path -LiteralPath $change) -or $archived.Count -ne 1) { throw 'ARCHIVE: Upstream completion could not be confirmed.' }
  # Successful upstream archive is verified on disk. Only our exact recovery directory is removed.
  $null = Resolve-SpecPath $root 'openspec/.team-recovery'
  Remove-Item -LiteralPath $recovery -Recurse -Force
  @{ action = 'archived'; changeId = $ChangeId; upstream = $archive; verificationPackets = 'Unchanged; archive separately and update their links.' } | ConvertTo-Json -Depth 40
} catch {
  if (Test-Path -LiteralPath $recovery) { throw "RECOVERY: Archive did not complete safely. Preserve current state and openspec/.team-recovery; no automatic rollback or retry. $($_.Exception.Message)" }
  throw
} finally {
  $lock.Dispose()
  Remove-Item -LiteralPath $lockPath -Force
}
