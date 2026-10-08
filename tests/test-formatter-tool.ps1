# Exercise the installed formatter adapter in isolated project fixtures.
# Controlled tools test transport and safety, not real formatter quality or Agent selection.
[CmdletBinding()]
param([switch]$SourceOnly, [ValidateSet('EditorConfig', 'GitIgnore')][string]$PolicyCase)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $root 'skills/team-core/scripts/format-code.ps1'
# FT-01: the installed shared Skill must include the requested executable adapter.
# Expected: absent helper is a practical preimplementation Red, before any process runs.
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
  throw 'FT-01 missing formatter helper: skills/team-core/scripts/format-code.ps1'
}
if ($SourceOnly) { Write-Output 'FT-01 helper payload exists; runtime safety not checked.'; return }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$fixture = Join-Path $tempParent ('codex-formatter-test-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $fixture 'project with spaces'
$outside = Join-Path $fixture 'outside.js'
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Assert-True([bool]$Value, [string]$Message) {
  # Fail at the behavioral boundary, retaining a scenario-specific diagnostic.
  if (-not $Value) { throw $Message }
}
function Write-Fixture([string]$Relative, [string]$Text) {
  # Fixture data only; these writes never target source or user installations.
  $target = Join-Path $project $Relative
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
  [IO.File]::WriteAllText($target, $Text, $utf8)
}
function Fingerprint([string]$Path) {
  # Byte hashes observe forbidden writes and BOM/EOL drift, not just decoded strings.
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Invoke-Adapter([hashtable]$Options) {
  # Invoke the real CLI in a fresh pwsh process; JSON/base64 preserves literal array args.
  $parameters = @{ ProjectRoot = $project; Files = @('src/file with spaces.js') }
  foreach ($key in $Options.Keys) { $parameters[$key] = $Options[$key] }
  $parameterJson = $parameters | ConvertTo-Json -Depth 8
  $encodedParameters = [Convert]::ToBase64String($utf8.GetBytes($parameterJson))
  $encodedHelper = [Convert]::ToBase64String($utf8.GetBytes($helper))
  $command = @"
`$parameterText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedParameters'))
`$params = `$parameterText | ConvertFrom-Json -AsHashtable
`$entry = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedHelper'))
& `$entry @params
exit `$LASTEXITCODE
"@
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $output = & pwsh -NoProfile -EncodedCommand $encodedCommand 2>&1
  $code = $LASTEXITCODE
  $raw = ($output | ForEach-Object { $_.ToString() }) -join "`n"
  try {
    $payload = $raw | ConvertFrom-Json
  } catch {
    throw "Non-JSON adapter response (exit$code): $raw"
  }
  Assert-True ($payload.schemaVersion -eq 1) 'Formatter schemaVersion is not1.'
  foreach ($row in $payload.results) {
    Assert-True ($row.status -in @('planned', 'clean', 'would-change', 'applied', 'excluded', 'blocked', 'error')) `
      "Unknown formatter status: $($row.status)"
  }
  return @{ Code = $code; Payload = $payload; Raw = $raw }
}
function Assert-NoChange([string]$Path, [string]$Hash, [string]$Scenario) {
  # Enforce the expected absence of a side effect in each safety scenario.
  Assert-True ((Fingerprint $Path) -ceq $Hash) "$Scenario changed protected original."
}
function Test-PolicyBoundary([string]$Kind) {
  # Observe existing policy outside a nested ProjectRoot without widening file authority.
  $parent = Join-Path $fixture ('policy-' + $Kind.ToLowerInvariant())
  $nested = Join-Path $parent 'nested'
  [IO.Directory]::CreateDirectory((Join-Path $nested 'src')) | Out-Null
  $file = Join-Path $nested 'src/file.js'
  [IO.File]::WriteAllText($file, "UNFORMATTED`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $nested '.prettierrc.json'), '{"printWidth":88}', $utf8)
  $hash = Fingerprint $file
  $options = @{ ProjectRoot = $nested; Formatter = 'Prettier'; ToolPath = $bin; Files = @('src/file.js') }
  $initialCalls = if (Test-Path -LiteralPath $log) { (Get-Content -LiteralPath $log).Count } else { 0 }
  if ($Kind -eq 'EditorConfig') {
    # FT-REVIEW-01 Red: external applicable .editorconfig with no project termination.
    # Expected: Plan blocks native policy boundary without executing config/tools or writing.
    [IO.File]::WriteAllText(
      (Join-Path $parent '.editorconfig'), "root = true`n[*]`nindent_size = 4`n", $utf8
    )
    $blocked = Invoke-Adapter $options
    Assert-True ($blocked.Code -eq 2 -and $blocked.Payload.results[0].reason -eq 'native-project-command-required') `
      "FT-REVIEW-01 external EditorConfig silently ignored: $($blocked.Raw)"
    Assert-NoChange $file $hash 'FT-REVIEW-01 parent policy'

    # FT-REVIEW-01 control: global root=true inside the project terminates inheritance.
    # Expected: supported Plan, no process; local terminating configuration remains authoritative.
    [IO.File]::WriteAllText((Join-Path $nested '.editorconfig'), "root = true`n[*]`nindent_size = 2`n", $utf8)
    $terminated = Invoke-Adapter $options
    Assert-True (
      $terminated.Code -eq 0 -and $terminated.Payload.results[0].status -eq 'planned'
    ) 'Global root=true did not terminate parent policy.'

    # FT-REVIEW-01 edge: section-local root=true is not a global termination directive.
    # Expected: inherited policy still blocks rather than treating arbitrary root text as authority.
    [IO.File]::WriteAllText((Join-Path $nested '.editorconfig'), "[*]`nroot = true`nindent_size = 2`n", $utf8)
    $section = Invoke-Adapter $options
    Assert-True ($section.Code -eq 2) 'Section-local root=true incorrectly terminated inheritance.'

    # FT-REVIEW-01 edge: last global root=false overrides an earlier root=true.
    # Expected: no false termination; the existing native workflow is required.
    [IO.File]::WriteAllText(
      (Join-Path $nested '.editorconfig'), "root = true`nroot = false`n[*]`nindent_size = 2`n", $utf8
    )
    $last = Invoke-Adapter $options
    Assert-True ($last.Code -eq 2) 'Earlier root=true incorrectly won over later root=false.'
  } else {
    # FT-REVIEW-02 Red: selected nested project belongs to a parent Git worktree.
    # Expected: Check blocks boundary before formatter, retaining parent-ignored original.
    & git -C $parent init -q
    Assert-True ($LASTEXITCODE -eq 0) 'Owned parent Git fixture initialization failed.'
    [IO.File]::WriteAllText((Join-Path $parent '.gitignore'), 'nested/src/file.js', $utf8)
    $options.Action = 'Check'
    $options.TrustTooling = $true
    $ignored = Invoke-Adapter $options
    Assert-True ($ignored.Code -eq 2 -and $ignored.Payload.results[0].reason -eq 'git-policy-boundary') `
      "FT-REVIEW-02 parent Git ignore silently bypassed: $($ignored.Raw)"
    Assert-NoChange $file $hash 'FT-REVIEW-02 ignored original'
  }
  $finalCalls = if (Test-Path -LiteralPath $log) { (Get-Content -LiteralPath $log).Count } else { 0 }
  Assert-True ($finalCalls -eq $initialCalls) "Policy $Kind executed formatter."
}
try {
  [IO.Directory]::CreateDirectory($project) | Out-Null
  $originalSource = "// Meaningful literal and explanation remain.`nconst message = 'UNFORMATTED';`n"
  Write-Fixture 'src/file with spaces.js' $originalSource
  Write-Fixture '.prettierrc.json' '{"printWidth":88}'
  Write-Fixture 'node_modules/prettier/package.json' `
    '{"name":"prettier","version":"0.0.0","bin":{"prettier":"bin/prettier.cjs"}}'
  $bin = Join-Path $project 'node_modules/prettier/bin/prettier.cjs'
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bin)) | Out-Null
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/formatter-prettier.cjs') `
    -Destination $bin
  $source = Join-Path $project 'src/file with spaces.js'
  $log = Join-Path $project 'tool-calls.jsonl'
  $before = Fingerprint $source
  if ($PolicyCase) {
    Test-PolicyBoundary $PolicyCase
    Write-Output "Policy $PolicyCase checks passed; native formatter acceptance not observed."
    return
  }
  Test-PolicyBoundary 'EditorConfig'
  Test-PolicyBoundary 'GitIgnore'

  # FT-02 happy: automatic selection from existing JSON config and installed local manifest.
  # Expected: default Plan identifies Prettier and never executes even its version command.
  $plan = Invoke-Adapter @{}
  Assert-True ($plan.Code -eq 0 -and $plan.Payload.action -eq 'Plan') 'Default Plan failed.'
  Assert-True ($plan.Payload.results[0].formatter -eq 'Prettier') 'Auto did not select configured Prettier.'
  Assert-True (-not (Test-Path -LiteralPath $log)) 'Plan executed formatter.'
  Assert-NoChange $source $before 'FT-02 Plan'

  # FT-03 trust/write gates: Check cannot execute without trust; Apply also needs write approval.
  # Expected: structured blocked outcome, no process log and unchanged original.
  foreach ($options in @(@{ Action = 'Check' }, @{ Action = 'Apply'; TrustTooling = $true })) {
    $denied = Invoke-Adapter $options
    Assert-True (
      $denied.Code -eq 2 -and $denied.Payload.results[0].status -eq 'blocked'
    ) 'Missing acknowledgment was not blocked.'
    Assert-True (-not (Test-Path -LiteralPath $log)) 'Unacknowledged action executed tool.'
    Assert-NoChange $source $before 'FT-03 gate'
  }

  # FT-04 complete CLI E2E: trusted Check observes change; Apply commits; second Check is clean.
  # Expected: Check1/no writes, Apply0/exact selected output, Check0; all args stay bounded.
  $check = Invoke-Adapter @{ Action = 'Check'; TrustTooling = $true }
  Assert-True (
    $check.Code -eq 1 -and $check.Payload.results[0].status -eq 'would-change'
  ) 'Check did not observe candidate change.'
  Assert-NoChange $source $before 'FT-04 Check'
  $apply = Invoke-Adapter @{ Action = 'Apply'; TrustTooling = $true; AllowWrite = $true }
  Assert-True ($apply.Code -eq 0 -and $apply.Payload.results[0].status -eq 'applied') 'Apply did not commit candidate.'
  Assert-True ([IO.File]::ReadAllText($source).Contains("const message = 'FORMATTED';")) 'Apply output missing.'
  $clean = Invoke-Adapter @{ Action = 'Check'; TrustTooling = $true }
  Assert-True (
    $clean.Code -eq 0 -and $clean.Payload.results[0].status -eq 'clean'
  ) "Second Check was not clean: $($clean.Raw)"
  $calls = Get-Content -LiteralPath $log | ForEach-Object { ,($_ | ConvertFrom-Json) }
  foreach ($call in $calls) {
    Assert-True (
      $call -notcontains '--write' -and $call -notcontains '--check'
    ) 'Tool received unsafe write/check native mode.'
  }

  # FT-06 faithful whitespace candidate: preserve a long literal and mandatory test explanation.
  # Expected: only known whitespace changes; exact comment/literal remains in output.
  # This demonstrates one controlled fixture, not external-engine semantic equivalence.
  $longLiteral = 'A meaningful URL https://example.test/a?value=' + ('x' * 180)
  $explanation = '// Scenario: exact literal remains. Expected: original string unchanged.'
  $faithfulText = "$explanation`nconst spacing=1;`nconst message = '$longLiteral';`n"
  Write-Fixture 'src/faithful.js' $faithfulText
  $faithful = Invoke-Adapter @{
    Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/faithful.js')
  }
  Assert-True ($faithful.Code -eq 0) 'Faithful candidate failed.'
  $faithfulActual = [IO.File]::ReadAllText((Join-Path $project 'src/faithful.js'))
  Assert-True (
    $faithfulActual -ceq $faithfulText.Replace('const spacing=1;', 'const spacing = 1;')
  ) 'Faithful candidate changed more than expected whitespace.'
  Assert-True (
    $faithfulActual.Contains($longLiteral) -and $faithfulActual.Contains($explanation)
  ) 'Literal/test explanation lost.'

  # FT-03 literal safety: outside, traversal and wildcard targets must not escape exact scope.
  # Expected: blocked/error/excluded row with no changes or process invocation.
  [IO.File]::WriteAllText($outside, 'UNFORMATTED', $utf8)
  $outsideHash = Fingerprint $outside
  $logHash = Fingerprint $log
  foreach ($target in @($outside, '../outside.js', 'src/*.js')) {
    $unsafe = Invoke-Adapter @{ Files = @($target) }
    Assert-True (
      $unsafe.Payload.results[0].status -in @('blocked', 'error', 'excluded')
    ) "Unsafe target accepted: $target"
    Assert-NoChange $outside $outsideHash 'FT-03 containment'
    Assert-NoChange $log $logHash 'FT-03 process prevention'
  }

  # FT-03 reparse escape: a project directory junction points to an owned outside directory.
  # Expected: reject the literal junction child, preserve target and avoid executing tools.
  $outsideDir = Join-Path $fixture 'junction-target'
  [IO.Directory]::CreateDirectory($outsideDir) | Out-Null
  $junctionSource = Join-Path $outsideDir 'file.js'
  [IO.File]::WriteAllText($junctionSource, 'UNFORMATTED', $utf8)
  $junctionHash = Fingerprint $junctionSource
  $junction = Join-Path $project 'src/junction'
  New-Item -ItemType Junction -Path $junction -Target $outsideDir | Out-Null
  try {
    $linked = Invoke-Adapter @{
      Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/junction/file.js')
    }
    Assert-True (
      $linked.Code -eq 2 -and $linked.Payload.results[0].status -in @('blocked', 'error')
    ) 'Reparse path accepted.'
    Assert-NoChange $junctionSource $junctionHash 'FT-03 reparse'
    Assert-NoChange $log $logHash 'FT-03 reparse process prevention'
  } finally {
    # Remove link itself without recursive traversal before cleaning owned fixture tree.
    if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
  }

  # FT-05 batch failure: one valid candidate and one formatter rejection.
  # Expected: Apply2 with both originals unchanged, no partial precompute writes.
  Write-Fixture 'src/first.js' "UNFORMATTED`n"
  Write-Fixture 'src/second.js' "FAIL_SENTINEL`n"
  $first = Join-Path $project 'src/first.js'
  $second = Join-Path $project 'src/second.js'
  $firstHash = Fingerprint $first
  $secondHash = Fingerprint $second
  $failed = Invoke-Adapter @{
    Action = 'Apply'; TrustTooling = $true; AllowWrite = $true
    Files = @('src/first.js', 'src/second.js')
  }
  Assert-True ($failed.Code -eq 2) 'Failed candidate did not block batch.'
  Assert-NoChange $first $firstHash 'FT-05 first candidate'
  Assert-NoChange $second $secondHash 'FT-05 failed candidate'

  # FT-06 representation: UTF-8 without/with BOM and UTF-16 LE/BE retain byte convention.
  # Expected: output keeps exact BOM absence/presence and CRLF; no null-prefix regression.
  $encodings = @(
    [Text.UTF8Encoding]::new($false), [Text.UTF8Encoding]::new($true)
    [Text.UnicodeEncoding]::new($false, $true), [Text.UnicodeEncoding]::new($true, $true)
  )
  foreach ($encoding in $encodings) {
    $representation = Join-Path $project 'src/encoding.js'
    $text = "// expected explanation`r`nUNFORMATTED`r`n"
    $bytes = @($encoding.GetPreamble()) + @($encoding.GetBytes($text))
    [IO.File]::WriteAllBytes($representation, [byte[]]$bytes)
    $result = Invoke-Adapter @{
      Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/encoding.js')
    }
    Assert-True ($result.Code -eq 0) 'Supported BOM encoding rejected.'
    $actual = [IO.File]::ReadAllBytes($representation)
    $expected = @($encoding.GetPreamble()) + @($encoding.GetBytes($text.Replace('UNFORMATTED', 'FORMATTED')))
    Assert-True (
      [Convert]::ToBase64String($actual) -ceq [Convert]::ToBase64String([byte[]]$expected)
    ) 'BOM/EOL output drift.'
  }

  # FT-06 unsupported mixed EOL / invalid UTF-8 must fail before any writes.
  # Expected: protected original bytes remain exactly identical.
  foreach ($bytes in @([byte[]](65, 13, 10, 66, 10), [byte[]](255, 128, 65))) {
    $bad = Join-Path $project 'src/bad.js'
    [IO.File]::WriteAllBytes($bad, $bytes)
    $hash = Fingerprint $bad
    $result = Invoke-Adapter @{ Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/bad.js') }
    Assert-True ($result.Code -eq 2) 'Unsupported encoding/EOL accepted.'
    Assert-NoChange $bad $hash 'FT-06 invalid representation'
  }

  # FT-02/05 selection conflicts: a second supported formatter must not be guessed away.
  # Expected: Auto Plan is blocked, does not execute either tool, and leaves source unchanged.
  Write-Fixture 'biome.json' '{}'
  $sourceHash = Fingerprint $source
  $logHash = Fingerprint $log
  $ambiguous = Invoke-Adapter @{}
  Assert-True (
    $ambiguous.Code -eq 2 -and $ambiguous.Payload.results[0].status -eq 'blocked'
  ) 'Ambiguous Auto selection accepted.'
  Assert-NoChange $source $sourceHash 'FT-02 ambiguity'
  Assert-NoChange $log $logHash 'FT-02 pure conflict Plan'
  Remove-Item -LiteralPath (Join-Path $project 'biome.json')

  # FT-03 protected metadata/generated/snapshot sources are never formatting targets.
  # Expected: reject/skip exact request and retain original bytes, including project config.
  $protectedTargets = @(
    'AGENTS.md', 'generated/file.js', 'snapshots/file.js', '.codex/file.js', 'node_modules/vendor.js'
  )
  foreach ($relative in $protectedTargets) {
    Write-Fixture $relative 'UNFORMATTED'
    $path = Join-Path $project $relative
    $hash = Fingerprint $path
    $protected = Invoke-Adapter @{
      Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @($relative)
    }
    Assert-True (
      $protected.Payload.results[0].status -in @('blocked', 'excluded', 'error')
    ) "Protected target accepted: $relative"
    Assert-NoChange $path $hash 'FT-03 protected target'
  }

  # FT-05 ignored native result: file-info says this exact target is ignored.
  # Expected: excluded row and unchanged original; formatter output is not requested.
  Write-Fixture 'src/ignored.js' 'UNFORMATTED'
  $ignored = Join-Path $project 'src/ignored.js'
  $hash = Fingerprint $ignored
  $ignoreCallsBefore = @(Get-Content -LiteralPath $log).Count
  $ignoreResult = Invoke-Adapter @{
    Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/ignored.js')
  }
  Assert-True (
    $ignoreResult.Code -eq 0 -and $ignoreResult.Payload.results[0].status -eq 'excluded'
  ) 'Native ignored file not excluded.'
  foreach ($line in @(Get-Content -LiteralPath $log | Select-Object -Skip $ignoreCallsBefore)) {
    $probeArgs = $line | ConvertFrom-Json
    Assert-True (
      $probeArgs -contains '--version' -or $probeArgs -contains '--file-info'
    ) 'Ignored file requested formatting output rather than policy probes only.'
    Assert-True ($probeArgs -notcontains '--stdin-filepath') 'Ignored file requested candidate output.'
  }
  Assert-NoChange $ignored $hash 'FT-05 ignored file'

  # FT-05 explicit missing tool and unsupported formatter have visible non-success.
  # Expected: blocked structured rows with no installation or fallback attempt.
  Write-Fixture 'src/test.py' 'UNFORMATTED'
  $missing = Invoke-Adapter @{
    Formatter = 'Ruff'; ToolPath = (Join-Path $fixture 'missing.exe'); Files = @('src/test.py')
  }
  Assert-True (
    $missing.Code -eq 2 -and $missing.Payload.results[0].status -eq 'blocked'
  ) 'Missing explicit tool did not block.'

  # FT-05 actual timeout and bounded output: trusted controlled process stalls or floods.
  # Expected: Apply errors with unchanged original, no unbounded wait/output.
  Write-Fixture 'src/limits.js' 'UNFORMATTED'
  $limits = Join-Path $project 'src/limits.js'
  foreach ($mode in @('timeout', 'oversize', 'unicode-oversize', 'fail')) {
    Write-Fixture 'tool-mode.txt' $mode
    $hash = Fingerprint $limits
    $limitTimeout = if ($mode -eq 'timeout') { 1 } else { 30 }
    $limited = Invoke-Adapter @{
      Action = 'Apply'; TrustTooling = $true; AllowWrite = $true
      Files = @('src/limits.js'); TimeoutSeconds = $limitTimeout
    }
    Assert-True ($limited.Code -eq 2) "Tool $mode did not fail closed."
    if ($mode -in @('oversize', 'unicode-oversize')) {
      Assert-True (
        $limited.Payload.results[0].reason -eq 'tool-output-limit'
      ) "Tool $mode failed for unrelated reason: $($limited.Raw)"
    }
    Assert-NoChange $limits $hash "FT-05 $mode"
  }
  # FT-06 split Unicode transport: supplementary characters split across native pipe chunks.
  # Expected: below-budget UTF-8 output survives exactly, without surrogate-state rejection.
  Write-Fixture 'tool-mode.txt' 'unicode-boundary'
  $unicode = Invoke-Adapter @{
    Action = 'Apply'; TrustTooling = $true; AllowWrite = $true; Files = @('src/limits.js')
  }
  Assert-True ($unicode.Code -eq 0) "Split Unicode candidate failed: $($unicode.Raw)"
  $unicodeExpected = $utf8.GetBytes(('A' + ('😀' * 6000)))
  Assert-True (
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($limits)) -ceq
    [Convert]::ToBase64String($unicodeExpected)
  ) 'Supplementary character bytes changed.'
  Remove-Item -LiteralPath (Join-Path $project 'tool-mode.txt')

  # FT-04 PowerShell fixed-worker transport: trusted synthetic installed PSD1 module.
  # Expected: Check detects change without writes; Apply commits only the selected PS file.
  $moduleRoot = Join-Path $fixture 'installed-module'
  [IO.Directory]::CreateDirectory($moduleRoot) | Out-Null
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/formatter-powershell.psd1') `
    -Destination (Join-Path $moduleRoot 'PSScriptAnalyzer.psd1')
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/formatter-powershell.psm1') -Destination $moduleRoot
  Write-Fixture 'src/sample.ps1' "# Expected explanation`n'UNFORMATTED'`n"
  $psFile = Join-Path $project 'src/sample.ps1'
  $psHash = Fingerprint $psFile
  $psOptions = @{
    Action = 'Check'; Formatter = 'PowerShell'; TrustTooling = $true
    ToolPath = (Join-Path $moduleRoot 'PSScriptAnalyzer.psd1'); Files = @('src/sample.ps1')
  }
  $psCheck = Invoke-Adapter $psOptions
  Assert-True (
    $psCheck.Code -eq 1 -and $psCheck.Payload.results[0].status -eq 'would-change'
  ) 'PowerShell worker Check mismatch.'
  Assert-NoChange $psFile $psHash 'FT-04 PowerShell Check'
  $psOptions.Action = 'Apply'
  $psOptions.AllowWrite = $true
  $psApply = Invoke-Adapter $psOptions
  Assert-True (
    $psApply.Code -eq 0 -and [IO.File]::ReadAllText($psFile).Contains("'FORMATTED'")
  ) 'PowerShell worker Apply mismatch.'

  # FT-07 actual payload recovery: deploy real adapter/worker bytes into fake homes then downgrade.
  # Expected: installed bytes equal source; downgrade removes both new helpers and retains old/personal data.
  $oldPackage = Join-Path $fixture 'old-package'
  $newPackage = Join-Path $fixture 'new-package'
  foreach ($package in @($oldPackage, $newPackage)) {
    [IO.Directory]::CreateDirectory((Join-Path $package 'agents')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $package 'skills/team-core/scripts')) | Out-Null
    # Both managed sets must be nonempty; this is data, not a native Codex profile claim.
    [IO.File]::WriteAllText(
      (Join-Path $package 'agents/team-fixture.toml'), 'name = "team-fixture"', $utf8
    )
    [IO.File]::WriteAllText(
      (Join-Path $package 'skills/team-core/SKILL.md'),
      "---`nname: team-core`ndescription: Controlled recovery package.`n---`n# Core`n", $utf8
    )
    [IO.File]::WriteAllText(
      (Join-Path $package 'skills/team-core/scripts/old.ps1'), '# Preserved old payload.', $utf8
    )
  }
  [IO.File]::WriteAllText((Join-Path $oldPackage 'VERSION'), '1.0.2', $utf8)
  [IO.File]::WriteAllText((Join-Path $newPackage 'VERSION'), '1.0.3', $utf8)
  $worker = Join-Path $root 'skills/team-core/scripts/format-code-powershell.ps1'
  foreach ($entry in @($helper, $worker)) {
    Assert-True (Test-Path -LiteralPath $entry -PathType Leaf) 'Installed helper/worker asset missing.'
    Copy-Item -LiteralPath $entry `
      -Destination (Join-Path $newPackage ('skills/team-core/scripts/' + [IO.Path]::GetFileName($entry)))
  }
  $fakeCodex = Join-Path $fixture 'fake-codex'
  $fakeAgents = Join-Path $fixture 'fake-agents'
  $manager = Join-Path $root 'scripts/deploy-user.ps1'
  $deployArgs = @{ CodexHome = $fakeCodex; AgentsHome = $fakeAgents }
  & $manager -Action Deploy -SourceRoot $oldPackage @deployArgs | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $fakeAgents 'skills/personal')) | Out-Null
  $personal = Join-Path $fakeAgents 'skills/personal/SKILL.md'
  [IO.File]::WriteAllText($personal, '# Personal untouched', $utf8)
  $personalHash = Fingerprint $personal
  & $manager -Action Deploy -SourceRoot $newPackage @deployArgs | Out-Null
  foreach ($entry in @($helper, $worker)) {
    $installed = Join-Path $fakeAgents ('skills/team-core/scripts/' + [IO.Path]::GetFileName($entry))
    Assert-True ((Fingerprint $entry) -ceq (Fingerprint $installed)) 'Installed formatter byte mismatch.'
  }
  & $manager -Action Deploy -SourceRoot $oldPackage @deployArgs | Out-Null
  foreach ($entry in @($helper, $worker)) {
    $removedPath = Join-Path $fakeAgents ('skills/team-core/scripts/' + [IO.Path]::GetFileName($entry))
    Assert-True (-not (Test-Path -LiteralPath $removedPath)) 'Downgrade left formatter helper residue.'
  }
  Assert-True (
    (Fingerprint (Join-Path $oldPackage 'skills/team-core/scripts/old.ps1')) -ceq
    (Fingerprint (Join-Path $fakeAgents 'skills/team-core/scripts/old.ps1'))
  ) 'Downgrade lost old payload.'
  Assert-NoChange $personal $personalHash 'FT-07 personal preservation'
  & $manager -Action Verify @deployArgs | Out-Null
  Write-Output 'FT-01..07 and policy checks passed; native formatter/Agent acceptance pending.'
} finally {
  # Delete only this test-created exact root after validating absolute temp containment.
  $resolved = [IO.Path]::GetFullPath($fixture)
  if ($resolved.StartsWith($tempParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
      [IO.Path]::GetFileName($resolved) -like 'codex-formatter-test-*') {
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  } else { throw 'Unsafe fixture cleanup target.' }
  Assert-True (-not (Test-Path -LiteralPath $fixture)) 'Formatter fixture cleanup incomplete.'
}
