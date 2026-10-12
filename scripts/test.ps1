# Run repository checks in separate PowerShell processes, without downloads or real-home writes.
# Each fixture suite owns and verifies cleanup; a cleanup failure is a failing process exit.
#requires -Version 7.0
[CmdletBinding()]
param([string[]]$Suite = @(), [string]$ResultPath)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path -Parent $PSScriptRoot
$shell = (Get-Process -Id $PID -ErrorAction Stop).Path
$runtime = [ordered]@{
  os=[Runtime.InteropServices.RuntimeInformation]::OSDescription
  osArchitecture=[string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture
  processArchitecture=[string][Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
  powerShell=[string]$PSVersionTable.PSVersion
  framework=[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
}
if ($ResultPath) {
  $ResultPath = [IO.Path]::GetFullPath($ResultPath)
  if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultPath) -PathType Container)) { throw 'TEST_SETUP: ResultPath parent directory must already exist.' }
}
$checks = @(
  @{name='validate';path='scripts/validate.ps1';arguments=@()},
  @{name='validate-docs';path='scripts/validate-docs.ps1';arguments=@('-ProjectRoot',$root)},
  @{name='agent-concurrency';path='tests/test-agent-concurrency.ps1';arguments=@()},
  @{name='ai-capability-contracts';path='tests/test-ai-capability-contracts.ps1';arguments=@()},
  @{name='ai-development-guidance';path='tests/test-ai-development-guidance.ps1';arguments=@()},
  @{name='ai-evaluation';path='tests/test-ai-evaluation.ps1';arguments=@()},
  @{name='ai-simulation';path='tests/test-ai-simulation.ps1';arguments=@()},
  @{name='architecture-migration';path='tests/test-architecture-migration.ps1';arguments=@()},
  @{name='bilingual-docs';path='tests/test-bilingual-docs.ps1';arguments=@()},
  @{name='code-readability';path='tests/test-code-readability.ps1';arguments=@()},
  @{name='deployment';path='tests/test-deployment.ps1';arguments=@()},
  @{name='design-exploration';path='tests/test-design-exploration.ps1';arguments=@()},
  @{name='documentation';path='tests/test-documentation.ps1';arguments=@()},
  @{name='feedback-runtime';path='tests/test-feedback-runtime.ps1';arguments=@()},
  @{name='formatter-tool';path='tests/test-formatter-tool.ps1';arguments=@()},
  @{name='generated-artifacts';path='tests/test-generated-artifacts.ps1';arguments=@()},
  @{name='git-delivery';path='tests/test-git-delivery.ps1';arguments=@()},
  @{name='install-user';path='tests/test-install-user.ps1';arguments=@()},
  @{name='openspec';path='tests/test-openspec.ps1';arguments=@()},
  @{name='project-blueprint';path='tests/test-project-blueprint.ps1';arguments=@()},
  @{name='project-rules';path='tests/test-project-rules.ps1';arguments=@()},
  @{name='stage-verification';path='tests/test-stage-verification.ps1';arguments=@()},
  @{name='team-entry';path='tests/test-team-entry.ps1';arguments=@()},
  @{name='test-support';path='tests/test-test-support.ps1';arguments=@()},
  @{name='validate-package';path='tests/test-validate.ps1';arguments=@()},
  @{name='web-engineering';path='tests/test-web-engineering.ps1';arguments=@()},
  @{name='portability';path='tests/test-portability.ps1';arguments=@()}
)
if ($Suite.Count -gt 0) {
  # A comma-delimited single argument also works through pwsh -File from Bash or Zsh.
  $Suite = @($Suite | ForEach-Object { $_ -split ',' })
  foreach ($name in $Suite) {
    if ($name -cnotin $checks.name) { throw "TEST_SETUP: Unknown suite '$name'. Choices: $($checks.name -join ', ')." }
  }
  $checks = @($checks | Where-Object { $_.name -cin $Suite })
}
if (-not $shell -or -not (Test-Path -LiteralPath $shell -PathType Leaf)) { throw 'TEST_SETUP: Cannot locate the running PowerShell executable.' }
Write-Host ("Platform: {0}; OS architecture: {1}; process architecture: {2}" -f [Runtime.InteropServices.RuntimeInformation]::OSDescription,[Runtime.InteropServices.RuntimeInformation]::OSArchitecture,[Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)
Write-Host ("Runtime: PowerShell {0}; {1}" -f $PSVersionTable.PSVersion,[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)
foreach ($prerequisite in @(
  @{name='git';suites=@('deployment','ai-development-guidance','ai-simulation','generated-artifacts','git-delivery','formatter-tool','documentation','openspec','portability');argument='--version'},
  @{name='node';suites=@('openspec','formatter-tool');argument='--version'}
)) {
  $dependentChecks=@($checks.name | Where-Object { $_ -in $prerequisite.suites })
  if ($dependentChecks.Count -eq 0) { continue }
  $command = Get-Command $prerequisite.name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $command) { throw "TEST_SETUP: $($prerequisite.name) is required for $($dependentChecks -join ', '); provision it separately. This runner never installs dependencies." }
  $version = & $command.Source $prerequisite.argument
  if ($LASTEXITCODE -ne 0) { throw "TEST_SETUP: $($prerequisite.name) version probe failed with exit $LASTEXITCODE." }
  Write-Host ("Dependency: {0}" -f ($version -join ' '))
}
$results = @()
foreach ($check in $checks) {
  $path = Join-Path $root $check.path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "TEST_SETUP: Missing check $($check.path)." }
  Write-Host ("RUN {0}" -f $check.path)
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $shell
  $info.WorkingDirectory = $root
  $info.UseShellExecute = $false
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive','-File',$path) + $check.arguments) { $info.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  $timer = [Diagnostics.Stopwatch]::StartNew()
  try {
    $null = $process.Start()
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    if ($output) { Write-Host $output.TrimEnd() }
    if ($errors) { Write-Host $errors.TrimEnd() }
    $timer.Stop()
    $results += [pscustomobject]@{Suite=$check.name;ExitCode=$process.ExitCode;Seconds=[math]::Round($timer.Elapsed.TotalSeconds,2)}
    Write-Host ("RESULT {0}: exit {1}; {2}s" -f $check.name,$process.ExitCode,[math]::Round($timer.Elapsed.TotalSeconds,2))
  } finally { $process.Dispose() }
}
$results | Format-Table -AutoSize | Out-Host
$failed = @($results | Where-Object ExitCode -ne 0)
if ($ResultPath) {
  # Only an explicit result destination writes an artifact; include no environment dump or home paths.
  $summary = [ordered]@{schemaVersion=1;finishedAt=[DateTime]::UtcNow.ToString('o');runtime=$runtime;checks=$results;passed=($failed.Count -eq 0)}
  [IO.File]::WriteAllText($ResultPath,($summary | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
}
if ($failed.Count -gt 0) { Write-Host ("Failed checks: {0}" -f ($failed.Suite -join ', ')); exit 1 }
Write-Host "All $($results.Count) selected checks passed, including each fixture suite's cleanup assertions. Live client behavior and untested platforms remain unverified."
exit 0
