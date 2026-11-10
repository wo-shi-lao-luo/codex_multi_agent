# Exercise the actual installer handoff without Node, downloads, or real homes.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$temporaryParent = Get-TestTemporaryParent
$fixture = Join-Path $temporaryParent ('codex-install-pin-' + [guid]::NewGuid().ToString('N'))
try {
  $scripts = Join-Path $fixture 'trusted/scripts'
  $helpers = Join-Path $fixture 'trusted/skills/team-core/scripts'
  $package = Join-Path $fixture 'package'
  New-Item -ItemType Directory -Force $scripts,$helpers,
    "$package/agents","$package/skills/team-fixture" | Out-Null
  Copy-Item "$repo/scripts/deploy-user.ps1" $scripts
  Copy-Item "$repo/skills/team-core/scripts/board-runtime.ps1" $helpers
  Set-Content "$package/VERSION" '1.0.0'
  Set-Content "$package/agents/team-fixture.toml" 'name = "team-fixture"'
  Set-Content "$package/skills/team-fixture/SKILL.md" '# Fixture'
  $installer = Get-Content "$repo/scripts/install-user.ps1" -Raw
  # Mutate selected directory after the genuine preview, just before the commit handoff.
  # Expected: the wrapper forwards the complete pin and rejects without creating homes.
  foreach ($mutation in @(
      'Set-Content (Join-Path $SourceRoot deployment.json) ''{"runtimeDataSchema":2}''',
      'New-Item -ItemType Directory (Join-Path $SourceRoot skills/team-fixture/empty) | Out-Null')) {
    $hook = '  $deployment = Invoke-TrustedDeployment'
    $modified = $installer.Replace($hook, $mutation + "`n" + $hook)
    if ($modified -ceq $installer) { throw 'Missing installer handoff boundary.' }
    Set-Content "$scripts/install-user.ps1" $modified
    $reply = Invoke-TestPowerShell -Arguments @('-File',"$scripts/install-user.ps1",
      '-SourceRoot',$package,'-CodexHome',"$fixture/codex",'-AgentsHome',"$fixture/agents-home",'-Offline')
    if ($reply.ExitCode -ne 1 -or $reply.Output -notmatch 'PACKAGE_CHANGED:') {
      throw "Installer accepted changed contract or failed for another reason: $($reply.Output) $($reply.Errors)"
    }
    if ((Test-Path "$fixture/codex") -or (Test-Path "$fixture/agents-home")) {
      throw 'Rejected handoff wrote fake homes.'
    }
    if (Test-Path "$package/deployment.json") { Remove-Item "$package/deployment.json" }
    if (Test-Path "$package/skills/team-fixture/empty") { Remove-Item "$package/skills/team-fixture/empty" }
  }
  Write-Host 'Installer source contract tests passed: schema and empty-directory mutation rejected.'
} finally {
  $resolved = [IO.Path]::GetFullPath($fixture)
  if ((Split-Path $resolved -Parent) -ne $temporaryParent -or
      (Split-Path $resolved -Leaf) -notlike 'codex-install-pin-*') { throw 'Unsafe fixture cleanup.' }
  if (Test-Path $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
