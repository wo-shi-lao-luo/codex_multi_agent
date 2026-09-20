[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Validate', 'Archive')][string]$Action,
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,79}$')][string]$StageSlug,
  [string]$StageTitle
)

$ErrorActionPreference = 'Stop'
$script:FinalManualStatuses = @('manual pending', 'manually verified', 'failed', 'deferred by user')
$script:Tracks = @('test-first', 'test-after', 'manual-or-environmental')
$script:RowStatuses = @('planned', 'written', 'failing as intended', 'passing', 'manual pending', 'manually verified', 'exception accepted')
$script:CoverageCategories = @('unit', 'integration', 'contract/API', 'E2E', 'regression', 'manual', 'component/UI', 'accessibility', 'visual regression', 'performance/load', 'security', 'compatibility', 'data migration/rollback', 'resilience/recovery', 'exploratory/usability')

function Get-StagePaths {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Slug)
  $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
  if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) { throw "Project root does not exist: $resolvedRoot" }
  $active = Join-Path $resolvedRoot 'docs\verification\active'
  [PSCustomObject]@{
    Root = $resolvedRoot
    Active = $active
    Packet = Join-Path $active ($Slug + '.md')
    Archive = Join-Path $resolvedRoot 'docs\verification\archive'
  }
}

function Get-FinalManualStatus {
  param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors)
  $matches = [regex]::Matches($Content, '(?mi)^Final manual status:\s*(.*?)\s*$')
  if ($matches.Count -ne 1) {
    $Errors.Add("Packet must contain exactly one 'Final manual status:' field; found $($matches.Count).")
    return $null
  }
  $status = $matches[0].Groups[1].Value.Trim().ToLowerInvariant()
  if ($script:FinalManualStatuses -notcontains $status) {
    $Errors.Add("Final manual status must be one of: $($script:FinalManualStatuses -join ', ').")
    return $null
  }
  return $status
}

function Get-MatrixRows {
  param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors)
  $section = [regex]::Match($Content, '(?ms)^## TDD behavior matrix\s*\r?\n(?<body>.*?)(?=^## |\z)')
  if (-not $section.Success) {
    $Errors.Add("Packet is missing the '## TDD behavior matrix' section.")
    return [PSCustomObject]@{ Rows = @() }
  }
  $lines = @($section.Groups['body'].Value -split "`r?`n" | Where-Object { $_.Trim().StartsWith('|') })
  if ($lines.Count -lt 3) {
    $Errors.Add('TDD behavior matrix must contain a header, separator, and at least one behavior row.')
    return [PSCustomObject]@{ Rows = @() }
  }
  $expectedHeader = '| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |'
  if ($lines[0].Trim() -ne $expectedHeader) {
    $Errors.Add('TDD behavior matrix header does not match the required schema.')
    return [PSCustomObject]@{ Rows = @() }
  }
  $rows = @()
  foreach ($line in $lines[2..($lines.Count - 1)]) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 11) {
      $Errors.Add("TDD behavior matrix row must have 11 cells: $line")
      continue
    }
    $rows += ,$cells
  }
  return [PSCustomObject]@{ Rows = @($rows) }
}

function Test-CoverageCategoryDecisions {
  param([Parameter(Mandatory = $true)][string]$Content, [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Errors)
  $section = [regex]::Match($Content, '(?ms)^## Coverage-category decisions\s*\r?\n(?<body>.*?)(?=^## |\z)')
  if (-not $section.Success) {
    $Errors.Add("Packet is missing the '## Coverage-category decisions' section.")
    return
  }
  $lines = @($section.Groups['body'].Value -split "`r?`n" | Where-Object { $_.Trim().StartsWith('|') })
  if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '| Category | Decision | Reason |') {
    $Errors.Add('Coverage-category decisions must contain the required header and at least one decision row.')
    return
  }
  $seen = @{}
  foreach ($line in $lines[2..($lines.Count - 1)]) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 3) {
      $Errors.Add("Coverage-category decision row must have 3 cells: $line")
      continue
    }
    $category = $cells[0]
    if ($script:CoverageCategories -notcontains $category) {
      $Errors.Add("Coverage-category decision has an unsupported category '$category'.")
      continue
    }
    if ($seen.ContainsKey($category)) { $Errors.Add("Coverage category '$category' appears more than once.") }
    $seen[$category] = $true
    if (@('required', 'conditional', 'not applicable') -notcontains $cells[1].ToLowerInvariant()) {
      $Errors.Add("Coverage category '$category' must be required, conditional, or not applicable.")
    }
    if ([string]::IsNullOrWhiteSpace($cells[2])) { $Errors.Add("Coverage category '$category' requires a reason.") }
  }
  foreach ($category in $script:CoverageCategories) {
    if (-not $seen.ContainsKey($category)) { $Errors.Add("Coverage category '$category' requires a decision row.") }
  }
}

function Test-Packet {
  param([Parameter(Mandatory = $true)][string]$PacketPath)
  if (-not (Test-Path -LiteralPath $PacketPath -PathType Leaf)) { throw "Active stage packet does not exist: $PacketPath" }
  $content = Get-Content -LiteralPath $PacketPath -Raw
  $errors = [System.Collections.Generic.List[string]]::new()

  foreach ($requiredField in 'Packet schema version: 2', 'Stage slug:', 'Contract status:') {
    if (-not $content.Contains($requiredField)) { $errors.Add("Packet is missing required metadata: $requiredField") }
  }
  foreach ($requiredHeading in '## Stage context', '## Use-case map', '## Coverage-category decisions', '## TDD behavior matrix', '## Automated test and E2E plan', '## Human verification script') {
    if ([regex]::Matches($content, '(?m)^' + [regex]::Escape($requiredHeading) + '\s*$').Count -ne 1) {
      $errors.Add("Packet must contain exactly one '$requiredHeading' section.")
    }
  }

  $finalManualStatus = Get-FinalManualStatus -Content $content -Errors $errors
  $finalEvidenceMatches = [regex]::Matches($content, '(?mi)^Final manual evidence:\s*(.*?)\s*$')
  if ($finalEvidenceMatches.Count -ne 1) {
    $errors.Add("Packet must contain exactly one 'Final manual evidence:' field; found $($finalEvidenceMatches.Count).")
  } elseif ($finalManualStatus -in @('manually verified', 'failed', 'deferred by user') -and [string]::IsNullOrWhiteSpace($finalEvidenceMatches[0].Groups[1].Value)) {
    $errors.Add("Final manual status '$finalManualStatus' requires Final manual evidence.")
  }
  Test-CoverageCategoryDecisions -Content $content -Errors $errors
  $matrix = Get-MatrixRows -Content $content -Errors $errors
  foreach ($cells in $matrix.Rows) {
    $behavior = $cells[0]
    $track = $cells[3].ToLowerInvariant()
    $testIdentity = $cells[4]
    $redEvidence = $cells[5]
    $greenEvidence = $cells[6]
    $refactorEvidence = $cells[7]
    $alternativeEvidence = $cells[8]
    $owner = $cells[9]
    $status = $cells[10].ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($behavior) -or [string]::IsNullOrWhiteSpace($cells[1]) -or [string]::IsNullOrWhiteSpace($cells[2]) -or [string]::IsNullOrWhiteSpace($owner)) {
      $errors.Add('Each TDD behavior matrix row must identify behavior, risk, coverage category, and owner.')
    }
    if ($script:Tracks -notcontains $track) { $errors.Add("Behavior '$behavior' has an unsupported track '$($cells[3])'.") }
    if ($script:RowStatuses -notcontains $status) { $errors.Add("Behavior '$behavior' has an unsupported status '$($cells[10])'.") }

    if ($track -eq 'test-first') {
      if ([string]::IsNullOrWhiteSpace($testIdentity)) { $errors.Add("Test-first behavior '$behavior' is missing a test identity.") }
      if ($status -in @('failing as intended', 'passing')) {
        foreach ($evidence in @(@{ Name = 'Red evidence'; Value = $redEvidence })) {
          if ([string]::IsNullOrWhiteSpace($evidence.Value) -or $evidence.Value.Trim().ToLowerInvariant() -in @('planned', 'not applicable')) {
            $errors.Add("Test-first behavior '$behavior' is $status but lacks $($evidence.Name).")
          }
        }
      }
      if ($status -eq 'passing') {
        foreach ($evidence in @(@{ Name = 'Green evidence'; Value = $greenEvidence }, @{ Name = 'Refactor verification'; Value = $refactorEvidence })) {
          if ([string]::IsNullOrWhiteSpace($evidence.Value) -or $evidence.Value.Trim().ToLowerInvariant() -in @('planned', 'not applicable')) {
            $errors.Add("Test-first behavior '$behavior' is passing but lacks $($evidence.Name).")
          }
        }
      }
    } elseif ([string]::IsNullOrWhiteSpace($alternativeEvidence) -or $alternativeEvidence.Trim().ToLowerInvariant() -in @('planned', 'not applicable')) {
      $errors.Add("Non-test-first behavior '$behavior' requires a concrete alternative evidence or exception reason.")
    }
  }

  [PSCustomObject]@{ valid = ($errors.Count -eq 0); finalManualStatus = $finalManualStatus; errors = @($errors) }
}

$paths = Get-StagePaths -Root $ProjectRoot -Slug $StageSlug
if ($Action -eq 'Initialize') {
  if (Test-Path -LiteralPath $paths.Packet) { throw "Stage packet already exists: $($paths.Packet)" }
  if ([string]::IsNullOrWhiteSpace($StageTitle)) { $StageTitle = $StageSlug }
  New-Item -ItemType Directory -Force -Path $paths.Active | Out-Null
  @"
# Verification: $StageTitle

Packet schema version: 2
Stage slug: $StageSlug
Contract status: draft
Final manual status: manual pending
Final manual evidence:

## Stage context
- Objective:
- Scope, environment, test data, and cleanup:

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| | | | | |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | required / conditional / not applicable | |
| integration | required / conditional / not applicable | |
| contract/API | required / conditional / not applicable | |
| E2E | required / conditional / not applicable | |
| regression | required / conditional / not applicable | |
| manual | required / conditional / not applicable | |
| component/UI | required / conditional / not applicable | |
| accessibility | required / conditional / not applicable | |
| visual regression | required / conditional / not applicable | |
| performance/load | required / conditional / not applicable | |
| security | required / conditional / not applicable | |
| compatibility | required / conditional / not applicable | |
| data migration/rollback | required / conditional / not applicable | |
| resilience/recovery | required / conditional / not applicable | |
| exploratory/usability | required / conditional / not applicable | |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | unit | test-first / test-after / manual-or-environmental | | planned | planned | planned | required for non-test-first | | planned |

Assess unit, integration, contract/API, E2E, regression, manual, component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability.

## Automated test and E2E plan
- Commands, fixtures, environment, cleanup, and TDD exceptions:

## Human verification script
### Preparation
1. Prepare environment, account, and test data:
### Happy path
1. Action:
   Expected result:
### Recommended edge cases
1. Action or condition:
   Expected result:
### Result
- Observations and cleanup:
"@ | Set-Content -LiteralPath $paths.Packet -Encoding utf8
  [PSCustomObject]@{ action = 'initialized'; packetPath = $paths.Packet } | ConvertTo-Json
  exit 0
}

$validation = Test-Packet -PacketPath $paths.Packet
if (-not $validation.valid) { throw ("Packet validation failed:`n- " + ($validation.errors -join "`n- ")) }
if ($Action -eq 'Validate') {
  [PSCustomObject]@{ action = 'validated'; packetPath = $paths.Packet; finalManualStatus = $validation.finalManualStatus } | ConvertTo-Json
  exit 0
}

if ($validation.finalManualStatus -notin @('manually verified', 'deferred by user')) {
  throw 'Archive requires Final manual status: manually verified or deferred by user.'
}
New-Item -ItemType Directory -Force -Path $paths.Archive | Out-Null
$destination = Join-Path $paths.Archive ((Get-Date -Format 'yyyy-MM-dd') + '_' + $StageSlug + '.md')
if (Test-Path -LiteralPath $destination) { throw "Archived packet already exists: $destination" }
Move-Item -LiteralPath $paths.Packet -Destination $destination
[PSCustomObject]@{ action = 'archived'; packetPath = $destination } | ConvertTo-Json
