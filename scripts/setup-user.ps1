# Coordinate isolated Codex prerequisite/discovery checks and explicitly requested
# installation into selected homes. Report results without exposing client output;
# this entrypoint never installs optional enhancements or changes host policy.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [ValidateSet('Doctor','Install','Verify')][string]$Action = 'Doctor',
  [string]$CodexPath,
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [ValidateRange(1,300)][int]$TimeoutSeconds = 120,
  [switch]$Json,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$script:SetupRoot = Split-Path -Parent $PSScriptRoot

function Resolve-SetupPath([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  if ($IsMacOS) {
    foreach ($pair in @(@('/tmp','/private/tmp'),@('/var','/private/var'))) {
      if ($full -ceq $pair[0] -or $full.StartsWith($pair[0]+'/',[StringComparison]::Ordinal)) {
        $item = Get-Item -LiteralPath $pair[0] -Force
        $targets=@($item.Target)
        if ($item.LinkType -cne 'SymbolicLink' -or $targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace($targets[0])) { throw 'unsafe_path' }
        $target=[string]$targets[0]
        if (-not [IO.Path]::IsPathRooted($target)) { $target=Join-Path ([IO.Path]::GetDirectoryName($pair[0])) $target }
        if ([IO.Path]::GetFullPath($target) -cne $pair[1] -or -not [IO.Directory]::Exists($pair[1])) { throw 'unsafe_path' }
        return $pair[1] + $full.Substring($pair[0].Length)
      }
    }
  }
  return $full
}

function Assert-SetupPlainPath([string]$Path) {
  $cursor = Resolve-SetupPath $Path
  while ($cursor) {
    try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'unsafe_path' }
    $cursor = Split-Path -Parent $cursor
  }
}

function Get-SetupPrivateRoots {
  return @((Join-Path $HOME '.codex'),(Join-Path $HOME '.config'),$script:SetupCodexHome) |
    Select-Object -Unique | ForEach-Object { (Resolve-SetupPath $_).TrimEnd('\','/') }
}

function Assert-SetupSkillsLayout([string]$SkillsRoot) {
  $selected=(Resolve-SetupPath $SkillsRoot).TrimEnd('\','/')
  # macOS's common case-insensitive volumes can resolve a differently spelled
  # private path to the masked directory. Linux retains exact path comparison.
  $comparison=if ($IsMacOS) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  $separator=[IO.Path]::DirectorySeparatorChar
  foreach ($privateRoot in Get-SetupPrivateRoots) {
    if ([string]::Equals($selected,$privateRoot,$comparison) -or $selected.StartsWith($privateRoot+$separator,$comparison) -or $privateRoot.StartsWith($selected+$separator,$comparison)) { throw 'unsupported_agents_layout' }
  }
}

function Get-SetupSandbox($Scratch, $CodexPath, $SkillsRoot) {
  # Client state is isolated independently of the sandbox. The sandbox also denies
  # network access and grants writes only beneath this run's owned scratch root.
  if ($IsMacOS) {
    if (-not [IO.File]::Exists('/usr/bin/sandbox-exec')) { throw 'sandbox_unavailable' }
    function Quote-Seatbelt([string]$Value) { return '"'+$Value.Replace('\','\\').Replace('"','\"')+'"' }
    $profile = '(version 1)(allow default)(deny network*)(deny file-write*)(allow file-write* (subpath '+(Quote-Seatbelt $Scratch)+'))'
    foreach ($secretRoot in Get-SetupPrivateRoots) {
      # A user may keep the executable within .codex; permit that exact file only.
      $profile += '(deny file-read* (require-all (subpath '+(Quote-Seatbelt $secretRoot)+') (require-not (literal '+(Quote-Seatbelt $CodexPath)+'))))'
    }
    $profilePath = Join-Path $Scratch 'sandbox.sb'
    [IO.File]::WriteAllText($profilePath,$profile)
    return @{ Launcher='/usr/bin/sandbox-exec'; Prefix=@('-f',$profilePath) }
  }
  if ($IsLinux) {
    $launcher = @('/usr/bin/bwrap','/bin/bwrap') | Where-Object { [IO.File]::Exists($_) } | Select-Object -First 1
    if (-not $launcher) { throw 'sandbox_unavailable' }
    $arguments = @('--unshare-user','--unshare-pid','--unshare-net','--die-with-parent','--new-session','--ro-bind','/','/','--bind',$Scratch,$Scratch,'--dev','/dev','--proc','/proc')
    foreach ($secretRoot in Get-SetupPrivateRoots) {
      if ([IO.Directory]::Exists($secretRoot)) {
        if ($CodexPath.StartsWith($secretRoot+'/',[StringComparison]::Ordinal)) { throw 'client_inside_private_config' }
        $arguments += @('--ro-bind',(Join-Path $Scratch 'empty'),$secretRoot)
      }
    }
    return @{ Launcher=$launcher; Prefix=($arguments + @('--')) }
  }
  throw 'unsupported_platform'
}

function New-SetupContext([string]$Client, [string]$SkillsRoot, [int]$Timeout = 120) {
  $scratch = Resolve-SetupPath (Join-Path ([IO.Path]::GetTempPath()) ('codex-kit-setup-'+[guid]::NewGuid().ToString('N')))
  Assert-SetupPlainPath $scratch
  $null = [IO.Directory]::CreateDirectory($scratch)
  $context = @{ Scratch=$scratch; Client=$Client; SkillsRoot=$SkillsRoot; Timeout=$Timeout; Processes=[Collections.Generic.List[object]]::new(); NextId=0; Probe=(Join-Path $scratch 'probe') }
  try {
    foreach ($name in @('home','codex','config','cache','data','state','tmp','empty','probe/.agents')) { $null = [IO.Directory]::CreateDirectory((Join-Path $scratch $name)) }
    if ([IO.Directory]::Exists($SkillsRoot)) {
      Assert-SetupPlainPath $SkillsRoot
      $null = New-Item -ItemType SymbolicLink -Path (Join-Path $context.Probe '.agents/skills') -Target $SkillsRoot -WhatIf:$false -Confirm:$false
    }
    $context.Sandbox = Get-SetupSandbox $scratch $Client $SkillsRoot
    return $context
  } catch {
    [IO.Directory]::Delete($scratch,$true)
    throw
  }
}

function Start-SetupClient($Context, [string[]]$Arguments) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $Context.Sandbox.Launcher
  foreach ($value in @($Context.Sandbox.Prefix) + @($Context.Client) + $Arguments) { $info.ArgumentList.Add([string]$value) }
  $info.UseShellExecute=$false; $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $info.WorkingDirectory=$Context.Probe
  # Allowlist instead of scrubbing a growing list of credential variables.
  $info.Environment.Clear()
  $searchPath=[Environment]::GetEnvironmentVariable('PATH')
  $info.Environment['PATH'] = if ([string]::IsNullOrWhiteSpace($searchPath)) { '/usr/bin:/bin:/usr/sbin:/sbin' } else { $searchPath }
  $info.Environment['LANG'] = 'C.UTF-8'
  $info.Environment['POWERSHELL_TELEMETRY_OPTOUT'] = '1'
  $info.Environment['POWERSHELL_UPDATECHECK'] = 'Off'
  foreach ($pair in @(@('HOME','home'),@('CODEX_HOME','codex'),@('XDG_CONFIG_HOME','config'),@('XDG_CACHE_HOME','cache'),@('XDG_DATA_HOME','data'),@('XDG_STATE_HOME','state'),@('TMPDIR','tmp'),@('TMP','tmp'),@('TEMP','tmp'))) {
    $info.Environment[$pair[0]] = Join-Path $Context.Scratch $pair[1]
  }
  $process = [Diagnostics.Process]::new(); $process.StartInfo=$info
  try {
    if (-not $process.Start()) { throw 'client_start_failed' }
    # Drain without retaining logs: client stderr may contain private diagnostics.
    $discard = $process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    $Context.Processes.Add(@{Process=$process; Stderr=$discard})
    return $process
  } catch { $process.Dispose(); throw 'client_start_failed' }
}

# Kill(true) includes attached descendants; an already orphaned process cannot be
# inferred from a parent PID. Cleanup reports explicitly scope tracked clients.
function Stop-SetupProcess($Process) {
  if (-not $Process.HasExited) { $Process.Kill($true) }
  if (-not $Process.WaitForExit(5000)) { throw 'process_cleanup_failed' }
}

function Remove-SetupContext($Context) {
  $stopped=$true; $removed=$false
  foreach ($entry in $Context.Processes) {
    try { Stop-SetupProcess $entry.Process } catch { $stopped=$false }
    finally { $entry.Process.Dispose() }
  }
  try {
    # Only remove the direct, uniquely named directory created by this invocation.
    Assert-SetupPlainPath $Context.Scratch
    if ([IO.Path]::GetFileName($Context.Scratch) -cnotmatch '^codex-kit-setup-[a-f0-9]{32}$') { throw 'unsafe_cleanup' }
    [IO.Directory]::Delete($Context.Scratch,$true)
    $removed = -not [IO.Directory]::Exists($Context.Scratch)
  } catch { $removed=$false }
  return @{processesStopped=$stopped; scratchRemoved=$removed; processScope='tracked-client-processes'}
}

function Read-SetupLine($Process, [datetime]$Deadline) {
  $remaining = [int][Math]::Max(0,($Deadline-[datetime]::UtcNow).TotalMilliseconds)
  if ($remaining -le 0) { throw 'client_timeout' }
  $read = $Process.StandardOutput.ReadLineAsync()
  if (-not $read.Wait($remaining)) { throw 'client_timeout' }
  $line=$read.GetAwaiter().GetResult()
  if ($null -eq $line) { throw 'client_protocol_closed' }
  if ($line.Length -gt 4194304) { throw 'client_protocol_invalid' }
  return $line
}

function Invoke-SetupRequest($Context, $Process, [string]$Method, $Parameters) {
  $Context.NextId++
  $id=$Context.NextId
  $Process.StandardInput.WriteLine((@{id=$id;method=$Method;params=$Parameters} | ConvertTo-Json -Depth 20 -Compress))
  $Process.StandardInput.Flush()
  $deadline=[datetime]::UtcNow.AddSeconds($Context.Timeout)
  for ($i=0; $i -lt 200; $i++) {
    $line = Read-SetupLine $Process $deadline
    try { $message=$line | ConvertFrom-Json -AsHashtable } catch { throw 'client_protocol_invalid' }
    if ($message -isnot [Collections.IDictionary]) { throw 'client_protocol_invalid' }
    if ($message.Contains('id') -and $message.id -eq $id) {
      if ($message.Contains('error')) { throw 'client_protocol_error' }
      if (-not $message.Contains('result')) { throw 'client_protocol_invalid' }
      return $message.result
    }
  }
  throw 'client_protocol_invalid'
}

function Invoke-SetupProbe($Context, [switch]$ProtocolOnly) {
  $versionProcess = Start-SetupClient $Context @('--version')
  try {
    $line = Read-SetupLine $versionProcess ([datetime]::UtcNow.AddSeconds($Context.Timeout))
    if (-not $versionProcess.WaitForExit($Context.Timeout*1000)) { throw 'client_timeout' }
    if ($versionProcess.ExitCode -ne 0 -or $line -cnotmatch '^codex-cli (\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?)$') { throw 'client_version_invalid' }
    $version=$Matches[1]
    $Context.VerifiedVersion=$version
  } finally { Stop-SetupProcess $versionProcess }
  $process = Start-SetupClient $Context @('app-server','-c','analytics.enabled=false','-c','feedback.enabled=false')
  try {
    $initialized = Invoke-SetupRequest $Context $process 'initialize' @{clientInfo=@{name='kit_setup';version='0.10.3'};capabilities=@{experimentalApi=$true}}
    if ($initialized -isnot [Collections.IDictionary]) { throw 'client_protocol_invalid' }
    $process.StandardInput.WriteLine('{"method":"initialized"}')
    $process.StandardInput.Flush()
    $result = Invoke-SetupRequest $Context $process 'skills/list' @{cwds=@($Context.Probe);forceReload=$true}
    if ($result -isnot [Collections.IDictionary] -or -not $result.Contains('data') -or $result.data -isnot [Array]) { throw 'client_protocol_invalid' }
    $entries=@($result.data)
    if ($entries.Count -ne 1 -or $entries[0].cwd -cne $Context.Probe -or -not $entries[0].Contains('skills') -or -not $entries[0].Contains('errors')) { throw 'client_protocol_invalid' }
    if ($entries[0].skills -isnot [Array] -or $entries[0].errors -isnot [Array]) { throw 'client_protocol_invalid' }
    # Installation readiness is a protocol check, not approval of existing files
    # that Force may legitimately repair. Doctor/Verify and post-install probes
    # still reject every discovery error before claiming an installed-state pass.
    if (-not $ProtocolOnly -and @($entries[0].errors).Count -ne 0) { throw 'skill_discovery_errors' }
    return @{version=$version; skills=@($entries[0].skills)}
  } finally { Stop-SetupProcess $process }
}

function Test-SetupSkillAlias($Context) {
  try {
    $aliasRoot=Join-Path $Context.Probe '.agents/skills'
    Assert-SetupPlainPath (Split-Path -Parent $aliasRoot)
    $item=Get-Item -LiteralPath $aliasRoot -Force
    $targets=@($item.Target)
    if ($item.LinkType -cne 'SymbolicLink' -or $targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace($targets[0])) { return $false }
    $target=[string]$targets[0]
    if (-not [IO.Path]::IsPathRooted($target)) { $target=Join-Path (Split-Path -Parent $aliasRoot) $target }
    return (Resolve-SetupPath $target) -ceq $Context.SkillsRoot
  } catch { return $false }
}

function Test-SetupDiscovery($Context, $Skills, [string[]]$Names) {
  $matched=0
  foreach ($name in $Names) {
    $candidates=@($Skills | Where-Object { $_.name -ceq $name })
    if ($candidates.Count -ne 1 -or $candidates[0].enabled -isnot [bool] -or -not $candidates[0].enabled) { continue }
    $expected=Join-Path $Context.SkillsRoot "$name/SKILL.md"
    $alias=Join-Path $Context.Probe ".agents/skills/$name/SKILL.md"
    $actual=[string]$candidates[0].path
    # The sole owned discovery symlink has a known target. Never accept arbitrary
    # matching suffixes, alternate roots, or links within the installed payload.
    if ($actual -cne $expected -and $actual -cne $alias) { continue }
    if ($actual -ceq $alias -and -not (Test-SetupSkillAlias $Context)) { continue }
    try { Assert-SetupPlainPath $expected } catch { continue }
    if ([IO.File]::Exists($expected)) { $matched++ }
  }
  return @{checked=$true;passed=($matched -eq $Names.Count);expectedCount=$Names.Count;matchedCount=$matched;mode='isolated-project-root'}
}

function Invoke-SetupManager([string]$ScriptPath, [string[]]$Arguments, [int]$Timeout) {
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=(Get-Process -Id $PID).Path
  foreach ($value in @('-NoLogo','-NoProfile','-NonInteractive','-File',$ScriptPath)+$Arguments) { $info.ArgumentList.Add($value) }
  $info.UseShellExecute=$false; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $info.Environment['POWERSHELL_TELEMETRY_OPTOUT'] = '1'
  $info.Environment['POWERSHELL_UPDATECHECK'] = 'Off'
  $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
  try {
    if (-not $process.Start()) { throw 'installer_start_failed' }
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    if (-not $process.WaitForExit($Timeout*1000)) { throw 'installer_timeout' }
    if ($process.ExitCode -ne 0) { throw 'installer_failed' }
    # A child retaining the pipe must not turn a finished manager into an
    # unbounded wait. Its output is still never exposed as raw diagnostics.
    if (-not $stdout.Wait($Timeout*1000)) { throw 'installer_timeout' }
    return $stdout.GetAwaiter().GetResult()
  } finally {
    try { if ($process.Id) { Stop-SetupProcess $process } } finally { $process.Dispose() }
  }
}

function Get-SetupPreview([string]$Output, [string]$CodexHome, [string]$AgentsHome) {
  $starts=[regex]::Matches($Output,'(?m)^\{')
  for ($index=$starts.Count-1; $index -ge 0; $index--) {
    try { $parsed=$Output.Substring($starts[$index].Index) | ConvertFrom-Json -AsHashtable } catch { continue }
    if ($parsed.action -cne 'preview' -or -not $parsed.Contains('operations')) { continue }
    $counts=@{install=0;replace=0;remove=0}
    foreach ($operation in @($parsed.operations)) {
      if ($operation.operation -notin @('install','replace','remove') -or $operation.unit -cnotmatch '^(agents/[a-z0-9][a-z0-9-]*\.toml|skills/[a-z0-9][a-z0-9-]*)$') { throw 'installer_preview_invalid' }
      $counts[$operation.operation]++
    }
    return @{codexHome=$CodexHome;agentsHome=$AgentsHome;unitCount=@($parsed.operations).Count;operations=$counts}
  }
  throw 'installer_preview_invalid'
}

# Doctor/Verify inspect the selected installation without deploying payloads;
# their client probes still create owned temporary resources that must be cleaned.
# Install explicitly delegates deployment into CodexHome/AgentsHome unless Preview.
# Return a structured report: expected failures become success=false with sanitized
# errors; completed cleanup is required before success-only installation advice.
function Invoke-SetupMain {
  [CmdletBinding()]
  param([string]$Action='Doctor',[string]$CodexPath,[string]$CodexHome,[string]$AgentsHome,[int]$TimeoutSeconds=120,[bool]$Preview=$false,[bool]$Force=$false)
  $report=[ordered]@{schemaVersion=1;action=$Action;success=$false;status='not_ready';platform=@{os='unsupported';architecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()};prerequisites=@{powershell=($PSVersionTable.PSVersion.Major -ge 7);codex=$false;sandbox=$false;protocol=$false};installation=@{attempted=$false;verified=$false;preview=$Preview};discovery=@{checked=$false;passed=$false;expectedCount=0;matchedCount=0;mode='isolated-project-root'};cleanup=@{processesStopped=$true;scratchRemoved=$true;processScope='tracked-client-processes'};errors=@();guidance=@()}
  $context=$null
  try {
    $report.platform.os=if ($IsMacOS) {'macos'} elseif ($IsLinux) {'linux'} else {'unsupported'}
    if ($report.platform.os -eq 'unsupported' -or $report.platform.architecture -notin @('arm64','x64') -or [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant() -cne $report.platform.architecture) { throw 'unsupported_platform' }
    $CodexHome=Resolve-SetupPath $CodexHome; $AgentsHome=Resolve-SetupPath $AgentsHome
    $script:SetupCodexHome=$CodexHome
    foreach ($path in @($CodexHome,$AgentsHome)) { Assert-SetupPlainPath $path }
    # The offline client cannot discover a tree hidden by its private-state mask.
    # Reject every action before a probe or installer could create partial state.
    Assert-SetupSkillsLayout (Join-Path $AgentsHome 'skills')
    # Every source Skill is required. Missing entries must fail rather than being
    # silently excluded, and a valid later bundle must not need a count edit.
    $names=@(Get-ChildItem -LiteralPath (Join-Path $script:SetupRoot 'skills') -Directory -Force | ForEach-Object {
      if ($_.Name -cnotmatch '^[a-z0-9][a-z0-9-]*$' -or -not [IO.File]::Exists((Join-Path $_.FullName 'SKILL.md'))) { throw 'source_skills_invalid' }
      $_.Name
    } | Sort-Object)
    if ($names.Count -eq 0) { throw 'source_skills_invalid' }
    $report.discovery.expectedCount=$names.Count
    if (-not $CodexPath) {
      $command=Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $command) { throw 'codex_missing' }
      $CodexPath=$command.Source
    }
    $CodexPath=Resolve-SetupPath $CodexPath
    if (-not [IO.File]::Exists($CodexPath)) { throw 'codex_missing' }
    # Keep the prerequisite probe independent of a damaged/missing installation.
    # A new context exposes the selected installed Skills only after deployment.
    $initialSkillsRoot=if ($Action -eq 'Install') { '' } else { Join-Path $AgentsHome 'skills' }
    $context=New-SetupContext $CodexPath $initialSkillsRoot $TimeoutSeconds
    $probe=Invoke-SetupProbe $context -ProtocolOnly:($Action -eq 'Install')
    $report.prerequisites.codex=$true; $report.prerequisites.sandbox=$true; $report.prerequisites.protocol=$true
    $report.prerequisites.version=$probe.version
    if ($Action -eq 'Doctor') {
      if ([IO.Directory]::Exists($context.SkillsRoot)) { $report.discovery=Test-SetupDiscovery $context $probe.skills $names }
      if (-not $report.discovery.passed) { $report.guidance+='Dependencies are ready. Use -Action Install for a missing kit, or -Action Verify to check an existing installation.' }
      $report.status='ready'; $report.success=$true
    } else {
      if ($Action -eq 'Install') {
        $arguments=@('-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome)
        if ($Force) { $arguments+='-Force' }
        if ($Preview) { $arguments+='-WhatIf' } else { $report.installation.attempted=$true }
        $installOutput=Invoke-SetupManager (Join-Path $script:SetupRoot 'scripts/install-user.ps1') $arguments $TimeoutSeconds
        if ($Preview) { $report.installation.plan=Get-SetupPreview $installOutput $CodexHome $AgentsHome }
      }
      if ($Preview) { $report.status='what_if'; $report.success=$true }
      else {
        $raw=Invoke-SetupManager (Join-Path $script:SetupRoot 'scripts/deploy-user.ps1') @('-Action','Verify','-CodexHome',$CodexHome,'-AgentsHome',$AgentsHome) $TimeoutSeconds
        try { $verified=$raw | ConvertFrom-Json -AsHashtable } catch { throw 'receipt_verification_failed' }
        if ($verified.valid -ne $true) { throw 'receipt_verification_failed' }
        $report.installation.verified=$true
        # A fresh context ensures cached Skills and pre-install absence cannot hide
        # the installed files from the post-install verification.
        $cleanup=Remove-SetupContext $context; $context=$null
        if (-not $cleanup.processesStopped -or -not $cleanup.scratchRemoved) { $report.cleanup=$cleanup; throw 'cleanup_failed' }
        $context=New-SetupContext $CodexPath (Join-Path $AgentsHome 'skills') $TimeoutSeconds
        $probe=Invoke-SetupProbe $context
        $report.discovery=Test-SetupDiscovery $context $probe.skills $names
        if (-not $report.discovery.passed) { throw 'skill_discovery_mismatch' }
        $report.success=$true; $report.status=if ($Action -eq 'Install') {'installed_verified'} else {'verified'}
      }
    }
  } catch {
    # Only local allowlisted categories leave the process; never emit raw client,
    # installer, OS diagnostics, authentication data, or config contents.
    $known=@('unsafe_path','sandbox_unavailable','client_inside_private_config','unsupported_platform','unsupported_agents_layout','client_start_failed','process_cleanup_failed','client_timeout','client_protocol_closed','client_protocol_invalid','client_protocol_error','client_version_invalid','skill_discovery_errors','installer_start_failed','installer_timeout','installer_failed','installer_preview_invalid','codex_missing','source_skills_invalid','receipt_verification_failed','cleanup_failed','skill_discovery_mismatch')
    if ($context -and $context.VerifiedVersion) {
      $report.prerequisites.codex=$true; $report.prerequisites.sandbox=$true; $report.prerequisites.version=$context.VerifiedVersion
    }
    $category=[string]$_.Exception.Message
    if ($category -notin $known) { $category='setup_failed' }
    if ($category -eq 'process_cleanup_failed') { $report.cleanup.processesStopped=$false }
    $report.errors+= $category
    $report.status='failed'; $report.success=$false
    if ($category -eq 'unsupported_agents_layout') { $report.guidance+='Select the default .agents home or another AgentsHome whose Skills directory does not overlap private .codex/.config or the selected CodexHome. Setup cannot discover Skills hidden by its privacy sandbox.' }
    elseif ($category -eq 'codex_missing') { $report.guidance+='Install the official native Codex CLI using an explicitly approved network route, then set -CodexPath. https://learn.chatgpt.com/docs/codex/cli' }
    elseif ($category -eq 'unsupported_platform') { $report.guidance+='Use native PowerShell 7 on macOS or Linux, with x64 or ARM64 architecture.' }
    elseif (-not $report.prerequisites.sandbox) { $report.guidance+='Client checks require a working OS no-network sandbox: sandbox-exec on macOS; Bubblewrap with permitted user/network namespaces on Linux. Ask your administrator if host policy blocks these. Setup never changes host policy or uses sudo.' }
    else { $report.guidance+='Check the selected installation and client compatibility. Existing installation conflicts require review; -Force is never enabled automatically.' }
  } finally {
    if ($context) {
      $prior=$report.cleanup
      $report.cleanup=Remove-SetupContext $context
      $report.cleanup.processesStopped=$report.cleanup.processesStopped -and $prior.processesStopped
      $report.cleanup.scratchRemoved=$report.cleanup.scratchRemoved -and $prior.scratchRemoved
    }
    if (-not $report.cleanup.processesStopped -or -not $report.cleanup.scratchRemoved) { $report.success=$false; $report.status='failed'; if ('cleanup_failed' -notin $report.errors) { $report.errors+='cleanup_failed' } }
  }
  # Installer output stays private. Add shared optional advice only after an
  # actual installation and all verification/cleanup have succeeded.
  if ($report.success -and $Action -eq 'Install' -and -not $Preview) {
    try {
      . (Join-Path $script:SetupRoot 'scripts/optional-capabilities.ps1')
      $report.guidance += Get-OptionalCapabilityGuidance
    } catch {
      # Optional advice must not invalidate an otherwise verified installation.
    }
  }
  return $report
}

$preview=($Action -eq 'Install' -and [bool]$WhatIfPreference)
if ($Action -eq 'Install' -and -not $preview) {
  # Preserve standard confirmation semantics while keeping -Json stdout clean.
  if (-not $PSCmdlet.ShouldProcess('the selected Codex and Agents homes','Install and verify the kit')) { $preview=$true }
}
$result=Invoke-SetupMain -Action $Action -CodexPath $CodexPath -CodexHome $CodexHome -AgentsHome $AgentsHome -TimeoutSeconds $TimeoutSeconds -Preview $preview -Force ([bool]$Force)
if ($Json) { $result | ConvertTo-Json -Depth 10 }
else {
  Write-Output "Setup $Action`: $($result.status)"
  Write-Output "Platform: $($result.platform.os)/$($result.platform.architecture); PowerShell $($PSVersionTable.PSVersion)"
  if ($result.installation.plan) {
    $plan=$result.installation.plan
    Write-Output "Preview: $($plan.unitCount) managed units; install=$($plan.operations.install), replace=$($plan.operations.replace), remove=$($plan.operations.remove)"
    Write-Output "Codex home: $($plan.codexHome)"
    Write-Output "Agents home: $($plan.agentsHome)"
  }
  if ($result.discovery.checked) { Write-Output "Selected installation Skills: $($result.discovery.matchedCount)/$($result.discovery.expectedCount)" }
  foreach ($message in @($result.errors)+@($result.guidance)) { Write-Output $message }
}
if (-not $result.success) { exit 1 }
