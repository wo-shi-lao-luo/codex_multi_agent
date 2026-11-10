# Finite activation wrapper. Read JSON from stdin; never install or persist credentials.
#requires -Version 7.0
[CmdletBinding()]
param([string]$ProjectRoot, [string]$AgentsHome, [switch]$Help)
$ErrorActionPreference = 'Stop'
# Windows .NET 10 Process.Start inherits unrelated inheritable handles as well as its redirected
# streams. A detached descendant can retain this wrapper's outer capture pipes after we exit.
# Limit the change to current standard PIPE handles, and restore only their original inherit bits.
function Start-BoardActivationProcess([Diagnostics.ProcessStartInfo]$Info) {
  if (-not $IsWindows) { return [Diagnostics.Process]::Start($Info) }
  if (-not ('CodexBoardActivation.PipeHandles' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace CodexBoardActivation {
  public static class PipeHandles {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int selector);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint GetFileType(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetHandleInformation(IntPtr handle, out uint flags);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);
  }
}
'@
  }
  $restore = [Collections.Generic.List[object]]::new()
  $seen = [Collections.Generic.HashSet[long]]::new()
  try {
    foreach ($selector in @(-10, -11, -12)) {
      $handle = [CodexBoardActivation.PipeHandles]::GetStdHandle($selector)
      if ($handle -eq [IntPtr]::Zero -or $handle -eq [IntPtr]::new(-1)) { continue }
      if (-not $seen.Add($handle.ToInt64())) { continue }
      if ([CodexBoardActivation.PipeHandles]::GetFileType($handle) -ne 3) { continue }
      [uint32]$flags = 0
      if (-not [CodexBoardActivation.PipeHandles]::GetHandleInformation($handle, [ref]$flags)) {
        throw 'PIPE_ISOLATION_FAILED'
      }
      if (($flags -band 1) -eq 0) { continue }
      $restore.Add(@{ Handle = $handle; Inherit = ($flags -band 1) })
      if (-not [CodexBoardActivation.PipeHandles]::SetHandleInformation($handle, 1, 0)) {
        throw 'PIPE_ISOLATION_FAILED'
      }
    }
    return [Diagnostics.Process]::Start($Info)
  } finally {
    $failed = $false
    foreach ($saved in $restore) {
      if (-not [CodexBoardActivation.PipeHandles]::SetHandleInformation(
          $saved.Handle, 1, $saved.Inherit)) { $failed = $true }
    }
    if ($failed) { throw 'PIPE_ISOLATION_FAILED' }
  }
}
$phase = 'runtime'
try {
  if (-not $AgentsHome) { $AgentsHome = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')) }
  . (Join-Path $PSScriptRoot 'board-runtime.ps1')
  $runtime = Resolve-BoardNode $AgentsHome
  if (-not $runtime) { throw 'RUNTIME_MISSING' }
  $entry = Join-Path $PSScriptRoot '../runtime/task-board/src/cli/activation.mjs'
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $runtime.nodePath
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  if (-not $Help -and -not $ProjectRoot) { throw 'PROJECT_ROOT_REQUIRED' }
  $arguments = if ($Help) { @($entry, '--help') } else { @($entry, '--project-root', $ProjectRoot, '--stdin') }
  foreach ($argument in $arguments) {
    $info.ArgumentList.Add($argument)
  }
  $phase = 'input'
  $buffer = [char[]]::new(262145)
  $length = 0
  if (-not $Help) {
    while ($length -lt $buffer.Length) {
      $read = [Console]::In.Read($buffer, $length, $buffer.Length - $length)
      if ($read -eq 0) { break }
      $length += $read
    }
    if ($length -gt 262144) { throw 'INPUT_TOO_LARGE' }
  }
  $phase = 'launch'
  $child = Start-BoardActivationProcess $info
  try {
    $phase = 'execution'
    # The CLI emits one JSON line. Detached services can retain inherited handles on Windows;
    # waiting for pipe EOF would incorrectly join their lifetime to this finite wrapper.
    $stdout = $child.StandardOutput.ReadLineAsync()
    $stderr = $child.StandardError.ReadToEndAsync()
    if (-not $Help) {
      $child.StandardInput.Write($buffer, 0, $length)
    }
    $child.StandardInput.Close()
    if (-not $child.WaitForExit(120000)) {
      $child.Kill()
      $child.WaitForExit()
      throw 'ACTIVATION_TIMEOUT'
    }
    if (-not $stdout.IsCompleted) { throw 'ACTIVATION_RESPONSE_UNKNOWN' }
    [Console]::Out.WriteLine($stdout.GetAwaiter().GetResult())
    if ($stderr.IsCompletedSuccessfully) {
      [Console]::Error.Write($stderr.GetAwaiter().GetResult())
    }
    exit $child.ExitCode
  } finally { $child.Dispose() }
} catch {
  $safeReasons = @('INPUT_TOO_LARGE', 'ACTIVATION_TIMEOUT', 'ACTIVATION_RESPONSE_UNKNOWN',
    'PIPE_ISOLATION_FAILED', 'PROJECT_ROOT_REQUIRED')
  $reason = if ($_.Exception.Message -cin $safeReasons) { $_.Exception.Message }
    elseif ($phase -eq 'runtime') { 'RUNTIME_UNAVAILABLE' }
    elseif ($phase -eq 'launch') { 'PIPE_ISOLATION_FAILED' }
    else { 'ACTIVATION_OUTCOME_UNKNOWN' }
  @{schemaVersion=1;operation='activation';ok=$true;result=@{
    state='activation-pending';reasonCode=$reason;
    nextStep='Inspect the indicated prerequisite or retained activation outcome; do not reset or install automatically.'
  }} | ConvertTo-Json -Compress -Depth 4
}
