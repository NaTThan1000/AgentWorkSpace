[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PairsPath,
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))

function Convert-UnicodeLiteral {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function Get-ProjectPath {
    param([string]$Path, [switch]$MustExist)
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $Path)) }
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $Path" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
    return $full
}

function Get-TextStats {
    param([string]$Path, [bool]$IsRaw)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $inFrontmatter = $false
    $frontmatterClosed = $false
    $bodyCount = 0
    $imageCount = 0
    $embedCount = 0
    $positionCount = 0
    $annotationHeading = Convert-UnicodeLiteral '## \u6279\u6ce8'
    $positionLiteral = Convert-UnicodeLiteral '\u539f\u6587\uff1a'

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]
        $trimmed = $line.Trim()
        if ($index -eq 0 -and $trimmed -eq '---') { $inFrontmatter = $true; continue }
        if ($inFrontmatter) {
            if ($trimmed -eq '---') { $inFrontmatter = $false; $frontmatterClosed = $true }
            continue
        }
        if ($IsRaw -and $trimmed -eq $annotationHeading) { break }
        if ($trimmed -match '!\[\[[^\]]+\]\]') { $embedCount++ }
        if ($trimmed -match '!\[[^\]]*\]\(' -or $trimmed -match '(?i)<img\s') { $imageCount++ }
        if ($trimmed.StartsWith('>') -and $trimmed.Contains($positionLiteral)) { $positionCount++; continue }
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^#{1,6}\s') { continue }
        if ($trimmed -match '^!\[[^\]]*\]\(' -or $trimmed -match '^!\[\[[^\]]+\]\]' -or $trimmed -match '^(?i)<img\s') { continue }
        $bodyCount++
    }
    return [pscustomobject][ordered]@{
        body_lines = $bodyCount
        image_lines = $imageCount
        embed_lines = $embedCount
        position_markers = $positionCount
        has_frontmatter = $frontmatterClosed
    }
}

try {
    $pairsFull = Get-ProjectPath -Path $PairsPath -MustExist
    $parsed = Get-Content -Raw -Encoding UTF8 -LiteralPath $pairsFull | ConvertFrom-Json
    $pairCount = if ($parsed -is [System.Array]) { $parsed.Count } else { 1 }
    if ($pairCount -lt 1) { throw 'PairsPath must contain at least one pair.' }
    $results = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $pairCount; $index++) {
        $pair = if ($parsed -is [System.Array]) { $parsed[$index] } else { $parsed }
        $sourceRelative = if ($pair.PSObject.Properties.Name -contains 'source_path') { [string]$pair.source_path } elseif ($pair.PSObject.Properties.Name -contains 'source') { [string]$pair.source } else { '' }
        $rawRelative = if ($pair.PSObject.Properties.Name -contains 'raw_path') { [string]$pair.raw_path } elseif ($pair.PSObject.Properties.Name -contains 'raw') { [string]$pair.raw } else { '' }
        if ([string]::IsNullOrWhiteSpace($sourceRelative) -or [string]::IsNullOrWhiteSpace($rawRelative)) { throw "Pair $index must contain source_path/raw_path or source/raw." }
        $sourceFull = Get-ProjectPath -Path $sourceRelative -MustExist
        $rawFull = Get-ProjectPath -Path $rawRelative -MustExist
        $sourceStats = Get-TextStats -Path $sourceFull -IsRaw $false
        $rawStats = Get-TextStats -Path $rawFull -IsRaw $true
        $ratio = if ($sourceStats.body_lines -eq 0) { $null } else { [Math]::Round((100.0 * $rawStats.body_lines / $sourceStats.body_lines), 1) }
        [void]$results.Add([pscustomobject][ordered]@{
            source_path = $sourceRelative
            raw_path = $rawRelative
            source_body_lines = $sourceStats.body_lines
            raw_body_lines = $rawStats.body_lines
            compression_percent = $ratio
            source_image_lines = $sourceStats.image_lines
            source_embed_lines = $sourceStats.embed_lines
            raw_position_markers = $rawStats.position_markers
        })
    }
    $json = @($results | ForEach-Object { $_ }) | ConvertTo-Json -Depth 10
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputFull = Get-ProjectPath -Path $OutputPath
        $parent = Split-Path -Parent $outputFull
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [IO.File]::WriteAllText($outputFull, ($json.TrimEnd() + "`n"), $utf8NoBom)
    }
    Write-Output $json
} catch {
    [Console]::Error.WriteLine("INGEST_TEXT_INSPECTION_FAILED: $($_.Exception.Message)")
    exit 2
}
