# Check this repository's bilingual public-doc structure without editing source or installed state.
# This is a separate maintainer command, not package/install validation or a translation certificate.
#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [ValidateNotNullOrEmpty()][string]$MasterBaseRef
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()
. (Join-Path $PSScriptRoot 'release-signals.ps1')

# Compare ordered signals or sorted multisets supplied by callers; preserve duplicate entries.
function Compare-Signals {
  param([string]$Label, [object[]]$English, [object[]]$Chinese)
  if (($English | ConvertTo-Json -Compress -Depth 5) -cne ($Chinese | ConvertTo-Json -Compress -Depth 5)) {
    $failures.Add("$Label differs between English and Chinese; synchronize the counterpart.")
  }
}

# Link labels can be translated; normalize only paired root filenames, retaining anchors,
# external URLs and every other path. Local path existence is checked, not anchor resolution.
function Get-LinkSignals {
  param([string]$Name, [string]$Prose, [string]$Root)
  $targets = [System.Collections.Generic.List[string]]::new()
  foreach ($match in [regex]::Matches($Prose, '\[[^\]]*\]\(([^)]+)\)')) {
    $target = $match.Groups[1].Value.Trim()
    if ($target -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*:' -and -not $target.StartsWith('//') -and -not $target.StartsWith('#')) {
      $local = ($target -split '[#?]', 2)[0]
      if ($local -and -not (Test-Path -LiteralPath (Join-Path $Root $local))) {
        $failures.Add("$Name links to missing local path: $local")
      }
    }
    $targets.Add(($target -creplace '^(?:\./)?README\.zh-CN\.md(?=[#?]|$)', 'README.md' -creplace '^(?:\./)?CHANGELOG\.zh-CN\.md(?=[#?]|$)', 'CHANGELOG.md' -creplace '^\./(?=(README|CHANGELOG)\.md(?:[#?]|$))', ''))
  }
  return @($targets.ToArray() | Sort-Object -CaseSensitive)
}

# Model and effort cells are technical facts; role labels and table headings may be localized.
# This checks pair consistency, not whether either README matches actual agent configuration.
function Get-ModelSignals {
  param([string]$Name, [string]$Prose)
  $rows = [System.Collections.Generic.List[string]]::new()
  foreach ($line in ($Prose -split "`n")) {
    if ($line -match '^\s*\|[^|]+\|\s*`?(gpt-[a-zA-Z0-9.-]+)`?\s*\|\s*`?([a-z]+)`?\s*\|\s*$') {
      $rows.Add($Matches[1] + '|' + $Matches[2])
    }
  }
  if ($rows.Count -eq 0) { $failures.Add("$Name has no supported model/effort table rows.") }
  return @($rows.ToArray())
}

try {
  if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw 'ProjectRoot must be an existing repository directory.' }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $contents = @{}
  foreach ($name in @('README.md', 'README.zh-CN.md', 'CHANGELOG.md', 'CHANGELOG.zh-CN.md', 'VERSION')) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Required file missing: $name"); continue }
    $content = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($content)) { $failures.Add("Required file empty: $name"); continue }
    $contents[$name] = $content
  }
  if ($failures.Count -eq 0) {
    $version = $contents['VERSION'].Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') { $failures.Add('VERSION must be X.Y.Z.') }
    if ($MasterBaseRef) {
      $baseCommit = & git -C $root rev-parse --verify --end-of-options "${MasterBaseRef}^{commit}" 2>$null
      if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve the master base commit.' }
      $baseVersion = (& git -C $root show "${baseCommit}:VERSION" 2>$null) -join ''
      if ($LASTEXITCODE -ne 0 -or $baseVersion -cnotmatch '^\d+\.\d+\.\d+$') {
        throw 'Master base commit must contain a numeric VERSION.'
      }
      if ([version]$version -le [version]$baseVersion) {
        $failures.Add("VERSION $version must be newer than master VERSION $baseVersion.")
      }
      $stamp = Join-Path $root 'skills/team-core/runtime/kit-version.txt'
      if (-not (Test-Path -LiteralPath $stamp -PathType Leaf) -or
          [IO.File]::ReadAllText($stamp).Trim() -cne $version) {
        $failures.Add('Packaged Kit version must match VERSION. Run scripts/sync-kit-version.ps1.')
      }
    }
    foreach ($pair in @(@('README.md', 'README.zh-CN.md'), @('CHANGELOG.md', 'CHANGELOG.zh-CN.md'))) {
      $english = $pair[0]; $chinese = $pair[1]
      $parts = @{}
      foreach ($name in $pair) {
        if ($contents[$name] -notmatch '(?m)^#\s+\S') { $failures.Add("$name must have a nonempty top-level title.") }
        $parts[$name] = Get-MarkdownParts $name $contents[$name] $failures
        foreach ($navName in ($pair | Where-Object { $_ -ne $name })) {
          if ($parts[$name].Prose -notmatch ('\[[^\]]+\]\((?:\./)?' + [regex]::Escape($navName) + '\)')) {
            $failures.Add("$name must contain language navigation to $navName.")
          }
        }
      }
      Compare-Signals "$english code fences" $parts[$english].Blocks $parts[$chinese].Blocks
      $englishLiterals = @([regex]::Matches($parts[$english].Prose, '(?<!`)`([^`\n]+)`(?!`)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -CaseSensitive)
      $chineseLiterals = @([regex]::Matches($parts[$chinese].Prose, '(?<!`)`([^`\n]+)`(?!`)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -CaseSensitive)
      Compare-Signals "$english inline technical literals" $englishLiterals $chineseLiterals
      Compare-Signals "$english link targets" @(Get-LinkSignals $english $parts[$english].Prose $root) @(Get-LinkSignals $chinese $parts[$chinese].Prose $root)
      if ($english -eq 'README.md') {
        foreach ($name in $pair) {
          $releaseFields = @([regex]::Matches($parts[$name].Prose, '(?m)^(?:Current release|当前版本|当前发布版本):\s*`([^`]+)`'))
          if ($releaseFields.Count -ne 1 -or $releaseFields[0].Groups[1].Value -cne $version) { $failures.Add("$name must declare exactly one current release field matching VERSION $version.") }
        }
        Compare-Signals 'README model/effort rows' @(Get-ModelSignals $english $parts[$english].Prose) @(Get-ModelSignals $chinese $parts[$chinese].Prose)
      } else {
        $signals = @{}
        foreach ($name in $pair) {
          $signals[$name] = @(Get-ReleaseSignals $name $parts[$name].Prose $version $failures)
          if ($MasterBaseRef -and $signals[$name] -clike 'Unreleased|*') {
            $failures.Add("$name still has changes under Unreleased. Promote them to the new version before merging to master.")
          }
        }
        Compare-Signals 'CHANGELOG release/date/category/item structure' $signals[$english] $signals[$chinese]
      }
    }
  }
} catch { $failures.Add("Documentation validation failed: $($_.Exception.Message)") }

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) { Write-Output "FAIL: $failure" }
  exit 1
}
Write-Output 'Bilingual documentation structural checks passed. Translation meaning, model/config accuracy and rendered navigation still require independent review.'
exit 0
