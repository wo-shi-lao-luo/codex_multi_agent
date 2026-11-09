# Launch the installed Board using its private verified runtime; never download on launch.
# Remaining arguments and inherited streams belong to the Board, including stdin credentials.
#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$AgentsHome,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$BoardArguments
)
$ErrorActionPreference = 'Stop'
if (-not $AgentsHome) { $AgentsHome = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')) }
. (Join-Path $PSScriptRoot 'board-runtime.ps1')
try {
  $runtime = Resolve-BoardNode $AgentsHome
  if (-not $runtime) { throw 'RUNTIME_MISSING: Run the full Kit installer to prepare Board dependencies.' }
  $cli = Join-Path $PSScriptRoot '../runtime/task-board/src/cli/cli.mjs'
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $runtime.nodePath
  $info.UseShellExecute = $false
  $info.ArgumentList.Add([IO.Path]::GetFullPath($cli))
  foreach ($argument in $BoardArguments) { $info.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::Start($info)
  try { $process.WaitForExit(); $code=$process.ExitCode } finally { $process.Dispose() }
  exit $code
} catch { Write-Error $_; exit 1 }
