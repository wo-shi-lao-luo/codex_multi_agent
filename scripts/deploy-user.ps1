# Persistent Kit deployment manager, protocol 1. Runs without a repository or the target version's installer.
# Only receipt-owned agents/Skill units are reconciled. Project data, feedback and global config are never deployed.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [ValidateSet('Deploy','Verify','Status','MarkStable','Restore','Recover','Prune')][string]$Action = 'Status',
  [string]$SourceRoot,
  [string]$GitRef,
  [string]$SnapshotId,
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents'),
  [switch]$Force,
  [ValidateRange(1,100)][int]$KeepSnapshots = 3,
  [switch]$ConfirmPrune
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$CodexHome = [IO.Path]::GetFullPath($CodexHome).TrimEnd('\','/')
$AgentsHome = [IO.Path]::GetFullPath($AgentsHome).TrimEnd('\','/')
$managerRoot = Join-Path $AgentsHome 'codex-multi-agent'
$receiptPath = Join-Path $managerRoot 'install-receipt.json'
$pendingPath = Join-Path $managerRoot 'pending.json'
$scriptFile = $PSCommandPath
$exportRoot = $null
$lock = $null
foreach ($homePath in @($CodexHome,$AgentsHome)) {
  if (-not $homePath -or $homePath -eq [IO.Path]::GetPathRoot($homePath).TrimEnd('\','/') -or $homePath -eq [IO.Path]::GetFullPath($HOME).TrimEnd('\','/')) { throw 'PATH: A filesystem root or user home cannot be an installation directory.' }
}

# All recursive operations use prevalidated absolute paths. Check ancestors as well as leaves:
# a junction at an ancestor is just as dangerous as one at a destination.
function Assert-PlainPath([string]$Path) {
  $cursor = [IO.Path]::GetFullPath($Path)
  while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "PATH: Linked path is unsupported: $cursor" }
    $cursor = Split-Path -Parent $cursor
  }
}

# Keys are portable receipt names, never executable instructions or absolute filesystem paths.
function Assert-Key([string]$Key, [switch]$Unit) {
  if ($Key -notmatch '^(agents/[a-z0-9][a-z0-9-]*\.toml|skills/[a-z0-9][a-z0-9-]*(/[^/]+)*)$' -or $Key -match '[\\:]') { throw "PATH: Invalid package key $Key" }
  foreach ($segment in $Key.Split('/')) {
    if ($segment -in @('.','..') -or $segment -match '[<>"|?*\x00-\x1f]' -or $segment.EndsWith('.') -or $segment.EndsWith(' ') -or $segment -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)') { throw 'PATH: Unsafe package segment.' }
  }
  if ($Unit -and $Key.StartsWith('skills/') -and $Key.Split('/').Count -ne 2) { throw 'PATH: Expected a whole Skill unit.' }
}
function Get-Unit([string]$Key) {
  Assert-Key $Key
  if ($Key.StartsWith('agents/')) { return $Key }
  return ($Key.Split('/')[0..1] -join '/')
}
function Get-Destination([string]$Key) {
  Assert-Key $Key
  $path = if ($Key.StartsWith('agents/')) { Join-Path $CodexHome $Key } else { Join-Path $AgentsHome $Key }
  Assert-PlainPath $path
  return $path
}

# Recursively enumerate without following links, preserving empty directories for precise snapshots.
function Get-Tree([string]$Path) {
  Assert-PlainPath $Path
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  $item
  if ($item.PSIsContainer) {
    foreach ($child in Get-ChildItem -LiteralPath $Path -Force) { Get-Tree $child.FullName }
  }
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-Digest($Files) {
  $text = (@($Files | Sort-Object key | ForEach-Object { "$($_.key):$($_.sha256)" }) -join "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}

# Replace metadata only after a complete write in the same directory. Interrupted payload work is
# tracked separately in pending.json; this is not a claim of multi-directory atomicity.
function Write-Json([string]$Path, $Value) {
  Assert-PlainPath $Path
  $temporary = $Path + '.tmp-' + [guid]::NewGuid().ToString('N')
  try {
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporary -Encoding utf8
    [IO.File]::Move($temporary, $Path, $true)
  } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

# Normalize legacy absolute paths against the requested homes before granting ownership.
# Schema-v2 key and path must agree; malformed receipts never degrade to an empty installation.
function Read-Receipt {
  if (-not (Test-Path -LiteralPath $receiptPath)) { return $null }
  Assert-PlainPath $receiptPath
  try { $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable } catch { throw 'RECEIPT: Invalid JSON; repair ownership before deployment.' }
  if ($receipt.schemaVersion -notin @(1,2) -or $receipt.kitVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'RECEIPT: Unsupported version.' }
  if ($receipt.schemaVersion -eq 2 -and $receipt.managerProtocol -ne 1) { throw 'RECEIPT: Unsupported manager protocol; use its compatible recovery runtime.' }
  if ([IO.Path]::GetFullPath($receipt.codexHome).TrimEnd('\','/') -ne $CodexHome -or [IO.Path]::GetFullPath($receipt.agentsHome).TrimEnd('\','/') -ne $AgentsHome) { throw 'RECEIPT: Home directories do not match.' }
  $seen = @{}
  foreach ($file in $receipt.files) {
    $path = [IO.Path]::GetFullPath([string]$file.path)
    $key = $null
    foreach ($mapping in @(@{root=$CodexHome; prefix='agents'}, @{root=$AgentsHome; prefix='skills'})) {
      $prefix = (Join-Path $mapping.root $mapping.prefix) + [IO.Path]::DirectorySeparatorChar
      if ($path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { $key = [IO.Path]::GetRelativePath($mapping.root,$path).Replace('\','/') }
    }
    if (-not $key) { throw 'RECEIPT: File is outside managed agent/Skill namespaces.' }
    Assert-Key $key
    if ($receipt.schemaVersion -eq 2 -and $file.key -cne $key) { throw 'RECEIPT: Key and path disagree.' }
    if ($seen.ContainsKey($key) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'RECEIPT: Duplicate file or invalid hash.' }
    $seen[$key] = $true
    $file.key = $key
  }
  if (@($receipt.files).Count -eq 0) { throw 'RECEIPT: Empty ownership receipt is not a valid installed Kit.' }
  $receipt.units = @($receipt.files | ForEach-Object { Get-Unit $_.key } | Sort-Object -Unique)
  if ($receipt.schemaVersion -eq 1) {
    $receipt.runtimeDataSchema = 1
    $receipt.directories = @(Get-ExpectedDirectories $receipt.files)
    $receipt.source = @{ kind='legacy-receipt'; commit=$null; dirty=$null }
  }
  foreach ($dir in $receipt.directories) {
    Assert-Key $dir
    if ((Get-Unit $dir) -notin $receipt.units) { throw 'RECEIPT: Directory outside owned units.' }
  }
  if ($receipt.runtimeDataSchema -isnot [long] -and $receipt.runtimeDataSchema -isnot [int]) { throw 'RECEIPT: Missing runtime data contract.' }
  if ($receipt.schemaVersion -eq 2 -and (Get-Digest $receipt.files) -cne $receipt.packageDigest) { throw 'RECEIPT: Package digest mismatch.' }
  return $receipt
}

# Legacy receipts did not list directories. Infer only parent directories of their owned files.
function Get-ExpectedDirectories($Files) {
  $dirs = @{}
  foreach ($file in $Files) {
    if (-not $file.key.StartsWith('skills/')) { continue }
    $parts = $file.key.Split('/')
    for ($i=1; $i -lt $parts.Count-1; $i++) { $dirs[($parts[0..$i] -join '/')] = $true }
  }
  return @($dirs.Keys | Sort-Object)
}

# Build a deterministic source package manifest; never run scripts from the requested Git version.
function Read-Package([string]$Root, $Provenance) {
  Assert-PlainPath $Root
  $version = (Get-Content -LiteralPath (Join-Path $Root 'VERSION') -Raw).Trim()
  if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'PACKAGE: Invalid VERSION.' }
  $files = @(); $directories = @()
  foreach ($area in @('agents','skills')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $area) -PathType Container)) { throw "PACKAGE: Missing $area" }
    foreach ($item in @(Get-Tree (Join-Path $Root $area) | Select-Object -Skip 1)) {
      $key = [IO.Path]::GetRelativePath($Root,$item.FullName).Replace('\','/')
      Assert-Key $key
      if ($item.PSIsContainer) { $directories += $key }
      else { $files += @{ key=$key; sha256=(Get-Sha $item.FullName) } }
    }
  }
  $units = @($files | ForEach-Object { Get-Unit $_.key } | Sort-Object -Unique)
  if (@($units | Where-Object { $_.StartsWith('agents/') }).Count -eq 0 -or @($units | Where-Object { $_.StartsWith('skills/') }).Count -eq 0) { throw 'PACKAGE: Expected nonempty agent and Skill sets.' }
  foreach ($unit in $units) {
    if ($unit.StartsWith('skills/') -and -not (Test-Path -LiteralPath (Join-Path $Root "$unit/SKILL.md") -PathType Leaf)) { throw "PACKAGE: Skill has no SKILL.md: $unit" }
  }
  foreach ($dir in $directories) { if ((Get-Unit $dir) -notin $units) { throw 'PACKAGE: Empty unowned Skill directory.' } }
  $dataSchema = 1
  if (Test-Path -LiteralPath (Join-Path $Root 'deployment.json')) {
    $contract = Get-Content -LiteralPath (Join-Path $Root 'deployment.json') -Raw | ConvertFrom-Json -AsHashtable
    if ($contract.runtimeDataSchema -isnot [long] -and $contract.runtimeDataSchema -isnot [int]) { throw 'DATA_SCHEMA: Integer runtimeDataSchema required.' }
    $dataSchema = $contract.runtimeDataSchema
  }
  return @{ schemaVersion=1; kitVersion=$version; runtimeDataSchema=$dataSchema; files=$files; directories=$directories; units=$units; source=$Provenance; packageDigest=(Get-Digest $files) }
}

# Inspect entire selected units. Unknown files inside an owned Skill are conflicts, not disposable data.
function Test-Installed($Manifest, [string[]]$Units) {
  $actual = @{}; $dirs = @{}
  foreach ($unit in $Units) {
    Assert-Key $unit -Unit
    $destination = Get-Destination $unit
    foreach ($item in @(Get-Tree $destination)) {
      $key = if ($item.FullName -eq $destination) { $unit } else { $unit + '/' + [IO.Path]::GetRelativePath($destination,$item.FullName).Replace('\','/') }
      if ($item.PSIsContainer) { $dirs[$key] = $true } else { $actual[$key] = Get-Sha $item.FullName }
    }
  }
  $expected = @{}
  foreach ($file in @($Manifest.files)) { $expected[$file.key] = $file.sha256 }
  if ($actual.Count -ne $expected.Count -or $dirs.Count -ne @($Manifest.directories).Count) { return $false }
  foreach ($key in $expected.Keys) { if (-not $actual.ContainsKey($key) -or $actual[$key] -cne $expected[$key]) { return $false } }
  foreach ($dir in @($Manifest.directories)) { if (-not $dirs.ContainsKey($dir)) { return $false } }
  return $true
}

# Validate an inactive package tree before any active file is touched, including unexpected empty
# directories. This catches source edits during staging and snapshot corruption before activation.
function Assert-Payload($Manifest, [string]$Root) {
  $actual=@{}; $dirs=@{}
  foreach ($item in @(Get-Tree $Root | Select-Object -Skip 1)) {
    $key=[IO.Path]::GetRelativePath($Root,$item.FullName).Replace('\','/')
    if ($item.PSIsContainer -and $key -in @('agents','skills')) { continue }
    Assert-Key $key
    if ($item.PSIsContainer) { $dirs[$key]=$true } else { $actual[$key]=Get-Sha $item.FullName }
  }
  if ($actual.Count -ne @($Manifest.files).Count -or $dirs.Count -ne @($Manifest.directories).Count) { throw 'PACKAGE: Payload inventory mismatch.' }
  foreach ($file in $Manifest.files) { if (-not $actual.ContainsKey($file.key) -or $actual[$file.key] -cne $file.sha256) { throw 'PACKAGE: Payload hash mismatch.' } }
  foreach ($dir in $Manifest.directories) { if (-not $dirs.ContainsKey($dir)) { throw 'PACKAGE: Payload directory mismatch.' } }
}

# Snapshots capture actual bytes (including Force conflicts), plus exact original receipt for recovery.
# Snapshot payload is outside discovery paths and is never automatically marked stable.
function Save-Snapshot([string]$Id, [string[]]$Units, $Receipt, [string]$Kind) {
  $folder = Join-Path $managerRoot "backups/$Id"
  Assert-PlainPath $folder
  New-Item -ItemType Directory -Path "$folder/payload" -Force | Out-Null
  $files=@(); $dirs=@(); $present=@()
  foreach ($unit in $Units) {
    $destination = Get-Destination $unit
    if (-not (Test-Path -LiteralPath $destination)) { continue }
    $present += $unit
    foreach ($item in @(Get-Tree $destination)) {
      $key = if ($item.FullName -eq $destination) { $unit } else { $unit + '/' + [IO.Path]::GetRelativePath($destination,$item.FullName).Replace('\','/') }
      Assert-Key $key
      if ($item.PSIsContainer) { $dirs += $key } else { $files += @{key=$key; sha256=(Get-Sha $item.FullName)} }
    }
    $copy = Join-Path "$folder/payload" $unit
    New-Item -ItemType Directory -Force (Split-Path -Parent $copy) | Out-Null
    Copy-Item -LiteralPath $destination -Destination $copy -Recurse
  }
  $manifest = @{ schemaVersion=1; id=$Id; kind=$Kind; codexHome=$CodexHome; agentsHome=$AgentsHome; files=$files; directories=$dirs; units=$present; restoreScope=$Units; packageDigest=(Get-Digest $files); kitVersion='0.0.0'; runtimeDataSchema=1; source=@{kind='empty'}; receiptText=$null }
  if ($Receipt) {
    $manifest.kitVersion=$Receipt.kitVersion; $manifest.runtimeDataSchema=$Receipt.runtimeDataSchema; $manifest.source=$Receipt.source
    $manifest.receiptText=Get-Content -LiteralPath $receiptPath -Raw
  }
  Write-Json "$folder/manifest.json" $manifest
  return $manifest
}

# Validate snapshot shape, containment and every payload byte before using it for writes or recovery.
function Read-Snapshot([string]$Id) {
  if ($Id -notmatch '^\d{8}T\d{6}-[a-f0-9]{32}$') { throw 'SNAPSHOT: Invalid snapshot ID.' }
  $folder=Join-Path $managerRoot "backups/$Id"
  Assert-PlainPath $folder
  $m=Get-Content -LiteralPath "$folder/manifest.json" -Raw | ConvertFrom-Json -AsHashtable
  if ($m.schemaVersion -ne 1 -or $m.id -cne $Id -or $m.codexHome -ne $CodexHome -or $m.agentsHome -ne $AgentsHome) { throw 'SNAPSHOT: Invalid metadata or different homes.' }
  $seen=@{}
  foreach ($unit in $m.units) { Assert-Key $unit -Unit }
  foreach ($unit in $m.restoreScope) { Assert-Key $unit -Unit }
  foreach ($file in $m.files) {
    Assert-Key $file.key
    if ((Get-Unit $file.key) -notin $m.units -or $seen.ContainsKey($file.key)) { throw 'SNAPSHOT: Invalid ownership or duplicate file.' }
    $seen[$file.key]=$true
    $path=Join-Path "$folder/payload" $file.key
    Assert-PlainPath $path
    if ((Get-Sha $path) -cne $file.sha256) { throw 'SNAPSHOT: Payload hash mismatch.' }
  }
  foreach ($dir in $m.directories) { Assert-Key $dir; if ((Get-Unit $dir) -notin $m.units) { throw 'SNAPSHOT: Invalid directory.' } }
  $actualFiles=@(Get-Tree "$folder/payload" | Where-Object { -not $_.PSIsContainer })
  if ($actualFiles.Count -ne @($m.files).Count -or (Get-Digest $m.files) -cne $m.packageDigest) { throw 'SNAPSHOT: Unexpected payload or digest.' }
  Assert-Payload $m "$folder/payload"
  return $m
}

# Remove only one validated component, never a home/root. Recursion occurs only after link scanning.
function Remove-Unit([string]$Unit) {
  Assert-Key $Unit -Unit
  $path=Get-Destination $Unit
  $null=@(Get-Tree $path)
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
function Copy-Unit([string]$Root,[string]$Unit) {
  Assert-Key $Unit -Unit
  $source=Join-Path $Root $Unit
  $null=@(Get-Tree $source)
  $destination=Get-Destination $Unit
  New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Recurse
}

# Preview and execution share retention rules; recompute under the lock before any pruning.
function Get-PruneCandidates {
  $stableId=if (Test-Path "$managerRoot/stable.json") { (Get-Content "$managerRoot/stable.json" -Raw | ConvertFrom-Json).snapshotId } else { '' }
  $all=@(Get-ChildItem -LiteralPath "$managerRoot/backups" -Directory -ErrorAction SilentlyContinue | Where-Object Name -match '^\d{8}T\d{6}-[a-f0-9]{32}$' | Sort-Object LastWriteTimeUtc -Descending)
  $retained=@($all | Select-Object -First $KeepSnapshots -ExpandProperty Name)+@($stableId)
  return @($all | Where-Object { $_.Name -notin $retained })
}

# Recovery restores the complete before-image and exact original receipt. Journal is removed only
# after verification; failure leaves it blocking future deploys. It never guesses a stale lock owner.
function Restore-Pending {
  $journal=Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json -AsHashtable
  if ($journal.schemaVersion -ne 1) { throw 'PENDING: Unsupported journal.' }
  $before=Read-Snapshot $journal.snapshotId
  foreach ($unit in $journal.units) { Assert-Key $unit -Unit }
  if ($journal.units.Count -eq 0) { throw 'PENDING: Empty transaction.' }
  foreach ($unit in $before.units) { if ($unit -notin $journal.units) { throw 'PENDING: Incomplete restore scope.' } }
  # The journal scope must match the independently recorded before/target union, not arbitrary paths.
  if ((@($journal.units | Sort-Object -Unique) -join '|') -cne (@($before.restoreScope | Sort-Object -Unique) -join '|')) { throw 'PENDING: Scope mismatch.' }
  # A crashed operation does not authorize erasing subsequent user edits. Accept only files from
  # its before-image or intended target (including partial copies); unknown bytes require inspection.
  $allowed=@{}
  foreach ($file in @($before.files)+@($journal.targetFiles)) {
    Assert-Key $file.key
    if ((Get-Unit $file.key) -notin $journal.units) { throw 'PENDING: Target file outside operation scope.' }
    if (-not $allowed.ContainsKey($file.key)) { $allowed[$file.key]=@() }
    $allowed[$file.key]+=$file.sha256
  }
  foreach ($unit in $journal.units) {
    $destination=Get-Destination $unit
    foreach ($item in @(Get-Tree $destination)) {
      $key=if ($item.FullName -eq $destination) {$unit} else {$unit+'/'+[IO.Path]::GetRelativePath($destination,$item.FullName).Replace('\','/')}
      if ($item.PSIsContainer) {
        if ($key -notin (@($before.directories)+@($journal.targetDirectories))) { throw 'RECOVERY_CONFLICT: A new directory appeared after interruption; preserve it before recovery.' }
      } elseif (-not $allowed.ContainsKey($key) -or (Get-Sha $item.FullName) -notin $allowed[$key]) { throw 'RECOVERY_CONFLICT: File changed outside the interrupted operation; inspect before recovery.' }
    }
  }
  foreach ($unit in $journal.units) {
    Remove-Unit $unit
    if ($unit -in $before.units) { Copy-Unit (Join-Path $managerRoot "backups/$($journal.snapshotId)/payload") $unit }
  }
  if (-not (Test-Installed $before $journal.units)) { throw 'RECOVERY: Restored files do not match snapshot.' }
  if ($null -ne $before.receiptText) {
    $tempReceipt=$receiptPath+'.restore'
    [IO.File]::WriteAllText($tempReceipt,$before.receiptText)
    [IO.File]::Move($tempReceipt,$receiptPath,$true)
  } elseif (Test-Path -LiteralPath $receiptPath) { Remove-Item -LiteralPath $receiptPath -Force }
  $staleStage=Join-Path $managerRoot "staging/$($journal.snapshotId)"
  $null=@(Get-Tree $staleStage)
  if (Test-Path -LiteralPath $staleStage) { Remove-Item -LiteralPath $staleStage -Recurse -Force }
  Remove-Item -LiteralPath $pendingPath -Force
}

# An immutable copy of this manager plus a small launcher survives Git checkout and Kit downgrade.
# Management files are deliberately outside the deployable agent/Skill payload and have protocol 1.
function Install-Manager {
  $digest=Get-Sha $scriptFile
  $folder=Join-Path $managerRoot "manager/$digest"
  Assert-PlainPath $folder
  New-Item -ItemType Directory -Force $folder | Out-Null
  $copy=Join-Path $folder 'deploy-user.ps1'
  if (-not (Test-Path -LiteralPath $copy)) { Copy-Item -LiteralPath $scriptFile -Destination $copy }
  if ((Get-Sha $copy) -cne $digest) { throw 'MANAGER: Installed runtime hash mismatch.' }
  $launcher=@'
# Persistent recovery entrypoint, independent of the current repository checkout.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manager.json') -Raw | ConvertFrom-Json
if ($config.protocol -ne 1 -or $config.digest -notmatch '^[a-f0-9]{64}$') { throw 'Invalid manager pointer.' }
$entry = Join-Path $PSScriptRoot "manager/$($config.digest)/deploy-user.ps1"
if ((Get-FileHash -LiteralPath $entry -Algorithm SHA256).Hash.ToLowerInvariant() -cne $config.digest) { throw 'Manager integrity check failed.' }
& $entry @args
'@
  $launcherPath=Join-Path $managerRoot 'rollback.ps1'
  if (Test-Path -LiteralPath $launcherPath) {
    if ((Get-Content -LiteralPath $launcherPath -Raw).Trim() -cne $launcher.Trim()) { throw 'MANAGER: Customized launcher; inspect instead of overwriting.' }
  } else { Set-Content -LiteralPath $launcherPath -Value $launcher -Encoding utf8 }
  Write-Json (Join-Path $managerRoot 'manager.json') @{ protocol=1; digest=$digest }
}

try {
  foreach ($path in @($CodexHome,$AgentsHome,$managerRoot)) { Assert-PlainPath $path }
  # Homes may not overlap: otherwise an apparently safe component key can alias manager/state files.
  $separator=[IO.Path]::DirectorySeparatorChar
  if ($CodexHome -eq $AgentsHome -or $CodexHome.StartsWith($AgentsHome+$separator,[StringComparison]::OrdinalIgnoreCase) -or $AgentsHome.StartsWith($CodexHome+$separator,[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Homes must be distinct, non-overlapping directories.' }
  if ($Action -ne 'Status' -and (Test-Path -LiteralPath $pendingPath) -and $Action -ne 'Recover') { throw 'PENDING: Run Recover before any further deployment.' }
  $current=if ($Action -eq 'Recover') { $null } else { Read-Receipt }
  if ($Action -eq 'Status') {
    @{ installed=$current; pending=(Test-Path -LiteralPath $pendingPath); snapshots=@(Get-ChildItem -LiteralPath (Join-Path $managerRoot 'backups') -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name); stable=if (Test-Path "$managerRoot/stable.json") { Get-Content "$managerRoot/stable.json" -Raw | ConvertFrom-Json } else { $null } } | ConvertTo-Json -Depth 25
    exit 0
  }
  if ($Action -eq 'Verify') {
    if (-not $current -or -not (Test-Installed $current $current.units)) { throw 'VERIFY: Installed files differ from the receipt.' }
    @{ valid=$true; kitVersion=$current.kitVersion; packageDigest=(Get-Digest $current.files) } | ConvertTo-Json
    exit 0
  }
  $target=$null; $payload=$null
  $stable=$null
  if ($Action -eq 'Deploy') {
    if (-not $SourceRoot) { throw 'SOURCE: SourceRoot is required.' }
    $SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
    $provenance=@{kind='directory'; commit=$null; dirty=$true}
    if ($GitRef) {
      $commit=(& git -C $SourceRoot rev-parse --verify --end-of-options "$GitRef^{commit}" 2>$null)
      if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[a-f0-9]{40,64}$') { throw 'SOURCE: Git ref did not resolve to a local commit.' }
      $exportRoot=Join-Path ([IO.Path]::GetTempPath()) ('codex-kit-export-'+[guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory $exportRoot | Out-Null
      & git -C $SourceRoot archive --format=zip "--output=$exportRoot/package.zip" $commit
      if ($LASTEXITCODE -ne 0) { throw 'SOURCE: Git export failed.' }
      $zip=[IO.Compression.ZipFile]::OpenRead("$exportRoot/package.zip")
      try {
        foreach ($entry in $zip.Entries) {
          if ($entry.FullName -match '(^|/)\.\.(/|$)|^[\\/]|:|\\' -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'SOURCE: Unsafe archive entry.' }
        }
      } finally { $zip.Dispose() }
      Expand-Archive -LiteralPath "$exportRoot/package.zip" -DestinationPath "$exportRoot/source"
      $payload="$exportRoot/source"; $provenance=@{kind='git';commit=$commit;dirty=$false}
    } else {
      $payload=$SourceRoot
      $gitRoot=(& git -C $SourceRoot rev-parse --show-toplevel 2>$null)
      if ($LASTEXITCODE -eq 0 -and [IO.Path]::GetFullPath($gitRoot) -eq $SourceRoot) {
        $provenance.commit=(& git -C $SourceRoot rev-parse HEAD).Trim()
        $provenance.dirty= -not [string]::IsNullOrWhiteSpace((& git -C $SourceRoot status --porcelain --untracked-files=normal | Out-String))
      }
    }
    $target=Read-Package $payload $provenance
  } elseif ($Action -eq 'Restore') {
    if (-not $SnapshotId) {
      if (-not (Test-Path "$managerRoot/stable.json")) { throw 'STABLE: No stable snapshot selected; specify SnapshotId or mark a verified install stable.' }
      $stable=Get-Content "$managerRoot/stable.json" -Raw | ConvertFrom-Json
      $SnapshotId=$stable.snapshotId
    }
    $target=Read-Snapshot $SnapshotId
    if ($stable -and ($stable.packageDigest -cne $target.packageDigest -or $stable.kitVersion -cne $target.kitVersion)) { throw 'STABLE: Snapshot does not match stable pointer.' }
    if (@($target.files).Count -eq 0) { throw 'SNAPSHOT: Pre-install empty snapshot is recovery-only.' }
    $payload=Join-Path $managerRoot "backups/$SnapshotId/payload"
    $target.source=@{kind='snapshot'; snapshotId=$SnapshotId; original=$target.source}
  }
  $units=@(); $plan=@()
  if ($target) {
    if ($current -and $current.runtimeDataSchema -gt $target.runtimeDataSchema) { throw 'DATA_SCHEMA: Target cannot safely consume current runtime data; explicit migration is required.' }
    $units=@(@($current.units)+@($target.units) | Where-Object { $_ } | Sort-Object -Unique)
    $expected=if ($current) { $current } else { @{files=@();directories=@()} }
    if (-not (Test-Installed $expected $units) -and -not $Force) { throw 'CONFLICT: Modified, missing or unowned files inside selected units. Review and use Force only to back up and replace these units.' }
    foreach ($unit in $units) {
      $plan += @{ unit=$unit; operation=if ($unit -notin $target.units) {'remove'} elseif (Test-Path -LiteralPath (Get-Destination $unit)) {'replace'} else {'install'} }
    }
  }
  if ($Action -eq 'Prune') { $plan=@(Get-PruneCandidates | ForEach-Object { @{snapshotId=$_.Name;operation='remove-snapshot'} }) }
  if (-not $PSCmdlet.ShouldProcess($managerRoot,"$Action Kit installation")) { @{ action='preview'; operations=$plan } | ConvertTo-Json -Depth 10; exit 0 }
  New-Item -ItemType Directory -Force $managerRoot | Out-Null
  $lockPath=Join-Path $managerRoot 'deployment.lock'
  Assert-PlainPath $lockPath
  try { $lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } catch { throw 'LOCK: Another deployment is active.' }
  if ($Action -eq 'Recover') {
    if (-not (Test-Path $pendingPath)) { throw 'PENDING: No interrupted operation.' }
    Restore-Pending
    @{action='recovered'} | ConvertTo-Json; exit 0
  }
  if (Test-Path $pendingPath) { throw 'PENDING: An interrupted operation appeared; recover first.' }
  # Recheck after locking, so a completed competing deploy cannot invalidate the earlier plan.
  $fresh=Read-Receipt
  if (($fresh | ConvertTo-Json -Depth 30 -Compress) -cne ($current | ConvertTo-Json -Depth 30 -Compress)) { throw 'CONFLICT: Installation changed during planning; retry inspection.' }
  if ($Action -eq 'Prune') {
    if (-not $ConfirmPrune) { throw 'APPROVAL: Prune requires ConfirmPrune.' }
    $removed=@()
    foreach ($folder in @(Get-PruneCandidates)) { $null=Read-Snapshot $folder.Name; $null=@(Get-Tree $folder.FullName); Remove-Item -LiteralPath $folder.FullName -Recurse -Force; $removed+=$folder.Name }
    @{action='pruned'; removed=$removed; recoverable=$false} | ConvertTo-Json; exit 0
  }
  $id=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss')+'-'+[guid]::NewGuid().ToString('N')
  if ($Action -eq 'MarkStable') {
    if (-not $current -or -not (Test-Installed $current $current.units)) { throw 'VERIFY: Only an unchanged verified installation can be marked stable.' }
    $snapshot=Save-Snapshot $id $current.units $current 'stable'
    $null=Read-Snapshot $id
    Install-Manager
    Write-Json "$managerRoot/stable.json" @{snapshotId=$id;kitVersion=$current.kitVersion;packageDigest=$snapshot.packageDigest}
    @{action='stable';snapshotId=$id;kitVersion=$current.kitVersion} | ConvertTo-Json; exit 0
  }
  $expected=if ($current) { $current } else { @{files=@();directories=@()} }
  if (-not (Test-Installed $expected $units) -and -not $Force) { throw 'CONFLICT: Files changed after planning.' }
  $stage=Join-Path $managerRoot "staging/$id"
  Assert-PlainPath $stage
  New-Item -ItemType Directory -Force $stage | Out-Null
  try {
    foreach ($unit in $target.units) {
      $destination=Join-Path $stage $unit
      New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
      Copy-Item -LiteralPath (Join-Path $payload $unit) -Destination $destination -Recurse
    }
    foreach ($file in $target.files) { if ((Get-Sha (Join-Path $stage $file.key)) -cne $file.sha256) { throw 'PACKAGE: Source changed while staging.' } }
    Assert-Payload $target $stage
    $before=Save-Snapshot $id $units $current 'before-deploy'
    $null=Read-Snapshot $id
    $journal=@{schemaVersion=1;snapshotId=$id;units=$units;targetFiles=$target.files;targetDirectories=$target.directories;phase='applying';completed=@()}
    Write-Json $pendingPath $journal
    try {
      foreach ($unit in $units) {
        Remove-Unit $unit
        if ($unit -in $target.units) { Copy-Unit $stage $unit }
        $journal.completed+= $unit
        Write-Json $pendingPath $journal
        Write-Verbose 'Unit activated.'
      }
      if (-not (Test-Installed $target $units)) { throw 'VERIFY: Deployment does not exactly match target.' }
      $files=@($target.files | ForEach-Object { @{ key=$_.key; path=(Get-Destination $_.key); sha256=$_.sha256 } })
      $receipt=@{schemaVersion=2;kitVersion=$target.kitVersion;installedAt=(Get-Date).ToUniversalTime().ToString('o');installationId=$id;codexHome=$CodexHome;agentsHome=$AgentsHome;files=$files;directories=$target.directories;runtimeDataSchema=$target.runtimeDataSchema;source=$target.source;packageDigest=$target.packageDigest;managerProtocol=1}
      Install-Manager
      Write-Verbose 'Before receipt commit.'
      Write-Json $receiptPath $receipt
      Write-Verbose 'Receipt committed.'
      $null=Read-Receipt
      Remove-Item -LiteralPath $pendingPath -Force
    } catch {
      $failure=$_
      try { Restore-Pending } catch { throw "RECOVERY: Automatic restore failed; pending journal retained. $($_.Exception.Message) Original: $failure" }
      throw $failure
    }
  } finally {
    $null=@(Get-Tree $stage)
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
  }
  @{action='deployed';kitVersion=$target.kitVersion;installationId=$id;packageDigest=$target.packageDigest;operations=$plan;recoveryEntrypoint=(Join-Path $managerRoot 'rollback.ps1')} | ConvertTo-Json -Depth 15
} finally {
  if ($lock) { $lock.Dispose() }
  if ($exportRoot -and (Test-Path -LiteralPath $exportRoot)) {
    $resolved=[IO.Path]::GetFullPath($exportRoot)
    if ((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') -or (Split-Path $resolved -Leaf) -notlike 'codex-kit-export-*') { throw 'PATH: Unsafe export cleanup.' }
    $null=@(Get-Tree $resolved)
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
