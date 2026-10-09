[CmdletBinding()]
param(
    [ValidateSet('Check', 'Sync')]
    [string]$Mode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$mapPath = Join-Path $projectRoot 'system/registry/clipping-path-migrations.json'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'clippings-path-resolver.ps1')

function Get-ProjectPath {
    param([string]$RelativePath)
    $rootPrefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath((Join-Path $projectRoot $RelativePath))
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Clipping migration path escapes Knowledge: $RelativePath"
    }
    return $full
}

if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
    throw 'Missing clipping migration map.'
}

$map = Get-Content -Raw -Encoding UTF8 -LiteralPath $mapPath | ConvertFrom-Json
if ([int]$map.schema_version -ne 1) { throw 'Unsupported clipping migration schema.' }

$oldPaths = @($map.migrations | ForEach-Object { [string]$_.old_path })
if (@($oldPaths | Select-Object -Unique).Count -ne $oldPaths.Count) {
    throw 'Clipping migration map contains duplicate old_path values.'
}

$drifts = New-Object 'System.Collections.Generic.List[object]'
foreach ($entry in @($map.migrations)) {
    $oldPath = [string]$entry.old_path
    $newPath = [string]$entry.new_path
    if ($oldPath -notmatch '^Clippings/.+\.md$') { throw "Invalid clipping migration old_path: $oldPath" }
    if (-not (Test-CanonicalClippingPath -Path $newPath)) { throw "Invalid clipping migration new_path: $newPath" }
    if ([string]$entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Invalid clipping migration sha256: $oldPath" }

    $oldFull = Get-ProjectPath -RelativePath $oldPath
    $newFull = Get-ProjectPath -RelativePath $newPath
    if (Test-Path -LiteralPath $oldFull -PathType Leaf) { throw "Clipping migration old_path still exists: $oldPath" }
    if (-not (Test-Path -LiteralPath $newFull -PathType Leaf)) { throw "Clipping migration target is missing: $newPath" }

    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $newFull).Hash.ToLowerInvariant()
    $recorded = ([string]$entry.sha256).ToLowerInvariant()
    if ($actual -ne $recorded) {
        [void]$drifts.Add([pscustomobject][ordered]@{
            old_path = $oldPath
            new_path = $newPath
            recorded_sha256 = $recorded
            actual_sha256 = $actual
        })
    }
}

if ($Mode -eq 'Check') {
    [pscustomobject][ordered]@{
        schema_version = 1
        status = if ($drifts.Count -eq 0) { 'passed' } else { 'failed' }
        mode = $Mode
        checked = @($map.migrations).Count
        drift_count = $drifts.Count
        drifts = @($drifts.ToArray())
    } | ConvertTo-Json -Depth 8
    if ($drifts.Count -gt 0) { exit 2 }
    exit 0
}

if ($drifts.Count -gt 0) {
    $byOldPath = @{}
    foreach ($drift in $drifts) { $byOldPath[[string]$drift.old_path] = [string]$drift.actual_sha256 }
    foreach ($entry in @($map.migrations)) {
        $oldPath = [string]$entry.old_path
        if ($byOldPath.ContainsKey($oldPath)) { $entry.sha256 = $byOldPath[$oldPath] }
    }
    $json = @(($map | ConvertTo-Json -Depth 10) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
    [IO.File]::WriteAllText($mapPath, $json + "`n", $utf8NoBom)
}

[pscustomobject][ordered]@{
    schema_version = 1
    status = 'synced'
    mode = $Mode
    checked = @($map.migrations).Count
    updated = $drifts.Count
    changes = @($drifts.ToArray())
} | ConvertTo-Json -Depth 8
exit 0
