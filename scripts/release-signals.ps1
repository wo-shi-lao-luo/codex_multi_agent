# Extract ordinary fenced blocks and prose separately. Unterminated fences are failures,
# not silently ignored text; languages and content remain exact after newline normalization.
function Get-MarkdownParts {
  param([string]$Name, [string]$Content, [System.Collections.Generic.List[string]]$Failures)
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

# Published history keeps strict version/date headings; one optional undated Unreleased
# section may precede it. Compare both kinds without treating pending items as a release.
function Get-ReleaseSignals {
  param([string]$Name, [string]$Prose, [string]$Version, [System.Collections.Generic.List[string]]$Failures)
  $categories = @{ Added='added'; '新增'='added'; Changed='changed'; '变更'='changed'; Removed='removed'; '移除'='removed'; Fixed='fixed'; '修复'='fixed'; Deprecated='deprecated'; '弃用'='deprecated'; Security='security'; '安全'='security' }
  $releases = [System.Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($line in ($Prose -split "`n")) {
    if ($line -match '^##\s+') {
      if ($line -cmatch '^## \[Unreleased\]\s*$') {
        if ($releases.Count -gt 0) { $failures.Add("$Name Unreleased must appear once, before published releases.") }
        $releaseVersion = 'Unreleased'
        $releaseDate = ''
      } elseif ($line -match '^## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})\s*$') {
        $releaseVersion = $Matches[1]
        $releaseDate = $Matches[2]
        $parsedDate = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($releaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
          $failures.Add("$Name release $releaseVersion has an invalid calendar date.")
        }
      } else {
        $failures.Add("$Name has a malformed release heading: $line")
        $current = $null
        continue
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
  $published = @($releases | Where-Object { $_.Version -cne 'Unreleased' })
  if ($published.Count -eq 0) { $failures.Add("$Name has no published release headings.") }
  elseif ($published[0].Version -cne $Version) { $failures.Add("$Name first release must match VERSION $Version.") }
  $seen = @{}
  foreach ($release in $releases) {
    if ($seen.ContainsKey($release.Version)) {
      # Both pre-integration branches used this preview number. Preserve their
      # original dated records without permitting arbitrary duplicate releases.
      $priorDates=@($seen[$release.Version])
      $historicalPair=$release.Version -ceq '0.10.1' -and $priorDates.Count -eq 1 -and
        $priorDates[0] -cne $release.Date -and
        $priorDates[0] -cin @('2026-10-04','2026-10-10') -and
        $release.Date -cin @('2026-10-04','2026-10-10')
      if (-not $historicalPair) { $failures.Add("$Name repeats release $($release.Version).") }
      $seen[$release.Version]=@($priorDates)+@($release.Date)
    } else { $seen[$release.Version]=@($release.Date) }
    if ($release.BulletCount -eq 0) { $failures.Add("$Name release $($release.Version) has no change items.") }
    # Produce deterministic primitive signatures instead of comparing unordered hashtables.
    '{0}|{1}|{2}|{3}|{4}' -f $release.Version, $release.Date, $release.BulletCount, ($release.Sections -join ','), ($release.Counts -join ',')
  }
}
