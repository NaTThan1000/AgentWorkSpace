function Test-CanonicalClippingPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $normalized = $Path.Replace('\', '/').Trim()
    return $normalized -match '^Clippings/\d{8}-.+\.md$'
}

function ConvertTo-ClippingPath {
    param([string]$Reference)
    if ([string]::IsNullOrWhiteSpace($Reference)) { return '' }
    $value = $Reference.Trim().Trim('"', "'")
    if ($value -match '^\[\[(?<path>[^\]]+)\]\]$') { $value = $Matches['path'] }
    $value = $value.Replace('\', '/')
    if (-not $value.StartsWith('Clippings/', [StringComparison]::OrdinalIgnoreCase)) {
        $value = 'Clippings/' + $value.TrimStart('/')
    }
    if (-not $value.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) { $value += '.md' }
    return $value
}

function Resolve-ClippingPathMigration {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RequestedFullPath
    )

    if (Test-Path -LiteralPath $RequestedFullPath -PathType Leaf) { return $RequestedFullPath }
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    $requested = [IO.Path]::GetFullPath($RequestedFullPath)
    if (-not $requested.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $RequestedFullPath }
    $relative = $requested.Substring($prefix.Length).Replace('\', '/')
    if (-not $relative.StartsWith('Clippings/', [StringComparison]::OrdinalIgnoreCase)) { return $RequestedFullPath }

    $mapPath = Join-Path $root 'system/registry/clipping-path-migrations.json'
    if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) { return $RequestedFullPath }
    $map = Get-Content -Raw -Encoding UTF8 -LiteralPath $mapPath | ConvertFrom-Json
    if ([int]$map.schema_version -ne 1) { throw 'Unsupported clipping path migration schema.' }
    $matches = @($map.migrations | Where-Object {
        [string]$_.old_path -eq $relative
    })
    if ($matches.Count -eq 0) { return $RequestedFullPath }
    if ($matches.Count -ne 1) { throw "Duplicate clipping migration source: $relative" }

    $entry = $matches[0]
    $targetRelative = [string]$entry.new_path
    if (-not (Test-CanonicalClippingPath -Path $targetRelative)) {
        throw "Clipping migration target is not canonical: $targetRelative"
    }
    $targetFull = [IO.Path]::GetFullPath((Join-Path $root $targetRelative))
    if (-not $targetFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Clipping migration target escapes Knowledge: $targetRelative"
    }
    if (-not (Test-Path -LiteralPath $targetFull -PathType Leaf)) {
        throw "Clipping migration target is missing: $targetRelative"
    }
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [IO.File]::ReadAllBytes($targetFull)
        $actualHash = (([BitConverter]::ToString($hasher.ComputeHash($bytes))) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $hasher.Dispose()
    }
    if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) {
        throw "Clipping migration target hash drifted: $targetRelative"
    }
    return $targetFull
}
