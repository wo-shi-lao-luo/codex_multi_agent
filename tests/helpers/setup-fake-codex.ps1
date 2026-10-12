# Local protocol fixture only. It never contacts a provider or reads personal state.
# Copy this file beside scenario.json before executing it through the test launcher.
param()
$ClientArguments = @($args)
$ErrorActionPreference = 'Stop'
$scenario = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scenario.json') -Raw | ConvertFrom-Json
$mode = [string]$scenario.mode
$scratch = if ($env:HOME) { Split-Path -Parent $env:HOME } else { '' }
$ownedScratch = $scratch -and ([IO.Path]::GetFileName($scratch) -cmatch '^codex-kit-setup-[a-f0-9]{32}$')
$observation = [ordered]@{
  pid=$PID
  privateEnvironmentAbsent=[string]::IsNullOrEmpty($env:SETUP_PRIVATE_SENTINEL)
  freshHome=($ownedScratch -and [IO.Path]::GetFileName($env:HOME) -ceq 'home')
  freshCodexHome=($ownedScratch -and $env:CODEX_HOME -ceq (Join-Path $scratch 'codex') -and -not (Test-Path -LiteralPath (Join-Path $env:CODEX_HOME 'auth.json')))
  freshXdgHome=($ownedScratch -and $env:XDG_CONFIG_HOME -ceq (Join-Path $scratch 'config'))
  expectedPathAvailable=(@($env:PATH -split [regex]::Escape([string][IO.Path]::PathSeparator)) -ccontains [string]$scenario.expectedPathEntry)
  powershellStartupPrivate=($env:POWERSHELL_TELEMETRY_OPTOUT -ceq '1' -and $env:POWERSHELL_UPDATECHECK -ceq 'Off')
}
[IO.File]::AppendAllText((Join-Path $PSScriptRoot 'observed.jsonl'), (($observation | ConvertTo-Json -Compress) + "`n"))

function Send-Reply($Id, $Result) {
  [Console]::Out.WriteLine((@{id=$Id;result=$Result} | ConvertTo-Json -Depth 30 -Compress))
  [Console]::Out.Flush()
}

function Send-Failure($Id) {
  [Console]::Out.WriteLine((@{id=$Id;error=@{code=-32000;message='FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE'}} | ConvertTo-Json -Compress))
  [Console]::Out.Flush()
}

if ($mode -eq 'exit') {
  [Console]::Error.WriteLine('FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE')
  exit 19
}
if ($ClientArguments -contains '--version') {
  if ($mode -eq 'bad-version') { [Console]::Out.WriteLine('FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE'); exit 0 }
  if ($mode -eq 'old-version') { [Console]::Out.WriteLine('codex-cli 0.1.0'); exit 0 }
  [Console]::Out.WriteLine('codex-cli 0.162.0-alpha.17.2')
  exit 0
}
if ($ClientArguments -contains 'generate-json-schema') {
  $index = [array]::IndexOf($ClientArguments, '--out')
  if ($index -lt 0 -or $index + 1 -ge $ClientArguments.Count) { exit 20 }
  $destination = $ClientArguments[$index + 1]
  $null = New-Item -ItemType Directory -Path $destination -Force
  $definitions = @{
    SkillsListParams=@{properties=@{cwds=@{};forceReload=@{};perCwdExtraUserRoots=@{}}}
    SkillsListResponse=@{properties=@{data=@{}}}
    SkillsListEntry=@{properties=@{cwd=@{};skills=@{};errors=@{}}}
    SkillMetadata=@{properties=@{name=@{};path=@{};enabled=@{}}}
    InitializeParams=@{properties=@{clientInfo=@{};capabilities=@{}}}
  }
  if ($mode -eq 'missing-capability') { $definitions.SkillsListParams.properties.Remove('perCwdExtraUserRoots') }
  $content = @{definitions=$definitions} | ConvertTo-Json -Depth 15
  if ($mode -eq 'bad-schema') { $content = '{ invalid json' }
  [IO.File]::WriteAllText((Join-Path $destination 'schema.json'), $content)
  exit 0
}
if ($ClientArguments -notcontains 'app-server') { exit 21 }
while ($null -ne ($line = [Console]::In.ReadLine())) {
  $request = $line | ConvertFrom-Json
  if ($null -eq $request.id) { continue }
  if ($mode -eq 'timeout') { Start-Sleep -Seconds 120; continue }
  if ($mode -eq 'bad-json') { [Console]::Out.WriteLine('{ invalid json'); [Console]::Out.Flush(); continue }
  if ($mode -eq 'rpc-error') { Send-Failure $request.id; continue }
  switch ($request.method) {
    'initialize' { Send-Reply $request.id @{userAgent='setup-test-fixture'} }
    'skills/list' {
      $cwd = @($request.params.cwds)[0]
      if (-not $request.params.forceReload -or $mode -eq 'missing-capability') { Send-Failure $request.id; continue }
      $skillsRoot = Join-Path $cwd '.agents/skills'
      $skills = @()
      $errors = @()
      if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
        $skills = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object {
          $entryPath=Join-Path $_.FullName 'SKILL.md'
          if ($mode -eq 'parse-skills' -and (-not (Test-Path -LiteralPath $entryPath -PathType Leaf) -or (Get-Content -LiteralPath $entryPath -Raw) -notmatch '(?s)^---\s*\r?\nname:\s*[a-z0-9-]+\s*\r?\ndescription:\s*.+?\r?\n---')) {
            $errors += @{path=$entryPath;message='FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE'}
          } else {
            @{name=$_.Name;path=$entryPath;enabled=$true}
          }
        })
      }
      if ($mode -eq 'missing-skill') { $skills = @($skills | Select-Object -Skip 1) }
      if ($mode -eq 'disabled-skill') { $skills[0].enabled = $false }
      if ($mode -eq 'wrong-path') { $skills[0].path = Join-Path $PSScriptRoot 'unrelated/SKILL.md' }
      if ($mode -eq 'duplicate-skill') { $skills += $skills[0] }
      if ($mode -eq 'skill-errors') { $errors = @(@{path='fixture';message='FAKE_PRIVATE_DIAGNOSTIC_DO_NOT_EXPOSE'}) }
      if ($mode -eq 'wrong-cwd') { $cwd = $PSScriptRoot }
      if ($mode -eq 'string-enabled' -and $skills.Count) { $skills[0].enabled = 'true' }
      Send-Reply $request.id @{data=@(@{cwd=$cwd;skills=$skills;errors=$errors})}
    }
    'config/read' { Send-Reply $request.id @{config=@{};layers=@()} }
    default { Send-Failure $request.id }
  }
}
