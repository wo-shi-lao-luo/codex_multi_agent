# Digest equivalence checks do not execute the deployment manager or write homes.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot '../scripts/deploy-user.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($manager,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Manager parse failed.' }
$digest = $ast.Find({ param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Get-SourceContractDigest'
},$true)
if (-not $digest) { throw 'Missing source contract digest.' }
. ([scriptblock]::Create($digest.Extent.Text))
$package = @{
  kitVersion='1.0.0'; runtimeDataSchema=1; packageDigest=('a' * 64)
  directories=@('skills/team-core'); boardRequired=$true
  files=@(@{key='skills/team-core/runtime/node-runtime.json'; sha256=('b' * 64)})
  runtimeSelection=[ordered]@{schemaVersion=1; runtime=[ordered]@{version='26'; platform='win32'}}
}
$before = Get-SourceContractDigest $package
# Selected JSON property ordering must not change the cross-process source pin.
# Expected: reordered nested dictionaries and alternate dictionary types produce equal digests.
$package.runtimeSelection = [ordered]@{
  runtime=[ordered]@{platform='win32'; version='26'}; schemaVersion=1
}
if ((Get-SourceContractDigest $package) -cne $before) { throw 'Property ordering changed the pin.' }
$package.runtimeSelection = @{schemaVersion=1; runtime=@{platform='win32'; version='26'}}
if ((Get-SourceContractDigest $package) -cne $before) { throw 'Dictionary type changed the pin.' }
# Runtime provenance comes from exact authoritative file bytes, not Hashtable serialization.
# Expected: changing only the lock inventory hash changes the pin even with the old packageDigest.
$package.files[0].sha256 = 'c' * 64
if ((Get-SourceContractDigest $package) -ceq $before) { throw 'Authoritative runtime lock hash was ignored.' }
$package.files = @()
if ((Get-SourceContractDigest $package) -ceq $before) { throw 'Runtime lock removal was ignored.' }
Write-Host 'Source contract digest passed: dictionary order equivalence and authoritative lock provenance.'
