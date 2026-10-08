# Fixed child adapter: trusted module code may execute, but no input source is evaluated.
#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Version', 'Format')][string]$Mode,
  [Parameter(Mandatory)][string]$ModulePath,
  [string]$SettingsPath
)
$ErrorActionPreference = 'Stop'
try {
  $module = Import-Module -Name $ModulePath -PassThru -ErrorAction Stop
  if ($Mode -eq 'Version') {
    [Console]::Out.Write(($module | Select-Object -First 1).Version.ToString())
    exit 0
  }
  $source = [Console]::In.ReadToEnd()
  $tokens = $null
  $parseErrors = $null
  $null = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count) { throw 'Invalid PowerShell syntax.' }
  $command = Get-Command Invoke-Formatter -Module ($module | Select-Object -First 1).Name -ErrorAction Stop
  $parameters = @{ ScriptDefinition = $source }
  if ($SettingsPath) { $parameters.Settings = Import-PowerShellDataFile -LiteralPath $SettingsPath }
  $formatted = & $command @parameters
  if ($formatted -isnot [string]) { throw 'Expected a single formatted string.' }
  [Console]::Out.Write($formatted)
} catch {
  # Never return source text or module diagnostics through the public tool record.
  [Console]::Error.Write('PowerShell formatter failed.')
  exit 2
}
