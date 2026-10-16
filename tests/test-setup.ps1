# Setup contract tests use a local protocol fixture, never an active Codex client.
# The OS-launcher mock is confined to AST-loaded functions in this test process;
# production scripts expose no network-isolation bypass or test environment flag.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$EnvironmentOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$setupScript = Join-Path $repo 'scripts/setup-user.ps1'
$launcher = Join-Path $repo 'scripts/setup.sh'
$temporaryParent = Get-TestTemporaryParent
$testRoot = Join-Path $temporaryParent ('codex-setup-test-' + [guid]::NewGuid().ToString('N'))
$pwsh = Get-TestPowerShell
$caseCount = 0
$expectedSkillCount = @(Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory).Count

function Assert-Setup([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Get-SetupTestFingerprint([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return '<absent>' }
  return ((Get-ChildItem -LiteralPath $Path -File -Recurse -Force | ForEach-Object {
    ($_.FullName.Substring($Path.Length) -replace '\\','/') + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  } | Sort-Object) -join "`n")
}

function New-SetupScenario([string]$Mode = 'good') {
  $fixture = Join-Path $testRoot ('client 空格 ' + [guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $fixture
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'helpers/setup-fake-codex.ps1') -Destination $fixture
  @{mode=$Mode;personalHome=$script:personalHome;expectedPathEntry=$script:ExpectedPathEntry} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixture 'scenario.json')
  return $fixture
}

function Assert-SetupFixtureStopped([string]$Fixture) {
  $path = Join-Path $Fixture 'observed.jsonl'
  if (-not (Test-Path -LiteralPath $path)) { return }
  foreach ($observation in @(Get-Content -LiteralPath $path | ForEach-Object { $_ | ConvertFrom-Json })) {
    Assert-Setup ($observation.privateEnvironmentAbsent -and $observation.freshHome -and $observation.freshCodexHome -and $observation.freshXdgHome) 'Client inherited private environment or non-disposable homes.'
    Assert-Setup $observation.expectedPathAvailable 'Client lost the approved executable search path or its safe fallback.'
    Assert-Setup $observation.powershellStartupPrivate 'Client runner omitted PowerShell startup telemetry/update opt-outs.'
    Assert-Setup ($null -eq (Get-Process -Id $observation.pid -ErrorAction SilentlyContinue)) 'A setup fixture process survived cleanup.'
  }
}

function Invoke-SetupShell([string[]]$Arguments, [hashtable]$Environment = @{}, [int]$TimeoutSeconds = 30) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = '/bin/sh'
  $info.UseShellExecute = $false
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($argument in @($launcher) + $Arguments) { $info.ArgumentList.Add($argument) }
  foreach ($key in $Environment.Keys) { $info.Environment[$key] = [string]$Environment[$key] }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw 'Owned setup shell fixture timed out.'
    }
    return @{ExitCode=$process.ExitCode;Output=$stdout.GetAwaiter().GetResult();Errors=$stderr.GetAwaiter().GetResult()}
  } finally { $process.Dispose() }
}

function Invoke-SetupCase([string]$Mode='good', [string]$Action='Doctor', [string]$CodexHome, [string]$AgentsHome, [bool]$Preview=$false, [bool]$Force=$false, [int]$Timeout=120) {
  $fixture = New-SetupScenario $Mode
  $report = Invoke-SetupMain -Action $Action -CodexPath (Join-Path $fixture 'setup-fake-codex.ps1') -CodexHome $CodexHome -AgentsHome $AgentsHome -Preview $Preview -Force $Force -TimeoutSeconds $Timeout
  Assert-Setup ($report.schemaVersion -eq 1 -and $report.action -eq $Action) 'Setup returned the wrong report schema/action.'
  Assert-Setup ($report.cleanup.processesStopped -and $report.cleanup.scratchRemoved) 'Setup did not confirm process and scratch cleanup.'
  $serialized = $report | ConvertTo-Json -Depth 20
  Assert-Setup ($serialized -notmatch 'FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE|SETUP_PRIVATE_VALUE') 'Setup exposed raw private diagnostics or inherited environment.'
  Assert-Setup (-not $serialized.Contains($script:personalHome)) 'Setup serialized a private home path.'
  Assert-SetupFixtureStopped $fixture
  foreach ($path in $script:OwnedSetupScratch) { Assert-Setup (-not (Test-Path -LiteralPath $path)) 'Setup left an owned scratch directory.' }
  $script:caseCount++
  return $report
}

try {
  $null = New-Item -ItemType Directory -Path $testRoot
  $script:personalHome = Join-Path $testRoot 'personal sentinel'
  $null = New-Item -ItemType Directory -Path (Join-Path $personalHome '.codex') -Force
  [IO.File]::WriteAllText((Join-Path $personalHome '.codex/auth.json'), '{"fixture":"must remain untouched"}')
  [IO.File]::WriteAllText((Join-Path $personalHome '.codex/config.toml'), '# personal fixture must remain untouched')
  $personalBefore = Get-SetupTestFingerprint $personalHome

  # Both public entrypoints must exist before loading the isolated test contract.
  Assert-Setup (Test-Path -LiteralPath $setupScript -PathType Leaf) 'Setup PowerShell entrypoint is missing.'
  Assert-Setup (Test-Path -LiteralPath $launcher -PathType Leaf) 'Setup shell entrypoint is missing.'

  if (-not $IsWindows) {
    # Missing dependencies must explain how to proceed without an installer,
    # download, authentication request, or mutation of either supplied home.
    $emptyPath = Join-Path $testRoot 'empty-path'
    $null = New-Item -ItemType Directory -Path $emptyPath
    $missingShell = Invoke-SetupShell @() @{PATH=$emptyPath}
    Assert-Setup ($missingShell.ExitCode -ne 0 -and ($missingShell.Errors + $missingShell.Output) -match '(?i)(PowerShell|pwsh)') 'Shell launcher did not explain missing PowerShell.'
    $caseCount++

    # A local echo fixture records argv without evaluating it. Spaces, Unicode,
    # shell metacharacters, and PowerShell flags must remain separate arguments.
    $echoShell = Join-Path $testRoot 'pwsh 参数 with spaces'
    $echoCode=@'
#!/bin/sh
printf '%s\n' "$@"
printf 'SETUP_TELEMETRY=%s\n' "${POWERSHELL_TELEMETRY_OPTOUT-unset}"
printf 'SETUP_UPDATECHECK=%s\n' "${POWERSHELL_UPDATECHECK-unset}"
'@
    [IO.File]::WriteAllText($echoShell, $echoCode+"`n", [Text.UTF8Encoding]::new($false))
    & /bin/chmod 700 $echoShell
    $literalHome = Join-Path $testRoot 'home 中文 $literal; untouched'
    $forwarded = Invoke-SetupShell @('--pwsh',$echoShell,'-Action','Doctor','-CodexHome',$literalHome,'-AgentsHome',(Join-Path $testRoot 'agents spaced'),'-Json','-WhatIf') @{POWERSHELL_TELEMETRY_OPTOUT='0';POWERSHELL_UPDATECHECK='Default'}
    Assert-Setup ($forwarded.ExitCode -eq 0) 'Explicit PowerShell path with spaces failed.'
    $lines = @($forwarded.Output -split '\r?\n' | Where-Object { $_ -ne '' })
    foreach ($value in @('-Action','Doctor','-CodexHome',$literalHome,'-Json','-WhatIf')) {
      Assert-Setup ($lines -ccontains $value) 'Shell launcher changed a forwarded argument.'
    }
    Assert-Setup ($lines -ccontains 'SETUP_TELEMETRY=1' -and $lines -ccontains 'SETUP_UPDATECHECK=Off') 'Shell launcher did not override PowerShell startup telemetry/update settings.'
    Assert-Setup (-not (Test-Path -LiteralPath $literalHome)) 'Shell argument forwarding executed or created the supplied home.'
    $caseCount++
  }

  # Load only function definitions from the trusted source. The entrypoint's
  # parameter defaults, ShouldProcess, installation and exit statements never run.
  $tokens=$null; $parseErrors=$null
  $ast=[Management.Automation.Language.Parser]::ParseFile($setupScript,[ref]$tokens,[ref]$parseErrors)
  Assert-Setup (@($parseErrors).Count -eq 0) 'Setup PowerShell source has parser errors.'
  Assert-Setup ($ast.ScriptRequirements.RequiredPSVersion.Major -ge 7) 'Setup does not require PowerShell 7 or newer before execution.'
  foreach ($definition in $ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] }) {
    Invoke-Expression $definition.Extent.Text
  }
  foreach ($functionName in @('Start-SetupClient','Invoke-SetupManager')) {
    $definition=@($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $functionName })[0]
    $assignments=$definition.Body.FindAll({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst]},$true)
    foreach ($pair in @(@('POWERSHELL_TELEMETRY_OPTOUT',"'1'"),@('POWERSHELL_UPDATECHECK',"'Off'"))) {
      $matching=@($assignments | Where-Object { $_.Left.Extent.Text -ceq ("`$info.Environment['"+$pair[0]+"']") -and $_.Right.Extent.Text -ceq $pair[1] })
      Assert-Setup ($matching.Count -eq 1) "$functionName must explicitly enforce both PowerShell startup opt-outs, independently of inheritance."
    }
  }
  $managerProbe=Join-Path $testRoot 'manager startup environment.ps1'
  [IO.File]::WriteAllText($managerProbe, '[Console]::Out.WriteLine((@{telemetryDisabled=($env:POWERSHELL_TELEMETRY_OPTOUT -ceq ''1'');updatesDisabled=($env:POWERSHELL_UPDATECHECK -ceq ''Off'')} | ConvertTo-Json -Compress))')
  $managerEnvironment=(Invoke-SetupManager $managerProbe @() 120) | ConvertFrom-Json
  Assert-Setup ($managerEnvironment.telemetryDisabled -and $managerEnvironment.updatesDisabled) 'Manager child did not receive PowerShell startup opt-outs.'
  $caseCount++
  $script:SetupRoot=$repo
  $script:SetupCodexHome=Join-Path $testRoot 'sandbox-selected-codex'
  $realSandbox=${function:Get-SetupSandbox}
  if ($IsMacOS) {
    Assert-Setup ((Resolve-SetupPath '/tmp/setup fixture') -ceq '/private/tmp/setup fixture') 'macOS /tmp alias did not canonicalize safely.'
    Assert-Setup ((Resolve-SetupPath '/var/setup fixture') -ceq '/private/var/setup fixture') 'macOS /var alias did not canonicalize safely.'
    $caseCount++
  }

  if ($IsWindows) {
    $unsupported=Invoke-SetupMain -Action Doctor -CodexPath (Join-Path $testRoot 'unused') -CodexHome (Join-Path $testRoot 'codex') -AgentsHome (Join-Path $testRoot 'agents')
    Assert-Setup (-not $unsupported.success -and 'unsupported_platform' -in $unsupported.errors) 'POSIX setup did not clearly reject an unsupported host.'
    $caseCount++
    Write-Host 'POSIX shell and protocol fixtures are not applicable on Windows; existing Windows installer coverage remains active.'
  } else {
    # Inspect the actual OS confinement builder without starting any executable.
    $sandboxRoot=Join-Path $testRoot 'sandbox inspect'
    $null=New-Item -ItemType Directory -Path (Join-Path $sandboxRoot 'empty') -Force
    if ($IsMacOS) {
      $sandbox=& $realSandbox $sandboxRoot $pwsh (Join-Path $testRoot 'no-skills')
      $policy=Get-Content -LiteralPath $sandbox.Prefix[1] -Raw
      Assert-Setup ($sandbox.Launcher -eq '/usr/bin/sandbox-exec' -and $policy.Contains('(deny network*)') -and $policy.Contains('(deny file-write*)') -and $policy.Contains('(allow file-write* (subpath ')) 'macOS sandbox lacks network/write confinement.'
    } else {
      $bubblewrap=Get-Command bwrap -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($bubblewrap) {
        $sandbox=& $realSandbox $sandboxRoot $pwsh (Join-Path $testRoot 'no-skills')
        foreach ($required in @('--unshare-user','--unshare-pid','--unshare-net','--die-with-parent','--ro-bind')) {
          Assert-Setup ($required -in $sandbox.Prefix) 'Linux sandbox lacks a required namespace/read-only boundary.'
        }
      } else {
        $sandboxFailed=$false
        try { & $realSandbox $sandboxRoot $pwsh (Join-Path $testRoot 'no-skills') | Out-Null } catch { $sandboxFailed=$_.Exception.Message -eq 'sandbox_unavailable' }
        Assert-Setup $sandboxFailed 'Missing Bubblewrap did not fail closed.'
      }
    }
    $caseCount++

    # This one scoped mock replaces only the native launcher. The real client
    # transport, timeout, environment, discovery and transactional installer run.
    $script:OwnedSetupScratch=[Collections.Generic.List[string]]::new()
    function Get-SetupSandbox($Scratch,$CodexPath,$SkillsRoot) {
      $script:OwnedSetupScratch.Add($Scratch)
      if ($script:SetupSandboxFailure) { throw 'sandbox_unavailable' }
      return @{Launcher=$script:pwsh;Prefix=@('-NoLogo','-NoProfile','-NonInteractive','-File')}
    }
    $script:SetupSandboxFailure=$false
    $priorPrivate=$env:SETUP_PRIVATE_SENTINEL
    $priorPath=$env:PATH
    $script:ExpectedPathEntry=Join-Path $testRoot 'runtime search 空格'
    $null=New-Item -ItemType Directory -Path $script:ExpectedPathEntry
    $env:PATH=$script:ExpectedPathEntry+[IO.Path]::PathSeparator+$priorPath
    $env:SETUP_PRIVATE_SENTINEL='SETUP_PRIVATE_VALUE'
    try {
      $codex=Join-Path $testRoot 'selected codex 中文'
      $agents=Join-Path $testRoot 'selected agents 空格'

      $doctor=Invoke-SetupCase -CodexHome $codex -AgentsHome $agents
      Assert-Setup ($doctor.success -and $doctor.status -eq 'ready' -and $doctor.prerequisites.powershell -and $doctor.prerequisites.codex -and $doctor.prerequisites.protocol) ('Doctor did not confirm healthy prerequisites: ' + ($doctor | ConvertTo-Json -Depth 8 -Compress))
      Assert-Setup (-not $doctor.installation.attempted -and -not (Test-Path $codex) -and -not (Test-Path $agents)) 'Doctor installed or changed supplied homes.'
      # OD05 negative action: readiness is not an installation event.
      # Expected: Doctor guidance does not advertise a completed optional integration.
      Assert-Setup (
        ($doctor.guidance -join "`n") -notmatch 'impeccable\.(style)|pbakaus/impeccable'
      ) 'Doctor emitted install-only optional guidance.'

      $inheritedPath=$env:PATH; $expectedPath=$script:ExpectedPathEntry
      try {
        $env:PATH=''; $script:ExpectedPathEntry='/usr/bin'
        $fallback=Invoke-SetupCase -CodexHome $codex -AgentsHome $agents
        Assert-Setup $fallback.success 'Doctor could not use the system executable-path fallback.'
      } finally { $env:PATH=$inheritedPath; $script:ExpectedPathEntry=$expectedPath }

      if (-not $EnvironmentOnly) {
      $missing=Invoke-SetupMain -CodexPath (Join-Path $testRoot 'missing client') -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $missing.success -and 'codex_missing' -in $missing.errors -and $missing.guidance.Count -gt 0) 'Missing client lacks explicit failure and guidance.'
      $caseCount++
      $script:SetupSandboxFailure=$true
      $blocked=Invoke-SetupCase -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $blocked.success -and 'sandbox_unavailable' -in $blocked.errors -and -not $blocked.installation.attempted) 'Sandbox unavailability did not stop before installation.'
      $script:SetupSandboxFailure=$false

      foreach ($row in @(@('bad-version','client_version_invalid'),@('bad-json','client_protocol_invalid'),@('rpc-error','client_protocol_error'),@('missing-capability','client_protocol_error'),@('wrong-cwd','client_protocol_invalid'),@('exit','client_protocol_closed'))) {
        $failed=Invoke-SetupCase -Mode $row[0] -Action Install -CodexHome $codex -AgentsHome $agents
        Assert-Setup (-not $failed.success -and $row[1] -in $failed.errors -and -not $failed.installation.attempted) "Protocol case $($row[0]) did not fail before mutation with its expected category."
        Assert-Setup (-not (Test-Path $codex) -and -not (Test-Path $agents)) 'Incompatible client changed installation homes.'
      }
      $timer=[Diagnostics.Stopwatch]::StartNew()
      $timedOut=Invoke-SetupCase -Mode timeout -Action Install -CodexHome $codex -AgentsHome $agents -Timeout 1
      Assert-Setup (-not $timedOut.success -and 'client_timeout' -in $timedOut.errors -and $timer.Elapsed.TotalSeconds -lt 15) 'Protocol timeout was not bounded and explicit.'

      $preview=Invoke-SetupCase -Action Install -CodexHome $codex -AgentsHome $agents -Preview $true
      Assert-Setup ($preview.success -and $preview.status -eq 'what_if' -and $preview.installation.preview -and -not $preview.installation.attempted) 'Install preview status is incorrect.'
      Assert-Setup (-not (Test-Path $codex) -and -not (Test-Path $agents)) 'Install preview created target files.'
      # OD06 preview: optional install advice is reserved for completed installation.
      # Expected: successful WhatIf has no install-only provider reminder.
      Assert-Setup (
        ($preview.guidance -join "`n") -notmatch 'impeccable\.(style)|pbakaus/impeccable'
      ) 'Setup preview emitted install-only optional guidance.'

      $installed=Invoke-SetupCase -Action Install -CodexHome $codex -AgentsHome $agents
      Assert-Setup ($installed.success -and $installed.status -eq 'installed_verified' -and $installed.installation.attempted -and $installed.installation.verified -and $installed.discovery.passed -and $installed.discovery.expectedCount -eq $expectedSkillCount -and $installed.discovery.matchedCount -eq $expectedSkillCount) 'Install did not verify receipt and every source Skill.'
      $receiptPath=Join-Path $agents 'codex-multi-agent/install-receipt.json'
      Assert-Setup (Test-Path -LiteralPath $receiptPath) 'Setup installation omitted its managed receipt.'
      # OD05 successful setup: add a non-blocking optional provider reminder once.
      # Expected: report remains successful with one optional official-provider link.
      $optionalGuidance = @($installed.guidance | Where-Object {
        $_ -match 'impeccable\.(style)|pbakaus/impeccable'
      })
      Assert-Setup (
        $optionalGuidance.Count -eq 1 -and $optionalGuidance[0] -match '(?i)optional'
      ) 'Verified setup omitted/duplicated optional guidance.'
      $beforeCodex=Get-SetupTestFingerprint $codex; $beforeAgents=Get-SetupTestFingerprint $agents

      $verified=Invoke-SetupCase -Action Verify -CodexHome $codex -AgentsHome $agents
      Assert-Setup ($verified.success -and $verified.status -eq 'verified' -and $verified.discovery.passed -and -not $verified.installation.attempted) 'Verify did not validate the selected existing installation.'
      Assert-Setup ((Get-SetupTestFingerprint $codex) -eq $beforeCodex -and (Get-SetupTestFingerprint $agents) -eq $beforeAgents) 'Read-only verification changed installed files.'
      # OD05 read-only verification: a healthy existing installation is not a new install.
      # Expected: Verify does not emit the install-only optional reminder.
      Assert-Setup (
        ($verified.guidance -join "`n") -notmatch 'impeccable\.(style)|pbakaus/impeccable'
      ) 'Verify emitted install-only optional guidance.'

      foreach ($mode in @('missing-skill','disabled-skill','wrong-path','duplicate-skill','string-enabled','skill-errors')) {
        $failed=Invoke-SetupCase -Mode $mode -Action Verify -CodexHome $codex -AgentsHome $agents
        $expected=if ($mode -eq 'skill-errors') {'skill_discovery_errors'} else {'skill_discovery_mismatch'}
        Assert-Setup (-not $failed.success -and $expected -in $failed.errors) "Discovery case $mode was accepted or misclassified."
        Assert-Setup ((Get-SetupTestFingerprint $codex) -eq $beforeCodex -and (Get-SetupTestFingerprint $agents) -eq $beforeAgents) 'Failed verification changed installed payloads.'
      }

      $agentFile=Join-Path $codex 'agents/team-architect.toml'
      [IO.File]::WriteAllText($agentFile,'# setup fixture user customization')
      $conflictBefore=Get-SetupTestFingerprint $codex
      $conflict=Invoke-SetupCase -Action Install -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $conflict.success -and 'installer_failed' -in $conflict.errors -and (Get-SetupTestFingerprint $codex) -eq $conflictBefore) 'Setup replaced a conflicting user file without Force.'
      # OD06 failed deployment: preserve error guidance, never add install-only advice.
      # Expected: conflict is still failure without optional-success reminder.
      Assert-Setup (
        ($conflict.guidance -join "`n") -notmatch 'impeccable\.(style)|pbakaus/impeccable'
      ) 'Failed setup emitted install-only optional guidance.'
      $forced=Invoke-SetupCase -Action Install -CodexHome $codex -AgentsHome $agents -Force $true
      Assert-Setup ($forced.success -and $forced.installation.verified) 'Explicit Force did not recover a conflicting managed install.'
      $backups=@(Get-ChildItem -LiteralPath (Join-Path $agents 'codex-multi-agent/backups') -Filter 'team-architect.toml' -File -Recurse | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -eq '# setup fixture user customization' })
      Assert-Setup ($backups.Count -gt 0) 'Explicit Force did not preserve the modified file in a backup.'

      # Parse errors in installed instructions are repairable managed conflicts.
      # The fake client reads the selected files; Force must reach the installer,
      # retain the damaged bytes, and then pass strict fresh-client discovery.
      $damagedSkill=Join-Path $agents 'skills/team-review/SKILL.md'
      $damagedText='invalid setup fixture frontmatter'
      [IO.File]::WriteAllText($damagedSkill,$damagedText)
      $damagedBefore=Get-SetupTestFingerprint $agents
      $parseFailure=Invoke-SetupCase -Mode parse-skills -Action Verify -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $parseFailure.success -and 'skill_discovery_errors' -in $parseFailure.errors -and (Get-SetupTestFingerprint $agents) -eq $damagedBefore) 'Strict verification accepted or changed a malformed installed Skill.'
      $unforcedRepair=Invoke-SetupCase -Mode parse-skills -Action Install -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $unforcedRepair.success -and 'installer_failed' -in $unforcedRepair.errors -and (Get-SetupTestFingerprint $agents) -eq $damagedBefore) 'Repair replaced damaged managed instructions without explicit Force.'
      $repairPreview=Invoke-SetupCase -Mode parse-skills -Action Install -CodexHome $codex -AgentsHome $agents -Preview $true -Force $true
      Assert-Setup ($repairPreview.success -and -not $repairPreview.installation.attempted -and (Get-SetupTestFingerprint $agents) -eq $damagedBefore) 'Force preview could not inspect a damaged Skill without changing it.'
      $repaired=Invoke-SetupCase -Mode parse-skills -Action Install -CodexHome $codex -AgentsHome $agents -Force $true
      Assert-Setup ($repaired.success -and $repaired.installation.verified -and $repaired.discovery.passed -and (Get-Content -LiteralPath $damagedSkill -Raw) -ceq (Get-Content -LiteralPath (Join-Path $repo 'skills/team-review/SKILL.md') -Raw)) 'Force did not repair malformed managed instructions and verify their discovery.'
      $damagedBackups=@(Get-ChildItem -LiteralPath (Join-Path $agents 'codex-multi-agent/backups') -Filter 'SKILL.md' -File -Recurse | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -ceq $damagedText })
      Assert-Setup ($damagedBackups.Count -eq 1) 'Force repair did not preserve the damaged Skill bytes in its before-image.'

      $postFailure=Invoke-SetupCase -Mode skill-errors -Action Install -CodexHome (Join-Path $testRoot 'post-error codex') -AgentsHome (Join-Path $testRoot 'post-error agents')
      Assert-Setup (-not $postFailure.success -and $postFailure.installation.attempted -and $postFailure.installation.verified -and 'skill_discovery_errors' -in $postFailure.errors) 'Protocol readiness hid discovery errors in the strict post-install probe.'
      # OD06 post-install probe failure: deployment alone is not setup success.
      # Expected: a later discovery failure suppresses install-only optional advice.
      Assert-Setup (
        ($postFailure.guidance -join "`n") -notmatch 'impeccable\.(style)|pbakaus/impeccable'
      ) 'Failed post-install discovery emitted optional guidance.'

      # A later valid Skill extends the expected inventory without a count edit.
      # Reuse the complete isolated validator fixture, then install all resources.
      $expandedSource=Join-Path $testRoot 'expanded source'
      $null=New-Item -ItemType Directory -Path $expandedSource
      foreach ($item in @('agents','skills','scripts','VERSION','CHANGELOG.md','CHANGELOG.zh-CN.md')) {
        Copy-Item -LiteralPath (Join-Path $repo $item) -Destination $expandedSource -Recurse
      }
      foreach ($relative in @('docs/formatter-tool.md','docs/verification/active/formatter-tool.md')) {
        $destination=Join-Path $expandedSource $relative
        $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $destination
      }
      $extraDirectory=Join-Path $expandedSource 'skills/setup-extra-fixture'
      $null=New-Item -ItemType Directory -Path $extraDirectory
      $extraContent="---`nname: setup-extra-fixture`ndescription: Local setup inventory regression.`n---`n`n## When to activate`nUse for the isolated inventory test.`n`n## Output contract`nReport the test result.`n`n[Execution contract](../team-core/references/execution-contract.md)`n"
      [IO.File]::WriteAllText((Join-Path $extraDirectory 'SKILL.md'),$extraContent)
      try {
        $script:SetupRoot=$expandedSource
        $expandedCodex=Join-Path $testRoot 'expanded codex'
        $expandedAgents=Join-Path $testRoot 'expanded agents'
        $expanded=Invoke-SetupCase -Mode parse-skills -Action Install -CodexHome $expandedCodex -AgentsHome $expandedAgents
        Assert-Setup ($expanded.success -and $expanded.discovery.expectedCount -eq ($expectedSkillCount+1) -and $expanded.discovery.matchedCount -eq ($expectedSkillCount+1) -and (Get-Content -LiteralPath (Join-Path $expandedAgents 'skills/setup-extra-fixture/SKILL.md') -Raw) -ceq $extraContent) 'Setup omitted an additional valid source Skill or retained a fixed expected count.'
        Remove-Item -LiteralPath (Join-Path $extraDirectory 'SKILL.md')
        $missingEntry=Invoke-SetupCase -Action Install -CodexHome (Join-Path $testRoot 'invalid source codex') -AgentsHome (Join-Path $testRoot 'invalid source agents')
        Assert-Setup (-not $missingEntry.success -and 'source_skills_invalid' -in $missingEntry.errors -and -not $missingEntry.installation.attempted) 'Source inventory silently ignored a Skill directory missing its entrypoint.'
      } finally { $script:SetupRoot=$repo }

      # Exercise the actual native-OS layout decision using only owned private
      # roots. Unsupported layouts must stop before context/probe/installer calls,
      # including a missing installation and WhatIf, without relaxing the mask.
      $layoutRoot=Join-Path $testRoot 'private layout fixtures'
      $privateConfig=Join-Path $layoutRoot '.config'
      $privateCodex=Join-Path $layoutRoot '.codex'
      $selectedPrivateCodex=Join-Path $layoutRoot 'selected codex'
      foreach ($path in @($privateConfig,$privateCodex,$selectedPrivateCodex)) {
        $null=New-Item -ItemType Directory -Path $path -Force
        [IO.File]::WriteAllText((Join-Path $path 'private-sentinel'),'owned private fixture must remain unchanged')
      }
      $layoutBefore=Get-SetupTestFingerprint $layoutRoot
      $privateRootFunction=${function:Get-SetupPrivateRoots}
      $probeFunction=${function:Invoke-SetupProbe}
      $managerFunction=${function:Invoke-SetupManager}
      $script:SetupLayoutPrivateRoots=@($privateConfig,$privateCodex,$selectedPrivateCodex)
      $script:SetupLayoutProbeCalls=0; $script:SetupLayoutManagerCalls=0
      function Get-SetupPrivateRoots { return $script:SetupLayoutPrivateRoots }
      function Invoke-SetupProbe { $script:SetupLayoutProbeCalls++; throw 'unexpected_layout_probe' }
      function Invoke-SetupManager { $script:SetupLayoutManagerCalls++; throw 'unexpected_layout_installer' }
      try {
        $layoutClient=Join-Path (New-SetupScenario) 'setup-fake-codex.ps1'
        $layouts=@($privateConfig,$privateCodex,$selectedPrivateCodex | ForEach-Object { Join-Path $_ 'kit-agents' })
        if ($IsMacOS) { $layouts+=Join-Path $layoutRoot '.CONFIG/kit-agents' }
        foreach ($selectedAgents in $layouts) {
          foreach ($row in @(@('Doctor',$false),@('Install',$false),@('Install',$true),@('Verify',$false))) {
            $scratchBefore=$script:OwnedSetupScratch.Count
            $rejected=Invoke-SetupMain -Action $row[0] -Preview $row[1] -CodexPath $layoutClient -CodexHome (Join-Path $testRoot 'layout client codex') -AgentsHome $selectedAgents
            Assert-Setup (-not $rejected.success -and 'unsupported_agents_layout' -in $rejected.errors -and $rejected.guidance.Count -gt 0 -and -not $rejected.installation.attempted -and $script:SetupLayoutProbeCalls -eq 0 -and $script:SetupLayoutManagerCalls -eq 0 -and $script:OwnedSetupScratch.Count -eq $scratchBefore) 'A masked private layout was not rejected before client/context/installer activity.'
            Assert-Setup ((Get-SetupTestFingerprint $layoutRoot) -ceq $layoutBefore) 'Unsupported layout checking changed private fixture bytes.'
            $caseCount++
          }
        }
        # Equality and ancestor overlap use selected CodexHome-like fixture roots.
        $equalSkills=Join-Path $layoutRoot 'equal agents/skills'
        $ancestorSkills=Join-Path $layoutRoot 'ancestor agents/skills'
        foreach ($row in @(@($equalSkills,$equalSkills),@((Join-Path $ancestorSkills 'private child'),$ancestorSkills))) {
          $script:SetupLayoutPrivateRoots=@($row[0])
          $rejected=$false
          try { Assert-SetupSkillsLayout $row[1] } catch { $rejected=$_.Exception.Message -ceq 'unsupported_agents_layout' }
          Assert-Setup $rejected 'Private-layout equality/ancestor overlap was accepted.'
          $caseCount++
        }
        $script:SetupLayoutPrivateRoots=@($privateConfig)
        Assert-SetupSkillsLayout (Join-Path $layoutRoot '.config-kit/skills')
        $caseCount++
        if ($IsLinux) {
          Assert-SetupSkillsLayout (Join-Path $layoutRoot '.CONFIG/skills')
          $caseCount++
        }
      } finally {
        if ($privateRootFunction) { Set-Item -LiteralPath function:Get-SetupPrivateRoots -Value $privateRootFunction } else { Remove-Item -LiteralPath function:Get-SetupPrivateRoots }
        Set-Item -LiteralPath function:Invoke-SetupProbe -Value $probeFunction
        Set-Item -LiteralPath function:Invoke-SetupManager -Value $managerFunction
      }

      $receipt=Get-Content -LiteralPath $receiptPath -Raw
      [IO.File]::WriteAllText($receiptPath,'{"schemaVersion":999}')
      $badReceipt=Invoke-SetupCase -Action Verify -CodexHome $codex -AgentsHome $agents
      Assert-Setup (-not $badReceipt.success -and -not $badReceipt.installation.verified) 'Verify accepted a malformed managed receipt.'
      [IO.File]::WriteAllText($receiptPath,$receipt)

      # The client can write in its scratch project. A reported alias path is
      # valid only while that exact alias still points to the selected Skills.
      $aliasContext=New-SetupContext $pwsh (Join-Path $agents 'skills')
      $alias=Join-Path $aliasContext.Probe '.agents/skills'
      $names=@(Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory | Select-Object -ExpandProperty Name)
      $aliasSkills=@($names | ForEach-Object { @{name=$_;enabled=$true;path=(Join-Path $alias "$_/SKILL.md")} })
      try {
        Assert-Setup ((Test-SetupDiscovery $aliasContext $aliasSkills $names).passed) 'Intact owned discovery alias was rejected.'
        $caseCount++
        Remove-TestLink $alias
        Assert-Setup (-not (Test-SetupDiscovery $aliasContext $aliasSkills $names).passed) 'Discovery accepted a deleted alias reported by the client.'
        $caseCount++
        $null=New-Item -ItemType Directory -Path $alias
        Assert-Setup (-not (Test-SetupDiscovery $aliasContext $aliasSkills $names).passed) 'Discovery accepted an alias replaced by an ordinary directory.'
        $caseCount++
        Remove-Item -LiteralPath $alias
        $alternateSkills=Join-Path $testRoot 'unrelated skills sentinel'
        $null=New-Item -ItemType Directory -Path $alternateSkills
        [IO.File]::WriteAllText((Join-Path $alternateSkills 'sentinel'),'unchanged')
        $null=New-Item -ItemType SymbolicLink -Path $alias -Target $alternateSkills
        Assert-Setup (-not (Test-SetupDiscovery $aliasContext $aliasSkills $names).passed) 'Discovery accepted an alias retargeted outside the selected Skills.'
        Assert-Setup ((Get-Content -LiteralPath (Join-Path $alternateSkills 'sentinel') -Raw) -ceq 'unchanged') 'Discovery modified the alternate-root sentinel.'
        $caseCount++
      } finally {
        Remove-TestLink $alias
        $aliasCleanup=Remove-SetupContext $aliasContext
        Assert-Setup ($aliasCleanup.processesStopped -and $aliasCleanup.scratchRemoved) 'Alias-tampering fixture cleanup failed.'
      }

      # Actual entrypoint JSON must be machine-readable on failure, contain no raw
      # diagnostics, and leave its supplied missing homes untouched.
      $publicResult=Invoke-TestPowerShell -Arguments @('-File',$setupScript,'-CodexPath',(Join-Path $testRoot 'missing'),'-Action','Doctor','-CodexHome',(Join-Path $testRoot 'public codex'),'-AgentsHome',(Join-Path $testRoot 'public agents'),'-Json')
      $public=$publicResult.Output | ConvertFrom-Json
      Assert-Setup ($publicResult.ExitCode -eq 1 -and -not $public.success -and 'codex_missing' -in $public.errors) 'Public JSON failure has incorrect status or exit code.'
      Assert-Setup ([string]::IsNullOrWhiteSpace($publicResult.Errors)) 'Public JSON failure leaked raw stderr.'
      $caseCount++
      }
    } finally { $env:SETUP_PRIVATE_SENTINEL=$priorPrivate; $env:PATH=$priorPath }
  }

  Assert-Setup ((Get-SetupTestFingerprint $personalHome) -eq $personalBefore) 'Setup tests changed the personal-state sentinel.'
  Write-Host "Setup tests passed ($caseCount scenarios)."
} finally {
  $resolved = [IO.Path]::GetFullPath($testRoot)
  $parent = [IO.Path]::GetFullPath((Split-Path -Parent $resolved)).TrimEnd([char]'/',[char]'\')
  if ($parent -ne $temporaryParent.TrimEnd([char]'/',[char]'\') -or -not ([IO.Path]::GetFileName($resolved).StartsWith('codex-setup-test-'))) {
    throw 'Refusing unexpected setup-test cleanup path.'
  }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert-Setup (-not (Test-Path -LiteralPath $resolved)) 'Setup fixture cleanup failed.'
}
