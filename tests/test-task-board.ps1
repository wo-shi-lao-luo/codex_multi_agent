# Explicit opt-in task-board suite: selected trusted runtime only, never install/download dependencies.
# Preflight must pass before launching the real Node tests; default documentation suites do not call this.
#requires -Version 7.0
[CmdletBinding()]
param([string]$NodePath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$selected = if ($NodePath) { $NodePath } else { 'node' }
$node = Get-Command $selected -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $node) { throw 'TEST_SETUP: NODE_MISSING; select an installed trusted runtime with -NodePath.' }
$doctor = Invoke-TestProcess -FilePath $node.Source -ArgumentList @(
  (Join-Path $repo 'packages/task-board/src/cli/cli.mjs'), 'runtime-doctor'
)
try { $reply = $doctor.Out | ConvertFrom-Json } catch { throw 'TEST_SETUP: Runtime doctor did not return valid JSON.' }
if ($doctor.Exit -ne 0 -or $reply.ok -ne $true -or $reply.result.available -ne $true) {
  throw "TEST_SETUP: $($reply.result.reasonCode); task-board runtime requirements are not met."
}
$files = @(Get-ChildItem -LiteralPath (Join-Path $repo 'tests/task-board') -Filter '*.test.mjs' -File |
  Sort-Object Name | Select-Object -ExpandProperty FullName)
if ($files.Count -eq 0) { throw 'TEST_SETUP: No task-board test files found.' }
# PowerShell native dispatch uses the selected repository location on every supported host.
# This keeps cwd-based Node fixtures correct when this wrapper is invoked from another directory.
$PSNativeCommandUseErrorActionPreference = $false
Push-Location $repo
try {
  & $node.Source @(@('--test', '--test-concurrency=2') + $files)
  $suiteExit = $LASTEXITCODE
} finally { Pop-Location }
exit $suiteExit
