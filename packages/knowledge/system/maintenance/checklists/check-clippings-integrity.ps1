[CmdletBinding()]
param([switch]$IncludeHistoricalEvidence)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $PSScriptRoot 'clippings-path-resolver.ps1')
$failures = New-Object System.Collections.Generic.List[string]
$resolvedMigrationCache = @{}
$migrationOldPaths = @{}
$script:legacyMissingReferenceCount = 0
$script:recoveryPendingCount = 0
$controls = @('.gitignore', 'README.md', 'temp-review-2026-07-05.md', 'temp-review-2026-07-13.md')
$mapPath = Join-Path $projectRoot 'system/registry/clipping-path-migrations.json'

function Add-Failure {
    param([string]$Message)
    [void]$failures.Add($Message)
}

function Get-RelativePath {
    param([string]$FullPath)
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return [IO.Path]::GetFullPath($FullPath).Substring($prefix.Length).Replace('\', '/')
}

function Resolve-Reference {
    param([string]$Path, [string]$Owner, [switch]$Strict)
    $relative = ConvertTo-ClippingPath -Reference $Path
    if ($relative -match '[*?]' -or $relative -match '^Clippings/YYYYMMDD-') { return }
    try {
        $requested = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
        if (Test-Path -LiteralPath $requested -PathType Leaf) { return }
        $cacheKey = $relative.ToLowerInvariant()
        if (-not $Strict -and -not $migrationOldPaths.ContainsKey($cacheKey)) {
            $script:legacyMissingReferenceCount++
            return
        }
        $resolved = if ($resolvedMigrationCache.ContainsKey($cacheKey)) {
            [string]$resolvedMigrationCache[$cacheKey]
        } else {
            $value = Resolve-ClippingPathMigration -ProjectRoot $projectRoot -RequestedFullPath $requested
            $resolvedMigrationCache[$cacheKey] = $value
            $value
        }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { Add-Failure "$Owner has unresolved clipping reference: $relative" }
    } catch {
        Add-Failure "$Owner has invalid clipping reference '$relative': $($_.Exception.Message)"
    }
}

$articleFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Clippings') -File | Where-Object { $_.Name -notin $controls })
foreach ($file in $articleFiles) {
    $relative = Get-RelativePath -FullPath $file.FullName
    if (-not (Test-CanonicalClippingPath -Path $relative)) { Add-Failure "Noncanonical clipping filename: $relative" }
    if ($file.Length -eq 0) { Add-Failure "Empty clipping file: $relative"; continue }
    $head = @(Get-Content -Encoding UTF8 -LiteralPath $file.FullName -TotalCount 20) -join "`n"
    if ($head -match '(?m)^capture_status:\s*missing\s*$') { $script:recoveryPendingCount++ }
}

if (Test-Path -LiteralPath $mapPath -PathType Leaf) {
    $map = Get-Content -Raw -Encoding UTF8 -LiteralPath $mapPath | ConvertFrom-Json
    if ([int]$map.schema_version -ne 1) { Add-Failure 'Migration map schema_version must be 1.' }
    $oldPaths = @($map.migrations | ForEach-Object { [string]$_.old_path })
    $newPaths = @($map.migrations | ForEach-Object { [string]$_.new_path })
    if (@($oldPaths | Select-Object -Unique).Count -ne $oldPaths.Count) { Add-Failure 'Migration map contains duplicate old_path values.' }
    foreach ($oldPathValue in $oldPaths) { $migrationOldPaths[$oldPathValue.ToLowerInvariant()] = $true }
    foreach ($entry in @($map.migrations)) {
        $oldPath = [string]$entry.old_path
        $newPath = [string]$entry.new_path
        if ($oldPath -notmatch '^Clippings/.+\.md$') { Add-Failure "Migration old_path is invalid: $oldPath" }
        if (-not (Test-CanonicalClippingPath -Path $newPath)) { Add-Failure "Migration new_path is not canonical: $newPath" }
        if ([string]$entry.sha256 -notmatch '^[0-9a-fA-F]{64}$') { Add-Failure "Migration sha256 is invalid: $oldPath" }
        $oldFull = Join-Path $projectRoot $oldPath
        if (Test-Path -LiteralPath $oldFull -PathType Leaf) { Add-Failure "Migration old_path still exists: $oldPath" }
        Resolve-Reference -Path $oldPath -Owner 'migration-map' -Strict
    }
}

$rawFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'raw-sources') -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' })
$rawReferenceCount = 0
foreach ($file in $rawFiles) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    $frontmatter = [regex]::Match($text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { continue }
    $block = [regex]::Match($frontmatter.Groups['body'].Value, '(?ms)^source_clipping:\s*(?<value>.*?)(?=^\S[^:\r\n]*:\s*|\z)')
    if (-not $block.Success) { continue }
    foreach ($match in [regex]::Matches($block.Groups['value'].Value, '\[\[(?<path>[^\]]+)\]\]')) {
        $rawReferenceCount++
        $relative = ConvertTo-ClippingPath -Reference $match.Groups['path'].Value
        if (-not (Test-CanonicalClippingPath -Path $relative)) { Add-Failure "Raw source_clipping is not canonical: $(Get-RelativePath $file.FullName) -> $relative" }
        Resolve-Reference -Path $relative -Owner (Get-RelativePath $file.FullName) -Strict
    }
}

$evidenceRoots = @((Join-Path $projectRoot 'system/registry'))
if ($IncludeHistoricalEvidence) { $evidenceRoots += (Join-Path $projectRoot 'system/maintenance/ingest-runs') }
$evidenceReferenceCount = 0
foreach ($root in $evidenceRoots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in @('.md', '.json') -and $_.FullName -ne $mapPath })) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($match in [regex]::Matches($text, 'Clippings/[^\r\n"\]\|<>]+?\.md')) {
            $evidenceReferenceCount++
            Resolve-Reference -Path $match.Value -Owner (Get-RelativePath $file.FullName) -Strict:($root.EndsWith('system\registry', [StringComparison]::OrdinalIgnoreCase))
        }
        foreach ($match in [regex]::Matches($text, '\[\[(?<path>Clippings/[^\]]+)\]\]')) {
            if ($match.Groups['path'].Value.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { continue }
            $evidenceReferenceCount++
            Resolve-Reference -Path $match.Groups['path'].Value -Owner (Get-RelativePath $file.FullName) -Strict:($root.EndsWith('system\registry', [StringComparison]::OrdinalIgnoreCase))
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "ERROR $_" }
    Write-Output "FAIL clipping integrity: failures=$($failures.Count) articles=$($articleFiles.Count) raw_refs=$rawReferenceCount evidence_refs=$evidenceReferenceCount legacy_missing_refs=$script:legacyMissingReferenceCount"
    exit 1
}

Write-Output "PASS clipping integrity: articles=$($articleFiles.Count) migrations=$($(if (Test-Path -LiteralPath $mapPath) { @((Get-Content -Raw -Encoding UTF8 -LiteralPath $mapPath | ConvertFrom-Json).migrations).Count } else { 0 })) raw_refs=$rawReferenceCount evidence_refs=$evidenceReferenceCount legacy_missing_refs=$script:legacyMissingReferenceCount recovery_pending=$script:recoveryPendingCount"
exit 0
