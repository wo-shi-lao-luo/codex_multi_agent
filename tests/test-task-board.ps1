# Explicit opt-in task-board suite: selected trusted runtime only, never install/download dependencies.
# Preflight must pass before launching the real Node tests; default documentation suites do not call this.
#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$NodePath,
  [string[]]$TestFile,
  [string]$TestNamePattern
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$inventory = @(Get-ChildItem -LiteralPath (Join-Path $repo 'tests/task-board') `
  -Filter '*.test.mjs' -File | Sort-Object Name)
# Only inventory basenames may be selected; never interpret paths or wildcard expressions.
if ($TestFile.Count -gt 0) {
  $names = @($TestFile | ForEach-Object { $_ -split ',' } | Select-Object -Unique)
  foreach ($name in $names) {
    if ($name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.test\.mjs$' -or
        $name -cnotin $inventory.Name) {
      throw "TEST_SETUP: INVALID_TEST_FILE; select an existing tests/task-board basename."
    }
  }
  $inventory = @($inventory | Where-Object { $_.Name -cin $names })
}
foreach ($file in $inventory) {
  if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'TEST_SETUP: LINKED_TEST_FILE; selected test files must be ordinary files.'
  }
}
$files = @($inventory | Select-Object -ExpandProperty FullName)
if ($files.Count -eq 0) { throw 'TEST_SETUP: No task-board test files found.' }
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
# PowerShell native dispatch uses the selected repository location on every supported host.
# This keeps cwd-based Node fixtures correct when this wrapper is invoked from another directory.
$PSNativeCommandUseErrorActionPreference = $false
Push-Location $repo
try {
  $arguments = @('--test', '--test-concurrency=2')
  if ($TestNamePattern) { $arguments += @('--test-name-pattern', $TestNamePattern) }
  & $node.Source @($arguments + $files)
  $suiteExit = $LASTEXITCODE
} finally { Pop-Location }
exit $suiteExit
