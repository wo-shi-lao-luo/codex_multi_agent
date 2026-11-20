# Synchronize generated version metadata and current release labels from the root VERSION.
#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [ValidatePattern('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')][string]$ReleaseDate,
  [string]$NodePath = 'node'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/team-core/scripts/platform-filesystem.ps1')
. (Join-Path $PSScriptRoot 'release-signals.ps1')
$root = Get-TeamCanonicalRoot $ProjectRoot
$versionFile = Resolve-TeamContainedPath $root 'VERSION'
$version = [IO.File]::ReadAllText($versionFile).Trim()
if ($version -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') {
  throw 'VERSION must be X.Y.Z.'
}
if ($ReleaseDate) {
  [void][DateTime]::ParseExact($ReleaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
}

$currentLabel = '(?m)^(?<prefix>(?:Current release|当前版本|当前发布版本):[ \t]*`)[0-9]+\.[0-9]+\.[0-9]+(?<suffix>`)'
$publishedHeading = '(?m)^## \[(?<version>[0-9]+\.[0-9]+\.[0-9]+)\] - (?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})[ \t]*\r?$'
$unreleasedHeading = '(?m)^## \[Unreleased\][ \t]*(?=\r?$)'
$updates = [ordered]@{}
$releaseSignals = @{}
$releaseFailures = [System.Collections.Generic.List[string]]::new()
$promoting = $null

foreach ($file in 'README.md', 'README.zh-CN.md') {
  $path = Resolve-TeamContainedPath $root $file
  $text = [IO.File]::ReadAllText($path)
  if ([regex]::Matches($text, $currentLabel).Count -ne 1) {
    throw "$file must contain exactly one current release field."
  }
  $updates[$path] = [regex]::Replace($text, $currentLabel, ('${prefix}' + $version + '${suffix}'))
}

# Promote only the first pending section. Published headings and their dates are immutable.
foreach ($file in 'CHANGELOG.md', 'CHANGELOG.zh-CN.md') {
  $path = Resolve-TeamContainedPath $root $file
  $text = [IO.File]::ReadAllText($path)
  $latest = [regex]::Match($text, $publishedHeading)
  if (-not $latest.Success) { throw "$file must have a published release heading." }
  $latestVersion = $latest.Groups['version'].Value
  $latestDate = $latest.Groups['date'].Value
  if ($latestVersion -ceq $version) {
    if ($ReleaseDate -and $ReleaseDate -cne $latestDate) {
      throw 'The existing release date differs from -ReleaseDate.'
    }
  } else {
    if (-not $ReleaseDate -or [version]$version -le [version]$latestVersion) {
      throw "$file is not on VERSION $version. To publish a newer version, supply -ReleaseDate and an Unreleased section."
    }
    $pending = [regex]::Matches($text, $unreleasedHeading)
    if ($pending.Count -ne 1 -or $pending[0].Index -ge $latest.Index) {
      throw "$file must have one Unreleased section before published history."
    }
    $heading = "## [$version] - $ReleaseDate"
    $text = $text.Remove($pending[0].Index, $pending[0].Length).Insert($pending[0].Index, $heading)
    $promoting = $true
  }
  $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
  $prose = (Get-MarkdownParts $file $normalized $releaseFailures).Prose
  foreach ($pattern in $publishedHeading, $unreleasedHeading) {
    if ([regex]::Matches($normalized, $pattern).Count -ne [regex]::Matches($prose, $pattern).Count) {
      throw "$file contains a release heading inside a code fence. Use a prose heading."
    }
  }
  $releaseSignals[$file] = @(Get-ReleaseSignals $file $prose $version $releaseFailures) -join "`n"
  $updates[$path] = $text
}
if ($releaseFailures.Count -gt 0) { throw ($releaseFailures -join "`n") }
if ($releaseSignals['CHANGELOG.md'] -cne $releaseSignals['CHANGELOG.zh-CN.md']) {
  throw 'Release headings, categories or item counts differ across the changelogs.'
}

$stamp = Resolve-TeamContainedPath $root 'skills/team-core/runtime/kit-version.txt'
$updates[$stamp] = $version + [char]10
if (Test-Path -LiteralPath $stamp -PathType Container) { throw 'Version metadata must be a file.' }

# Only Board-enabled branches need Node. Run the existing builder before updating the
# documents so an unavailable runtime leaves their release labels untouched.
$builder = Resolve-TeamContainedPath $root 'scripts/build-task-board.mjs'
if (Test-Path -LiteralPath $builder -PathType Leaf) {
  $node = Get-Command $NodePath -CommandType Application -ErrorAction Stop | Select-Object -First 1
  & $node.Source $builder --project-root $root
  if ($LASTEXITCODE -ne 0) { throw 'Task Board build failed.' }
}

$encoding = [Text.UTF8Encoding]::new($false)
foreach ($path in $updates.Keys) {
  if ((Test-Path -LiteralPath $path -PathType Leaf) -and [IO.File]::ReadAllText($path) -ceq $updates[$path]) {
    continue
  }
  [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
  [IO.File]::WriteAllText($path, $updates[$path], $encoding)
}
if ($promoting) { Write-Output "Prepared release $version ($ReleaseDate)." }
else { Write-Output "Synchronized Kit version $version." }
