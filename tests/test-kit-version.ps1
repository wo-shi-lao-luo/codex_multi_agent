# Exercise release synchronization and installed version lookup in disposable directories.
#requires -Version 7.0

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')

$root = Split-Path -Parent $PSScriptRoot
$temporaryParent = Get-TestTemporaryParent
$prefix = 'codex-multi-agent-kit-version-test-'
$testRoot = Join-Path $temporaryParent ($prefix + [guid]::NewGuid().ToString('N'))
$project = Join-Path $testRoot 'source'
$installedCore = Join-Path $testRoot 'installed/team-core'
$syncScript = Join-Path $root 'scripts/sync-kit-version.ps1'
$helper = 'skills/team-core/scripts/platform-filesystem.ps1'
$stamp = 'skills/team-core/runtime/kit-version.txt'
$encoding = [Text.UTF8Encoding]::new($false)

function Assert-Equal($Actual, $Expected, [string]$Message) {
  if ($Actual -cne $Expected) { throw $Message }
}

function Write-FixtureFile([string]$RelativePath, [string]$Content) {
  $path = Join-Path $project $RelativePath
  [IO.File]::WriteAllText($path, $Content, $encoding)
}

function Assert-FixtureFile([string]$RelativePath, [string]$Expected) {
  $actualBytes = [IO.File]::ReadAllBytes((Join-Path $project $RelativePath))
  $expectedBytes = $encoding.GetBytes($Expected)
  Assert-Equal ([Convert]::ToBase64String($actualBytes)) `
    ([Convert]::ToBase64String($expectedBytes)) "$RelativePath has unexpected bytes."
}

function Get-ReleaseSnapshot {
  # Include timestamps to detect rewrites that produce identical bytes.
  $files = Get-ChildItem -LiteralPath $project -File -Recurse | Sort-Object FullName
  return ($files | ForEach-Object {
    "$($_.FullName) $($_.LastWriteTimeUtc.Ticks) $((Get-FileHash -LiteralPath $_.FullName).Hash)"
  }) -join "`n"
}

function Assert-SyncRejected([string[]]$Arguments, [string]$Description) {
  # Exercise the command's public failure status and check the entire fixture for writes.
  $before = Get-ReleaseSnapshot
  $result = Invoke-TestPowerShell (@('-File', $syncScript, '-ProjectRoot', $project) + $Arguments)
  if ($result.ExitCode -eq 0) { throw "Synchronization accepted $Description." }
  Assert-Equal (Get-ReleaseSnapshot) $before "Synchronization changed files for $Description."
}

function Assert-LookupRejected([string]$Description) {
  # Propagate unexpected helper errors instead of mistaking them for metadata rejection.
  try {
    $null = Get-TeamKitVersion
  } catch {
    if ($_.Exception.Message -like 'KIT_VERSION:*') { return }
    throw
  }
  throw "Installed version lookup accepted $Description."
}

try {
  [IO.Directory]::CreateDirectory((Join-Path $project 'skills/team-core/runtime')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $installedCore 'scripts')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $installedCore 'runtime')) | Out-Null

  $oldVersion = '4.5.6'
  $newVersion = '4.5.7'
  $releaseDate = '2026-11-20'
  $changelog = "# History`n`n## [Unreleased]`n`n- Pending item`n`n" +
    "## [$oldVersion] - 2026-10-01`n`n- Existing item  `n`n" +
    "## [4.5.5] - 2026-09-01`n`n- Older item`n"
  $labels = @{ 'README.md' = 'Current release'; 'README.zh-CN.md' = '当前发布版本' }
  $changelogs = @{
    'CHANGELOG.md' = $changelog
    'CHANGELOG.zh-CN.md' = $changelog.Replace("`n", "`r`n")
  }
  Write-FixtureFile 'VERSION' "$newVersion`n"
  Write-FixtureFile $stamp "$oldVersion`n"
  foreach ($name in $labels.Keys) {
    Write-FixtureFile $name ('{0}: `{1}``nExample {1}' -f $labels[$name], $oldVersion).Replace('`n', "`n")
  }
  foreach ($name in $changelogs.Keys) { Write-FixtureFile $name $changelogs[$name] }

  # Scenario: a version ahead of published history needs an explicit publication date.
  # Expected: the command fails and leaves the fixture untouched.
  Assert-SyncRejected @() 'a version ahead of history without a date'

  # Scenario: the supplied release date is invalid and the READMEs need updates.
  # Expected: the invalid date is rejected before any fixture file is rewritten.
  Assert-SyncRejected @('-ReleaseDate', '2026-02-30') 'an invalid calendar date'

  # Scenario: VERSION contains a prerelease suffix.
  # Expected: the strict numeric release contract rejects it before making changes.
  Write-FixtureFile 'VERSION' "$newVersion-preview`n"
  Assert-SyncRejected @('-ReleaseDate', $releaseDate) 'an invalid VERSION'
  Write-FixtureFile 'VERSION' "$newVersion`n"

  # Scenario: one pending section has an extra item.
  # Expected: the prospective release pair is rejected before any fixture file is written.
  $chineseChangelog = 'CHANGELOG.zh-CN.md'
  $unevenChangelog = $changelogs[$chineseChangelog].Replace(
    '- Pending item', "- Pending item`r`n- Additional pending item"
  )
  Write-FixtureFile $chineseChangelog $unevenChangelog
  Assert-SyncRejected @('-ReleaseDate', $releaseDate) 'uneven changelog item counts'
  Write-FixtureFile $chineseChangelog $changelogs[$chineseChangelog]

  # Scenario: apparent pending headings appear only in fenced examples.
  # Expected: release preparation refuses them without editing either example.
  $fence = '~~~'
  foreach ($name in $changelogs.Keys) {
    $newline = if ($name -eq $chineseChangelog) { "`r`n" } else { "`n" }
    $fenced = $changelogs[$name].Replace('## [Unreleased]', "$fence${newline}## [Unreleased]")
    Write-FixtureFile $name $fenced.Replace('- Pending item', "- Pending item$newline$fence")
  }
  Assert-SyncRejected @('-ReleaseDate', $releaseDate) 'fenced pending headings'
  foreach ($name in $changelogs.Keys) { Write-FixtureFile $name $changelogs[$name] }

  # Scenario: publish both pending sections from VERSION in a source without Board.
  # Expected: only current labels, pending headings and the generated LF stamp change.
  & $syncScript -ProjectRoot $project -ReleaseDate $releaseDate -NodePath 'missing-test-node'
  Assert-FixtureFile 'VERSION' "$newVersion`n"
  Assert-FixtureFile $stamp "$newVersion`n"
  foreach ($name in $labels.Keys) {
    $expected = '{0}: `{1}``nExample {2}' -f $labels[$name], $newVersion, $oldVersion
    Assert-FixtureFile $name ($expected.Replace('`n', "`n"))
  }
  foreach ($name in $changelogs.Keys) {
    Assert-FixtureFile $name ($changelogs[$name].Replace(
      '## [Unreleased]', "## [$newVersion] - $releaseDate"
    ))
  }

  # Scenario: synchronization was interrupted after promoting only the English changelog.
  # Expected: retry with the same date promotes the remaining heading and refreshes the stamp.
  $englishPath = Join-Path $project 'CHANGELOG.md'
  $englishPublicationTime = (Get-Item -LiteralPath $englishPath).LastWriteTimeUtc
  Write-FixtureFile $chineseChangelog $changelogs[$chineseChangelog]
  Write-FixtureFile $stamp "$oldVersion`n"
  & $syncScript -ProjectRoot $project -ReleaseDate $releaseDate
  Assert-FixtureFile $stamp "$newVersion`n"
  $publishedHeading = "## [$newVersion] - $releaseDate"
  foreach ($name in $changelogs.Keys) {
    Assert-FixtureFile $name ($changelogs[$name].Replace('## [Unreleased]', $publishedHeading))
  }
  Assert-Equal (Get-Item -LiteralPath $englishPath).LastWriteTimeUtc $englishPublicationTime `
    'Retry rewrote the already published English changelog.'

  # Scenario: synchronize again with matching current release headings.
  # Expected: every file retains its bytes and timestamp.
  $before = Get-ReleaseSnapshot
  & $syncScript -ProjectRoot $project
  Assert-Equal (Get-ReleaseSnapshot) $before 'Repeat synchronization rewrote a file.'

  # Scenario: the published release is given a different date.
  # Expected: the command rejects the date and preserves published history.
  Assert-SyncRejected @('-ReleaseDate', '2026-11-21') 'a different date for a published release'

  # Scenario: an installed helper runs in a source at a different release.
  # Expected: it reads the installed runtime stamp alongside its own script.
  $installedHelper = Join-Path $installedCore 'scripts/platform-filesystem.ps1'
  $installedStamp = Join-Path $installedCore 'runtime/kit-version.txt'
  Copy-Item -LiteralPath (Join-Path $root $helper) -Destination $installedHelper
  [IO.File]::WriteAllText($installedStamp, "$oldVersion`n", $encoding)
  Push-Location -LiteralPath $project
  try {
    . $installedHelper
    Assert-Equal (Get-TeamKitVersion) $oldVersion 'Lookup did not use the installed stamp.'
  } finally {
    Pop-Location
  }

  # Scenario: the installed stamp is invalid or absent.
  # Expected: lookup fails in both cases instead of returning fallback provenance.
  [IO.File]::WriteAllText($installedStamp, "$oldVersion-preview`n", $encoding)
  Assert-LookupRejected 'invalid metadata'
  Remove-Item -LiteralPath $installedStamp
  Assert-LookupRejected 'missing metadata'

  Write-Output 'Kit release synchronization and installed provenance tests passed.'
} finally {
  $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
  if ([IO.Path]::GetDirectoryName($resolvedTestRoot) -cne $temporaryParent -or
      -not [IO.Path]::GetFileName($resolvedTestRoot).StartsWith($prefix)) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
