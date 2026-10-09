[CmdletBinding()]
param(
    [string]$Path = '',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$clippingsRoot = Join-Path $projectRoot 'Clippings'
$mapPath = Join-Path $projectRoot 'system/registry/clipping-path-migrations.json'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$controls = @('.gitignore', 'README.md', 'temp-review-2026-07-05.md', 'temp-review-2026-07-13.md')
. (Join-Path $PSScriptRoot 'clippings-path-resolver.ps1')

function Write-Utf8 {
    param([string]$TargetPath, [string]$Text)
    $parent = Split-Path -Parent $TargetPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($TargetPath, $Text, $utf8NoBom)
}

function Get-RelativePath {
    param([string]$FullPath)
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return [IO.Path]::GetFullPath($FullPath).Substring($prefix.Length).Replace('\', '/')
}

function Get-Candidates {
    $files = if ([string]::IsNullOrWhiteSpace($Path)) {
        @(Get-ChildItem -LiteralPath $clippingsRoot -File | Where-Object { $_.Name -notin $controls })
    } else {
        @($Path -split ';' | ForEach-Object {
            $value = $_.Trim()
            if ([string]::IsNullOrWhiteSpace($value)) { return }
            $full = if ([IO.Path]::IsPathRooted($value)) { [IO.Path]::GetFullPath($value) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $value)) }
            if (-not $full.StartsWith($clippingsRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Normalization path must stay in Clippings: $value" }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Normalization source is missing: $value" }
            Get-Item -LiteralPath $full
        })
    }
    return @($files | Where-Object { -not (Test-CanonicalClippingPath -Path (Get-RelativePath $_.FullName)) } | Sort-Object Name)
}

$candidates = @(Get-Candidates)
$plans = New-Object System.Collections.Generic.List[object]
foreach ($file in $candidates) {
    $head = @(Get-Content -Encoding UTF8 -LiteralPath $file.FullName -TotalCount 20) -join "`n"
    $created = [regex]::Match($head, '(?m)^created:\s*["'']?(?<date>\d{4}-\d{2}-\d{2})["'']?\s*$')
    if (-not $created.Success) { throw "Clipping has no YYYY-MM-DD created date: $($file.Name)" }
    $prefix = $created.Groups['date'].Value.Replace('-', '')
    $targetName = "$prefix-$($file.Name)"
    $targetFull = Join-Path $clippingsRoot $targetName
    if (Test-Path -LiteralPath $targetFull) { throw "Clipping normalization target already exists: $targetName" }
    [void]$plans.Add([pscustomobject][ordered]@{
        old_path = Get-RelativePath -FullPath $file.FullName
        new_path = Get-RelativePath -FullPath $targetFull
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    })
}

if (-not $Apply) {
    Write-Output ([pscustomobject][ordered]@{ status = 'planned'; count = $plans.Count; migrations = @($plans | ForEach-Object { $_ }) } | ConvertTo-Json -Depth 10)
    exit 0
}

$map = if (Test-Path -LiteralPath $mapPath -PathType Leaf) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $mapPath | ConvertFrom-Json
} else {
    [pscustomobject][ordered]@{ schema_version = 1; migrations = @() }
}
if ([int]$map.schema_version -ne 1) { throw 'Unsupported clipping path migration schema.' }
$existingOld = @($map.migrations | ForEach-Object { [string]$_.old_path })
foreach ($plan in $plans) {
    if ($existingOld -contains [string]$plan.old_path) { throw "Migration old_path already registered: $($plan.old_path)" }
}

foreach ($plan in $plans) {
    $oldFull = Join-Path $projectRoot ([string]$plan.old_path)
    $newFull = Join-Path $projectRoot ([string]$plan.new_path)
    Move-Item -LiteralPath $oldFull -Destination $newFull
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $newFull).Hash.ToLowerInvariant() -ne [string]$plan.sha256) {
        throw "Clipping hash changed during normalization: $($plan.new_path)"
    }
}

$rawChanged = New-Object System.Collections.Generic.List[string]
foreach ($rawFile in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'raw-sources') -Filter '*.md' -File)) {
    $before = Get-Content -Raw -Encoding UTF8 -LiteralPath $rawFile.FullName
    $after = $before
    foreach ($plan in $plans) {
        $oldStem = ([string]$plan.old_path).Substring(0, ([string]$plan.old_path).Length - 3)
        $newStem = ([string]$plan.new_path).Substring(0, ([string]$plan.new_path).Length - 3)
        $after = $after.Replace("[[$oldStem]]", "[[$newStem]]")
        $after = $after.Replace("[[$($plan.old_path)]]", "[[$($plan.new_path)]]")
    }
    if ($after -ne $before) {
        Write-Utf8 -TargetPath $rawFile.FullName -Text $after
        [void]$rawChanged.Add((Get-RelativePath -FullPath $rawFile.FullName))
    }
}

$dated = Get-Date -Format 'yyyy-MM-dd'
$newEntries = @($plans | ForEach-Object {
    [pscustomobject][ordered]@{
        old_path = [string]$_.old_path
        new_path = [string]$_.new_path
        sha256 = [string]$_.sha256
        migrated_at = $dated
        reason = 'canonical-date-prefix'
    }
})
$map.migrations = @($map.migrations + $newEntries | Sort-Object old_path)
$json = @(($map | ConvertTo-Json -Depth 10) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
Write-Utf8 -TargetPath $mapPath -Text ($json + "`n")

Write-Output ([pscustomobject][ordered]@{ status = 'applied'; count = $plans.Count; raw_files_updated = @($rawChanged); migration_map = Get-RelativePath $mapPath } | ConvertTo-Json -Depth 10)
exit 0
