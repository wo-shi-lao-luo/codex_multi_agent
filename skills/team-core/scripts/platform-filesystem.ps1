# Local filesystem primitives shared by the installed team-core runtimes.
# Loading this file performs no I/O. Paths are checked boundaries, not a sandbox
# against another process replacing files after an inspection.
#requires -Version 7.0

function Get-TeamPathComparison {
  if ($IsWindows) { return [StringComparison]::OrdinalIgnoreCase }
  return [StringComparison]::Ordinal
}

function New-TeamOrdinalMap {
  return ,([Collections.Hashtable]::new([StringComparer]::Ordinal))
}

# Get-Item sees dangling links whose absent targets make Test-Path return false.
# An approved system alias is resolved only at the selected-root boundary below;
# repository descendants and every other linked ancestor remain unsupported.
function Assert-TeamPlainPath([string]$Path) {
  $cursor = [IO.Path]::GetFullPath($Path)
  while ($cursor) {
    try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
    catch { throw 'PATH: Cannot safely inspect path ancestors.' }
    if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'PATH: Linked/reparse paths are unsupported.' }
    $next = [IO.Path]::GetDirectoryName($cursor)
    if ($next -eq $cursor) { break }
    $cursor = $next
  }
}

# macOS exposes its system temporary roots through these two stable aliases.
# Verify the actual link and its exact target before substituting the trusted
# anchor. Never resolve arbitrary user/project links into an allowed destination.
function Get-TeamCanonicalRoot([string]$Path, [switch]$AllowMissing) {
  if ([string]::IsNullOrWhiteSpace($Path)) { throw 'PATH: Root must be a filesystem directory.' }
  $root = [IO.Path]::GetFullPath($Path)
  if ($IsMacOS) {
    foreach ($alias in @(@{ source='/tmp'; target='/private/tmp' }, @{ source='/var'; target='/private/var' })) {
      if ($root -ceq $alias.source -or $root.StartsWith($alias.source + '/', [StringComparison]::Ordinal)) {
        try { $item = Get-Item -LiteralPath $alias.source -Force -ErrorAction Stop }
        catch { throw 'PATH: Cannot verify macOS system alias.' }
        $targets = @($item.Target)
        if ($item.LinkType -cne 'SymbolicLink' -or -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$targets[0])) { throw 'PATH: Cannot verify macOS system alias target.' }
        $target = [string]$targets[0]
        if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path ([IO.Path]::GetDirectoryName($alias.source)) $target }
        if ([IO.Path]::GetFullPath($target) -cne $alias.target -or -not (Test-Path -LiteralPath $alias.target -PathType Container)) { throw 'PATH: Unexpected macOS system alias target.' }
        $root = $alias.target + $root.Substring($alias.source.Length)
      }
    }
  }
  if ($root -cne [IO.Path]::GetPathRoot($root)) { $root = $root.TrimEnd('/','\') }
  Assert-TeamPlainPath $root
  if (Test-Path -LiteralPath $root) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'PATH: Root must be a directory.' }
  } elseif (-not $AllowMissing) { throw 'PATH: Root must be an existing directory.' }
  return $root
}

# Keep stored path identities portable and reject traversal before normalization.
# Windows aliases/streams/reserved names are rejected on every host so a record
# cannot acquire a different filesystem meaning when moved to another platform.
function Normalize-TeamRelativePath([string]$Relative) {
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw 'PATH: Require a repository-relative path.' }
  $normalized = $Relative.Replace('\','/')
  foreach ($part in ($normalized -split '/')) {
    if ($part -in @('','.','..') -or $part -match '[<>:"|?*\x00-\x1f]' -or $part -match '[ .]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw 'PATH: Unsafe path segment.' }
  }
  return $normalized
}

function Resolve-TeamContainedPath([string]$Root, [string]$Relative) {
  $base = Get-TeamCanonicalRoot $Root -AllowMissing
  $normalized = Normalize-TeamRelativePath $Relative
  $full = [IO.Path]::GetFullPath((Join-Path $base $normalized))
  $prefix = $base.TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, (Get-TeamPathComparison))) { throw 'PATH: Path leaves selected root.' }
  Assert-TeamPlainPath $full
  return $full
}

# SHA256.HashData and Convert.ToHexString are unavailable in PowerShell 7.0's
# .NET runtime. This implementation keeps the same lowercase SHA256 byte identity.
function Get-TeamSha256Hex([byte[]]$Bytes) {
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($algorithm.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}
