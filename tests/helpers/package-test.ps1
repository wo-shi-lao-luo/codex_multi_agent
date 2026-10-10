# Shared transport and filesystem mechanisms for isolated package tests.
# Callers own scenarios, assertions, environment policy and final payload proofs.
#requires -Version 7.0

# Run literal argv with independently drained pipes and caller-selected child env.
# Return exit/stdout/stderr unchanged; launch errors throw and parent env is untouched.
function Invoke-TestProcess {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [hashtable]$Environment = @{}
  )
  $start = [Diagnostics.ProcessStartInfo]::new($FilePath)
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
  foreach ($name in $Environment.Keys) { $start.Environment[$name] = $Environment[$name] }
  $process = [Diagnostics.Process]::Start($start)
  try {
    # Drain both pipes concurrently so either stream may exceed its pipe buffer.
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [pscustomobject]@{
      Exit = $process.ExitCode
      Out = $stdout.GetAwaiter().GetResult()
      Error = $stderr.GetAwaiter().GetResult()
    }
  } finally {
    $process.Dispose()
  }
}

# Copy exact package bytes with an explicit config choice and existing docs boundary.
# Narrow copies only formatter link dependencies; PublicDocs excludes local history
# and governance. Reject overlapping roots before creating or copying any files.
function Copy-TestPackage {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$DestinationRoot,
    [Parameter(Mandatory)][ValidateSet('Narrow', 'PublicDocs')][string]$Profile,
    [Parameter(Mandatory)][bool]$IncludeConfig
  )
  $source = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/')
  $destination = [IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\', '/')
  $comparison = if ($IsWindows) {
    [StringComparison]::OrdinalIgnoreCase
  } else { [StringComparison]::Ordinal }
  $separator = [IO.Path]::DirectorySeparatorChar
  if ($source.Equals($destination, $comparison) -or
      $source.StartsWith($destination + $separator, $comparison) -or
      $destination.StartsWith($source + $separator, $comparison)) {
    throw 'Package source and destination must not overlap.'
  }
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Package source directory does not exist: $source"
  }
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  $items = @('agents', 'skills', 'scripts')
  if ($IncludeConfig) { $items += 'config' }
  $items += 'VERSION'
  if ($Profile -eq 'Narrow') { $items += @('CHANGELOG.md', 'CHANGELOG.zh-CN.md') }
  foreach ($item in $items) {
    Copy-Item -LiteralPath (Join-Path $source $item) -Destination $destination -Recurse -Force
  }
  if ($Profile -eq 'Narrow') {
    foreach ($relative in @('docs/formatter-tool.md', 'docs/verification/active/formatter-tool.md')) {
      $target = Join-Path $destination $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $source $relative) -Destination $target
    }
  } else {
    $docsRoot = Join-Path $source 'docs'
    foreach ($document in Get-ChildItem -LiteralPath $docsRoot -File -Recurse) {
      $relative = [IO.Path]::GetRelativePath($docsRoot, $document.FullName).Replace('\', '/')
      if ($relative -match '^(governance|superpowers)/') { continue }
      $target = Join-Path $destination "docs/$relative"
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      Copy-Item -LiteralPath $document.FullName -Destination $target
    }
    foreach ($document in Get-ChildItem -LiteralPath $source -Filter '*.md' -File) {
      Copy-Item -LiteralPath $document.FullName -Destination $destination
    }
  }
}

# A complete hidden-file-inclusive manifest detects additions, removals and byte edits.
# Return relative path TAB uppercase SHA256 lines in ordinal order, joined with LF.
function Get-TestFingerprint {
  param([Parameter(Mandatory)][string]$Root)
  $resolved = [IO.Path]::GetFullPath($Root)
  $manifest = [Collections.Generic.List[string]]::new()
  foreach ($file in Get-ChildItem -LiteralPath $resolved -Recurse -Force -File) {
    $relative = [IO.Path]::GetRelativePath($resolved, $file.FullName)
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $manifest.Add("$relative`t$hash")
  }
  $manifest.Sort([StringComparer]::Ordinal)
  return ($manifest -join "`n")
}

# Remove only the caller's literal-prefix plus lowercase GUID direct OS-temp child.
# Validate even absent paths; reject reparse roots rather than following their target.
# Callers must supply the exact per-suite prefix, including its trailing hyphen.
function Remove-TestSandbox {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Prefix
  )
  $resolved = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
  $actualParent = [IO.Path]::GetDirectoryName($resolved)
  $comparison = if ($IsWindows) {
    [StringComparison]::OrdinalIgnoreCase
  } else { [StringComparison]::Ordinal }
  $pattern = '^' + [regex]::Escape($Prefix) + '[a-f0-9]{32}$'
  if (-not $actualParent.Equals($temporaryParent, $comparison) -or
      [IO.Path]::GetFileName($resolved) -cnotmatch $pattern) {
    throw "Refusing cleanup outside owned test directory: $resolved"
  }
  $item = Get-Item -LiteralPath $resolved -Force -ErrorAction SilentlyContinue
  if ($null -ne $item) {
    if (-not $item.PSIsContainer -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Refusing cleanup of non-directory or reparse root: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
