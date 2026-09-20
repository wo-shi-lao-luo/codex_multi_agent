[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][ValidateSet('Initialize', 'Validate')][string]$Action,
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$BlueprintPath = 'docs/architecture/project-blueprint.md'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'Project root must exist.' }
if ([IO.Path]::IsPathRooted($BlueprintPath)) { throw 'BlueprintPath must be repository-relative.' }
$path = [IO.Path]::GetFullPath((Join-Path $root $BlueprintPath))
$prefix = $root.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'BlueprintPath must stay inside ProjectRoot.' }
# Reject linked ancestors so initialization cannot escape through a directory junction.
$ancestor = $path
while ($ancestor -ne $root -and $ancestor.Length -ge $root.Length) {
  if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked blueprint paths are not supported.' }
  $ancestor = Split-Path -Parent $ancestor
}
if ($Action -eq 'Initialize') {
  if (Test-Path -LiteralPath $path) { throw 'Blueprint already exists; inspect and update it in place.' }
  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
  @'
# Project blueprint

Blueprint schema: 1
Blueprint revision: 1
Project context: draft
Refactor decision: pending
Decision evidence:

## Scope

## Baseline assessment

## Modules
| Module | Responsibility | Location | Dependencies |
| --- | --- | --- | --- |
| | | | |

## File responsibilities

## Composition roots

## Interfaces and ownership

## Structural evolution

## Verification

## Retained constraints
'@ | Set-Content -LiteralPath $path -Encoding utf8
  [PSCustomObject]@{ action = 'initialized'; blueprintPath = $path } | ConvertTo-Json
  return
}
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Blueprint does not exist.' }
$content = Get-Content -LiteralPath $path -Raw
$errors = [Collections.Generic.List[string]]::new()
$fields = @{}
foreach ($field in 'Blueprint schema', 'Blueprint revision', 'Project context', 'Refactor decision', 'Decision evidence') {
  $found = [regex]::Matches($content, '(?m)^' + [regex]::Escape($field) + ':[ \t]*([^\r\n]*)\r?$')
  if ($found.Count -ne 1 -or [string]::IsNullOrWhiteSpace($found[0].Groups[1].Value)) { $errors.Add("Require one nonempty $field field."); continue }
  $fields[$field] = $found[0].Groups[1].Value.Trim()
}
if ($fields['Blueprint schema'] -ne '1') { $errors.Add('Unsupported blueprint schema.') }
if ($fields['Blueprint revision'] -notmatch '^[1-9][0-9]*$') { $errors.Add('Blueprint revision must be a positive integer.') }
if ($fields['Project context'] -notin @('new', 'existing')) { $errors.Add('Project context must be new or existing.') }
if ($fields['Refactor decision'] -notin @('not needed', 'pending', 'approved', 'declined', 'deferred')) { $errors.Add('Unsupported refactor decision.') }
foreach ($heading in 'Scope', 'Baseline assessment', 'Modules', 'File responsibilities', 'Composition roots', 'Interfaces and ownership', 'Structural evolution', 'Verification', 'Retained constraints') {
  $sections = [regex]::Matches($content, '(?ms)^## ' + [regex]::Escape($heading) + '[ \t]*\r?\n(.*?)(?=^## |\z)')
  if ($sections.Count -ne 1 -or [string]::IsNullOrWhiteSpace($sections[0].Groups[1].Value)) { $errors.Add("Require one populated $heading section.") }
}
$moduleSection = [regex]::Match($content, '(?ms)^## Modules[ \t]*\r?\n(.*?)(?=^## |\z)')
$lines = @($moduleSection.Groups[1].Value -split '\r?\n' | Where-Object { $_.Trim().StartsWith('|') })
if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '| Module | Responsibility | Location | Dependencies |') { $errors.Add('Require module table and at least one module.') }
else {
  $ids = @{}
  foreach ($line in $lines[2..($lines.Count - 1)]) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 4 -or @($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { $errors.Add('Each module requires four nonempty cells.'); continue }
    if ($ids.ContainsKey($cells[0])) { $errors.Add('Duplicate module ID.') }
    $ids[$cells[0]] = $true
  }
}
if ($errors.Count) { throw ($errors -join "`n") }
[PSCustomObject]@{ action = 'validated'; blueprintPath = $path; revision = $fields['Blueprint revision']; refactorDecision = $fields['Refactor decision']; modules = @($ids.Keys) } | ConvertTo-Json
