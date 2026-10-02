# Check this repository's bilingual public-doc structure without editing source or installed state.
# This is a separate maintainer command, not package/install validation or a translation certificate.
#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

# Compare ordered signals or sorted multisets supplied by callers; preserve duplicate entries.
function Compare-Signals {
  param([string]$Label, [object[]]$English, [object[]]$Chinese)
  if (($English | ConvertTo-Json -Compress -Depth 5) -cne ($Chinese | ConvertTo-Json -Compress -Depth 5)) {
    $failures.Add("$Label differs between English and Chinese; synchronize the counterpart.")
  }
}

# Extract ordinary fenced blocks and prose separately. Unterminated fences are failures,
# not silently ignored text; languages and content remain exact after newline normalization.
function Get-MarkdownParts {
  param([string]$Name, [string]$Content)
  $blocks = [System.Collections.Generic.List[string]]::new()
  $prose = [System.Collections.Generic.List[string]]::new()
  $body = [System.Collections.Generic.List[string]]::new()
  $marker = $null
  $language = ''
  foreach ($line in ($Content -split "`n")) {
    if ($null -eq $marker) {
      if ($line -match '^\s{0,3}(`{3,}|~{3,})([^`]*)$') {
        $marker = $Matches[1]
        $language = $Matches[2].Trim()
        $body.Clear()
      } else { $prose.Add($line) }
    } elseif ($line -match ('^\s{0,3}' + [regex]::Escape($marker.Substring(0, 1)) + '{' + $marker.Length + ',}\s*$')) {
      $blocks.Add($language + "`n" + ($body -join "`n"))
      $marker = $null
    } else { $body.Add($line) }
  }
  if ($null -ne $marker) { $failures.Add("$Name contains an unterminated code fence.") }
  return @{ Blocks = @($blocks.ToArray()); Prose = ($prose -join "`n") }
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

# Release history must have strict version/date headings, ordered matching sections and item
# counts. Category mapping supports idiomatic Chinese headings, not arbitrary inferred meaning.
function Get-ReleaseSignals {
  param([string]$Name, [string]$Prose, [string]$Version)
  $categories = @{ Added='added'; '新增'='added'; Changed='changed'; '变更'='changed'; Removed='removed'; '移除'='removed'; Fixed='fixed'; '修复'='fixed'; Deprecated='deprecated'; '弃用'='deprecated'; Security='security'; '安全'='security' }
  $releases = [System.Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($line in ($Prose -split "`n")) {
    if ($line -match '^##\s+') {
      if ($line -notmatch '^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})\s*$') {
        $failures.Add("$Name has a malformed release heading: $line")
        $current = $null
        continue
      }
      $releaseVersion = $Matches[1]
      $releaseDate = $Matches[2]
      $parsedDate = [datetime]::MinValue
      if (-not [datetime]::TryParseExact($releaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $failures.Add("$Name release $releaseVersion has an invalid calendar date.")
      }
      $current = @{ Version=$releaseVersion; Date=$releaseDate; Sections=[System.Collections.Generic.List[string]]::new(); Counts=[System.Collections.Generic.List[int]]::new(); BulletCount=0 }
      $releases.Add($current)
    } elseif ($null -ne $current -and $line -match '^###\s+(.+?)\s*$') {
      $category = $Matches[1]
      if (-not $categories.ContainsKey($category)) { $failures.Add("$Name has unsupported release category: $category") }
      $current.Sections.Add($(if ($categories.ContainsKey($category)) { $categories[$category] } else { $category }))
      $current.Counts.Add(0)
    } elseif ($null -ne $current -and $line -match '^\s*[-*+]\s+') {
      $current.BulletCount++
      if ($current.Counts.Count -gt 0) { $current.Counts[$current.Counts.Count - 1]++ }
    }
  }
  if ($releases.Count -eq 0) { $failures.Add("$Name has no release headings.") }
  elseif ($releases[0].Version -cne $Version) { $failures.Add("$Name first release must match VERSION $Version.") }
  $seen = @{}
  foreach ($release in $releases) {
    if ($seen.ContainsKey($release.Version)) { $failures.Add("$Name repeats release $($release.Version).") }
    $seen[$release.Version] = $true
    if ($release.BulletCount -eq 0) { $failures.Add("$Name release $($release.Version) has no change items.") }
    # Produce deterministic primitive signatures instead of comparing unordered hashtables.
    '{0}|{1}|{2}|{3}|{4}' -f $release.Version, $release.Date, $release.BulletCount, ($release.Sections -join ','), ($release.Counts -join ',')
  }
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
    foreach ($pair in @(@('README.md', 'README.zh-CN.md'), @('CHANGELOG.md', 'CHANGELOG.zh-CN.md'))) {
      $english = $pair[0]; $chinese = $pair[1]
      $parts = @{}
      foreach ($name in $pair) {
        if ($contents[$name] -notmatch '(?m)^#\s+\S') { $failures.Add("$name must have a nonempty top-level title.") }
        $parts[$name] = Get-MarkdownParts $name $contents[$name]
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
        Compare-Signals 'CHANGELOG release/date/category/item structure' @(Get-ReleaseSignals $english $parts[$english].Prose $version) @(Get-ReleaseSignals $chinese $parts[$chinese].Prose $version)
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
