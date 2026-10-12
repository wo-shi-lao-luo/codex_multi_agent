# Test infrastructure only: keep disposable fixtures off macOS's verified system aliases.
# Runtime guards are tested through public commands, never replaced by these helpers.
function Get-TestTemporaryParent {
  $path = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if ($IsMacOS) {
    foreach ($alias in @('/tmp', '/var')) {
      if ($path -ceq $alias -or $path.StartsWith($alias + '/', [StringComparison]::Ordinal)) {
        $item = Get-Item -LiteralPath $alias -Force -ErrorAction Stop
        $expected = '/private' + $alias
        $targets = @($item.Target)
        if ($item.LinkType -cne 'SymbolicLink' -or $targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace($targets[0])) {
          throw "TEST_SETUP: Cannot verify macOS temporary-path alias $alias."
        }
        $target = [string]$targets[0]
        if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path ([IO.Path]::GetDirectoryName($alias)) $target }
        if ([IO.Path]::GetFullPath($target) -cne $expected) { throw "TEST_SETUP: Unexpected macOS temporary-path alias $alias." }
        $path = $expected + $path.Substring($alias.Length)
      }
    }
  }
  return $path.TrimEnd([char]'/', [char]'\')
}

function Get-TestPowerShell {
  # Reuse the exact running host rather than assuming pwsh.exe or a PATH entry.
  $executable = (Get-Process -Id $PID -ErrorAction Stop).Path
  if (-not $executable -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'TEST_SETUP: Cannot locate the running PowerShell executable.'
  }
  return $executable
}

function Invoke-TestPowerShell([string[]]$Arguments, [int]$TimeoutSeconds = 30) {
  # Exercise a genuine independent process, retaining the real exit status and errors.
  # The timeout applies only to this owned, bounded fixture child.
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = Get-TestPowerShell
  $info.UseShellExecute = $false
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive') + $Arguments) { $info.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw "TEST_TIMEOUT: Fixture child exceeded $TimeoutSeconds seconds."
    }
    return [pscustomobject]@{ExitCode=$process.ExitCode;Output=$stdout.GetAwaiter().GetResult();Errors=$stderr.GetAwaiter().GetResult()}
  } finally { $process.Dispose() }
}

function New-TestDirectoryLink([string]$Path, [string]$Target) {
  # Windows junctions avoid symbolic-link privileges; Unix uses real symbolic links.
  $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
  New-Item -ItemType $type -Path $Path -Target $Target -ErrorAction Stop | Out-Null
}

function Remove-TestLink([string]$Path) {
  # Get-Item observes dangling links which Test-Path can classify as missing.
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if ($null -ne $item) { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
}

function Test-CaseSensitiveFixture([string]$Root) {
  # Probe the actual fixture volume, not the OS name (macOS supports either mode).
  $lower = Join-Path $Root 'case-probe'
  $upper = Join-Path $Root 'CASE-PROBE'
  try {
    [IO.File]::WriteAllText($lower, 'owned test probe')
    return -not (Test-Path -LiteralPath $upper)
  } finally { Remove-Item -LiteralPath $lower -Force -ErrorAction Stop }
}
