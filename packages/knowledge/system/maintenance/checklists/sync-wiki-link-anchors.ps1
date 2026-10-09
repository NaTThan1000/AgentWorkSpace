[CmdletBinding()]
param(
    [ValidateSet('Check', 'Sync')][string]$Mode = 'Check',
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
} else {
    [IO.Path]::GetFullPath($ProjectRoot)
}
$wikiRoot = Join-Path $projectRoot 'wiki'
$wikiPrefix = $wikiRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$repairable = New-Object 'System.Collections.Generic.List[object]'
$unresolved = New-Object 'System.Collections.Generic.List[object]'
$headingCache = @{}
$overridePath = Join-Path $PSScriptRoot 'wiki-related-page-anchor-overrides.json'
$anchorOverrides = @{}

function Normalize-AnchorText {
    param([string]$Value)
    $decoded = [Uri]::UnescapeDataString($Value).ToLowerInvariant()
    return [regex]::Replace($decoded, '[^\p{L}\p{Nd}]', '')
}

function Remove-LeadingSectionNumber {
    param([string]$Value)
    $normalized = Normalize-AnchorText $Value
    return [regex]::Replace($normalized, '^(?:[0-9]+|[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e]+)', '')
}

function Get-HeadingRecords {
    param([string]$Path)
    if ($headingCache.ContainsKey($Path)) { return @($headingCache[$Path]) }
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $Path) {
        $match = [regex]::Match($line, '^#{1,6}\s+(?<heading>.+?)\s*$')
        if (-not $match.Success) { continue }
        $heading = $match.Groups['heading'].Value
        $heading = [regex]::Replace($heading, '\[([^\]]+)\]\([^\)]+\)', '$1')
        $heading = [regex]::Replace($heading, '<[^>]+>', '')
        $heading = [regex]::Replace($heading.Trim().Trim('#').Trim(), '[`*_~]', '')
        $anchor = [regex]::Replace($heading, '\s', '-')
        [void]$records.Add([pscustomobject]@{
            path = $Path
            heading = $heading
            anchor = $anchor
            normalized = Normalize-AnchorText $heading
            stripped = Remove-LeadingSectionNumber $heading
        })
    }
    $headingCache[$Path] = @($records.ToArray())
    return @($headingCache[$Path])
}

function Get-UniqueCandidate {
    param([string]$Fragment, [object[]]$Headings)
    $normalized = Normalize-AnchorText $Fragment
    $stripped = Remove-LeadingSectionNumber $Fragment
    $candidates = @($Headings | Where-Object { $_.normalized -eq $normalized })
    if ($candidates.Count -eq 1) { return [pscustomobject]@{ record = $candidates[0]; rule = 'normalized_exact' } }
    $candidates = @($Headings | Where-Object { $_.stripped -eq $stripped })
    if ($candidates.Count -eq 1) { return [pscustomobject]@{ record = $candidates[0]; rule = 'section_number_agnostic' } }
    $candidates = @($Headings | Where-Object {
        $candidate = [string]$_.stripped
        $maximum = [Math]::Max($candidate.Length, $stripped.Length)
        $minimum = [Math]::Min($candidate.Length, $stripped.Length)
        $maximum -gt 0 -and ($candidate.Contains($stripped) -or $stripped.Contains($candidate)) -and (($minimum / $maximum) -ge 0.7)
    })
    if ($candidates.Count -eq 1) { return [pscustomobject]@{ record = $candidates[0]; rule = 'unique_containment_70' } }
    return $null
}

function Get-UniqueGlobalCandidate {
    param([string]$Fragment, [object[]]$Headings)
    $normalized = Normalize-AnchorText $Fragment
    $stripped = Remove-LeadingSectionNumber $Fragment
    $candidates = @($Headings | Where-Object { $_.normalized -eq $normalized })
    if ($candidates.Count -eq 1) { return [pscustomobject]@{ record = $candidates[0]; rule = 'global_normalized_exact' } }
    $candidates = @($Headings | Where-Object { $_.stripped -eq $stripped })
    if ($candidates.Count -eq 1) { return [pscustomobject]@{ record = $candidates[0]; rule = 'global_section_number_agnostic' } }
    return $null
}

function Get-OverrideKey {
    param([string]$SourceRelative, [string]$TargetRelative)
    return ($SourceRelative + '|' + $TargetRelative).ToLowerInvariant()
}

try {
    if (-not (Test-Path -LiteralPath $wikiRoot -PathType Container)) { throw "Missing Wiki directory: $wikiRoot" }
    if (Test-Path -LiteralPath $overridePath -PathType Leaf) {
        $overrideJson = Get-Content -Raw -Encoding UTF8 -LiteralPath $overridePath
        if ($overrideJson -match '^\s*\[\s*\]\s*$') { $overrides = @() }
        else { $overrides = @($overrideJson | ConvertFrom-Json) }
        foreach ($override in $overrides) {
            if ($null -eq $override) {
                if ($overrideJson -match '^\s*\[\s*\]\s*$') { continue }
                throw 'Invalid related-page anchor override: null record'
            }
            foreach ($field in @('source', 'target', 'heading')) {
                if ([string]::IsNullOrWhiteSpace([string]$override.$field)) { throw "Invalid related-page anchor override: missing $field" }
            }
            $key = Get-OverrideKey -SourceRelative ([string]$override.source) -TargetRelative ([string]$override.target)
            if ($anchorOverrides.ContainsKey($key)) { throw "Duplicate related-page anchor override: $key" }
            $anchorOverrides[$key] = [string]$override.heading
        }
    }
    $linkPattern = '(?m)\[[^\]]+\]\((?<target><[^>]+>|[^\)]+)\)'
    $wikiFiles = @(Get-ChildItem -LiteralPath $wikiRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    $globalHeadings = @(foreach ($candidateFile in $wikiFiles) { Get-HeadingRecords $candidateFile.FullName })
    foreach ($wikiFile in $wikiFiles) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $wikiFile.FullName
        $updated = [regex]::Replace($text, $linkPattern, {
            param($match)
            $rawTarget = $match.Groups['target'].Value.Trim()
            $wrapped = $rawTarget.StartsWith('<') -and $rawTarget.EndsWith('>')
            $target = $rawTarget.Trim('<', '>')
            if ($target -match '^(?i)(https?|mailto|obsidian):') { return $match.Value }
            $hashIndex = $target.IndexOf('#')
            $pathPart = if ($hashIndex -lt 0) { $target } else { $target.Substring(0, $hashIndex) }
            $fragment = if ($hashIndex -lt 0) { $null } else { [Uri]::UnescapeDataString($target.Substring($hashIndex + 1)) }
            $targetPath = if ([string]::IsNullOrWhiteSpace($pathPart)) {
                $wikiFile.FullName
            } else {
                [IO.Path]::GetFullPath((Join-Path $wikiFile.DirectoryName ([Uri]::UnescapeDataString($pathPart))))
            }
            if (-not $targetPath.StartsWith($wikiPrefix, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($targetPath) -ne '.md' -or -not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                return $match.Value
            }
            $headings = @(Get-HeadingRecords $targetPath)
            $sourceRelative = 'wiki/' + $wikiFile.Name
            $targetRelative = 'wiki/' + (Split-Path -Leaf $targetPath)
            $overrideKey = Get-OverrideKey -SourceRelative $sourceRelative -TargetRelative $targetRelative
            $overrideHeading = if ($anchorOverrides.ContainsKey($overrideKey)) { [string]$anchorOverrides[$overrideKey] } else { $null }
            if ([string]::IsNullOrWhiteSpace($fragment) -and [string]::IsNullOrWhiteSpace($overrideHeading)) { return $match.Value }
            if (-not [string]::IsNullOrWhiteSpace($fragment) -and @($headings | Where-Object { $_.anchor -ieq $fragment }).Count -gt 0) { return $match.Value }
            $candidate = $null
            if (-not [string]::IsNullOrWhiteSpace($fragment)) {
                $candidate = Get-UniqueCandidate -Fragment $fragment -Headings $headings
                if ($null -eq $candidate) { $candidate = Get-UniqueGlobalCandidate -Fragment $fragment -Headings $globalHeadings }
            }
            if ($null -eq $candidate -and -not [string]::IsNullOrWhiteSpace($overrideHeading)) {
                $candidate = Get-UniqueCandidate -Fragment $overrideHeading -Headings $headings
                if ($null -ne $candidate) { $candidate = [pscustomobject]@{ record = $candidate.record; rule = 'curated_related_page_heading' } }
            }
            $record = [pscustomobject][ordered]@{
                source = $sourceRelative
                target = $targetRelative
                old_anchor = $fragment
                new_target = if ($null -eq $candidate) { $null } else { 'wiki/' + (Split-Path -Leaf $candidate.record.path) }
                new_anchor = if ($null -eq $candidate) { $null } else { $candidate.record.anchor }
                rule = if ($null -eq $candidate) { $null } else { $candidate.rule }
            }
            if ($null -eq $candidate) {
                [void]$unresolved.Add($record)
                return $match.Value
            }
            [void]$repairable.Add($record)
            if ($Mode -ne 'Sync') { return $match.Value }
            $newPathPart = if ($candidate.record.path -eq $targetPath) { $pathPart } else { './' + (Split-Path -Leaf $candidate.record.path) }
            $newTarget = $newPathPart + '#' + $candidate.record.anchor
            $needsWrapper = $wrapped -or $newPathPart.Contains(' ')
            $newRawTarget = if ($needsWrapper) { '<' + $newTarget + '>' } else { $newTarget }
            $targetOffset = $match.Groups['target'].Index - $match.Index
            return $match.Value.Remove($targetOffset, $match.Groups['target'].Length).Insert($targetOffset, $newRawTarget)
        })
        if ($Mode -eq 'Sync' -and $updated -ne $text) { [IO.File]::WriteAllText($wikiFile.FullName, $updated.Replace("`r`n", "`n"), $utf8NoBom) }
    }
    $result = [pscustomobject][ordered]@{
        schema_version = 1
        status = if ($Mode -eq 'Sync') { 'synced' } elseif ($repairable.Count -eq 0 -and $unresolved.Count -eq 0) { 'passed' } else { 'drifted' }
        mode = $Mode
        repairable_count = $repairable.Count
        unresolved_count = $unresolved.Count
        repairable = @($repairable.ToArray())
        unresolved = @($unresolved.ToArray())
    }
    $result | ConvertTo-Json -Depth 8
    if ($Mode -eq 'Check' -and ($repairable.Count -gt 0 -or $unresolved.Count -gt 0)) { exit 2 }
    exit 0
} catch {
    [Console]::Error.WriteLine("WIKI_ANCHOR_SYNC_FAILED: $($_.Exception.Message)")
    [Console]::Error.WriteLine("WIKI_ANCHOR_SYNC_LOCATION: $($_.InvocationInfo.ScriptLineNumber)")
    exit 3
}
