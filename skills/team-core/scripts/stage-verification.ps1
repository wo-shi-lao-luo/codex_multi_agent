[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Archive')][string]$Action,
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9-]{0,79}$')][string]$StageSlug,
  [string]$StageTitle
)
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Project root does not exist: $root" }
$active = Join-Path $root 'docs\verification\active'
$packet = Join-Path $active ($StageSlug + '.md')
if ($Action -eq 'Initialize') {
  if (Test-Path -LiteralPath $packet) { throw "Stage packet already exists: $packet" }
  if ([string]::IsNullOrWhiteSpace($StageTitle)) { $StageTitle = $StageSlug }
  New-Item -ItemType Directory -Force -Path $active | Out-Null
  @"
# Verification: $StageTitle

Stage slug: $StageSlug
Contract status: draft
Manual status: manual pending

## Stage context
- Objective:
- Scope, environment, test data, and cleanup:

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| | | | | |

## Coverage matrix
| Behavior | Risk | Coverage category | Decision | Reason | Automated scenario | Manual scenario | Owner | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | unit | required / conditional / not applicable | | | | | planned | |

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
- Manual status: manual pending
- Observations and cleanup:
"@ | Set-Content -LiteralPath $packet -Encoding utf8
  [PSCustomObject]@{ action = 'initialized'; packetPath = $packet } | ConvertTo-Json
  exit 0
}
if (-not (Test-Path -LiteralPath $packet -PathType Leaf)) { throw "Active stage packet does not exist: $packet" }
if ((Get-Content -LiteralPath $packet -Raw) -notmatch '(?mi)^-?\s*Manual status:\s*(manually verified|deferred by user)\s*$') { throw 'Archive requires Manual status: manually verified or deferred by user.' }
$archive = Join-Path $root 'docs\verification\archive'
New-Item -ItemType Directory -Force -Path $archive | Out-Null
$destination = Join-Path $archive ((Get-Date -Format 'yyyy-MM-dd') + '_' + $StageSlug + '.md')
if (Test-Path -LiteralPath $destination) { throw "Archived packet already exists: $destination" }
Move-Item -LiteralPath $packet -Destination $destination
[PSCustomObject]@{ action = 'archived'; packetPath = $destination } | ConvertTo-Json
