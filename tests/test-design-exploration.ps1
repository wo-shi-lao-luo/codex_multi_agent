# Validate shared design-exploration distribution, not future Agent decision semantics.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
# DE-01: a Team planning/development installation needs its shared exploration reference.
# Expected: the source payload contains a nonempty UTF-8 reference; fake-home byte propagation
# is checked by test-install-user's full dynamic package map, not an invented semantic parser.
$reference=Join-Path $root 'skills/team-core/references/design-exploration.md'
if(-not(Test-Path -LiteralPath $reference -PathType Leaf)){throw 'DE-01 missing shared design-exploration reference.'}
$text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($reference))
if([string]::IsNullOrWhiteSpace($text)){throw 'DE-01 shared design-exploration reference is empty.'}
Write-Output 'Design-exploration source payload check passed; Agent behavior not tested.'
