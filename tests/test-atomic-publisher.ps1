# Native publication checks use disposable files only; no homes, network or mount changes.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$manager = Join-Path $PSScriptRoot '../scripts/deploy-user.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($manager,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Manager parse failed.' }
$publisher = $ast.Find({ param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Publish-PayloadFile'
},$true)
if (-not $publisher) { throw 'Missing native atomic publisher.' }
. ([scriptblock]::Create($publisher.Extent.Text))
$copy = $ast.Find({ param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Copy-Unit'
},$true)
# A managed publication must not reintroduce .NET's cross-device copy fallback.
# Expected: Copy-Unit calls the native boundary; that boundary contains no File.Move call.
if ($copy.Extent.Text -notmatch 'Publish-PayloadFile \$temporary \$path' -or
    $copy.Extent.Text -match '\[IO.File\]::Move' -or
    $publisher.Extent.Text -match '\[IO.File\]::Move') {
  throw 'Payload publication bypasses the native rename boundary.'
}
$parent = Get-TestTemporaryParent
$fixture = Join-Path $parent ('codex-atomic-publish-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory $fixture | Out-Null
  $source = Join-Path $fixture 'source'
  $destination = Join-Path $fixture 'destination'
  # Exercise a real native replacement on the host, including paths with Unicode.
  # Expected: exact new bytes replace the destination and source disappears.
  $source = $source + ' 中文'
  [IO.File]::WriteAllText($source,'complete target bytes')
  [IO.File]::WriteAllText($destination,'before bytes')
  Publish-PayloadFile $source $destination
  if ((Test-Path $source) -or [IO.File]::ReadAllText($destination) -cne 'complete target bytes') {
    throw 'Native replacement failed.'
  }
  # Native failure must surface without truncating or replacing the destination.
  # Expected: missing source throws and existing bytes remain unchanged.
  $failed = $false
  try { Publish-PayloadFile $source $destination } catch { $failed = $true }
  if (-not $failed -or [IO.File]::ReadAllText($destination) -cne 'complete target bytes') {
    throw 'Native failure changed the destination or was suppressed.'
  }
  Write-Host 'Atomic publisher passed: native replacement and failure preserve complete bytes.'
  Write-Host 'UNVERIFIED: cross-device mount boundary and non-host native bindings.'
} finally {
  $resolved = [IO.Path]::GetFullPath($fixture)
  if ((Split-Path $resolved -Parent) -ne $parent -or
      (Split-Path $resolved -Leaf) -notlike 'codex-atomic-publish-*') { throw 'Unsafe cleanup.' }
  if (Test-Path $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
