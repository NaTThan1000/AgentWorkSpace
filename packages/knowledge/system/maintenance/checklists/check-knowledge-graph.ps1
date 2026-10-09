[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$OutputPath,
    [switch]$IncludeHistoricalJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
} else {
    [IO.Path]::GetFullPath($ProjectRoot)
}
$projectPrefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$wikiRoot = Join-Path $projectRoot 'wiki'
$rawRoot = Join-Path $projectRoot 'raw-sources'
$domainRoot = Join-Path $projectRoot 'domains'
$failures = New-Object 'System.Collections.Generic.List[object]'
$warnings = New-Object 'System.Collections.Generic.List[object]'

function Add-Failure {
    param([string]$Code, [string]$Path, [string]$Detail)
    [void]$failures.Add([pscustomobject][ordered]@{ code = $Code; path = $Path; detail = $Detail })
}

function Add-Warning {
    param([string]$Code, [string]$Path, [string]$Detail)
    [void]$warnings.Add([pscustomobject][ordered]@{ code = $Code; path = $Path; detail = $Detail })
}

function Get-RelativeProjectPath {
    param([string]$FullPath)
    $full = [IO.Path]::GetFullPath($FullPath)
    if (-not $full.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes project root: $full" }
    return $full.Substring($projectPrefix.Length).Replace('\', '/')
}

function Get-Frontmatter {
    param([string]$Text)
    $match = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $match.Success) { return $null }
    return $match.Groups['body'].Value
}

function Test-FrontmatterField {
    param([string]$Body, [string]$Field)
    return [regex]::IsMatch($Body, '(?m)^' + [regex]::Escape($Field) + ':')
}

function Get-FrontmatterValues {
    param([string]$Body, [string]$Field)
    if ($null -eq $Body) { return @() }
    $name = [regex]::Escape($Field)
    $inline = [regex]::Match($Body, '(?m)^' + $name + ':\s*\[(?<values>[^\]]*)\]\s*$')
    if ($inline.Success) {
        return @($inline.Groups['values'].Value -split '[,\uFF0C]' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' })
    }
    $block = [regex]::Match($Body, '(?m)^' + $name + ':\s*\r?\n(?<values>(?:[ \t]+-\s+.*\r?\n?)+)')
    if ($block.Success) {
        return @([regex]::Matches($block.Groups['values'].Value, '(?m)^[ \t]+-\s+(?<value>.+?)\s*$') | ForEach-Object { $_.Groups['value'].Value.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' })
    }
    $scalar = [regex]::Match($Body, '(?m)^' + $name + ':\s*(?<value>[^\r\n]*)$')
    if ($scalar.Success -and -not [string]::IsNullOrWhiteSpace($scalar.Groups['value'].Value)) {
        return @($scalar.Groups['value'].Value.Trim().Trim('"', "'"))
    }
    return @()
}

function Get-MarkdownLinks {
    param([string]$Text)
    return @([regex]::Matches($Text, '(?m)\[[^\]]+\]\((?<target><[^>]+>|[^\)]+)\)') | ForEach-Object {
        $_.Groups['target'].Value.Trim().Trim('<', '>')
    })
}

function Get-RawWikiLinks {
    param([string]$Text)
    return @([regex]::Matches($Text, '\[\[raw-sources/(?<name>[^\]|#]+?)(?:\.md)?(?:[|#][^\]]*)?\]\]') | ForEach-Object {
        'raw-sources/' + $_.Groups['name'].Value + '.md'
    })
}

function Get-SourceSectionRawLinks {
    param([string]$Text)
    $sourceHeading = ConvertFrom-Json '"\u6765\u6e90"'
    $section = [regex]::Match($Text, '(?ms)^##\s+' + [regex]::Escape($sourceHeading) + '\s*\r?\n(?<body>.*?)(?=^##\s+|\z)')
    if (-not $section.Success) { return $null }
    $body = $section.Groups['body'].Value
    $links = New-Object 'System.Collections.Generic.List[string]'
    foreach ($raw in @(Get-RawWikiLinks -Text $body)) { [void]$links.Add($raw) }
    foreach ($match in [regex]::Matches($body, '(?m)\[[^\]]+\]\((?<target><[^>]+>|[^\)]+)\)')) {
        $target = [Uri]::UnescapeDataString($match.Groups['target'].Value.Trim('<', '>')).Split('#')[0]
        if ($target -match '(?i)(?:^|/)raw-sources/(?<name>[^/]+\.md)$') {
            [void]$links.Add('raw-sources/' + $Matches['name'])
        }
    }
    return @($links.ToArray() | Sort-Object -Unique)
}

function Resolve-LocalTarget {
    param([string]$SourcePath, [string]$Target)
    $fragment = ''
    $pathPart = $Target
    $hashIndex = $Target.IndexOf('#')
    if ($hashIndex -ge 0) {
        $pathPart = $Target.Substring(0, $hashIndex)
        $fragment = $Target.Substring($hashIndex + 1)
    }
    try {
        $pathPart = [Uri]::UnescapeDataString($pathPart)
        $fragment = [Uri]::UnescapeDataString($fragment)
    } catch {
        return [pscustomobject]@{ error = 'invalid_uri_encoding'; path = $null; fragment = $fragment }
    }
    $full = if ([string]::IsNullOrWhiteSpace($pathPart)) {
        [IO.Path]::GetFullPath($SourcePath)
    } else {
        [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $SourcePath) $pathPart))
    }
    if ($full -ne $projectRoot -and -not $full.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ error = 'target_escapes_project'; path = $full; fragment = $fragment }
    }
    return [pscustomobject]@{ error = $null; path = $full; fragment = $fragment }
}

function Get-HeadingAnchors {
    param([string]$Text)
    $anchors = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in ($Text -split '\r?\n')) {
        $match = [regex]::Match($line, '^#{1,6}\s+(?<heading>.+?)\s*$')
        if (-not $match.Success) { continue }
        $heading = $match.Groups['heading'].Value
        $heading = [regex]::Replace($heading, '\[([^\]]+)\]\([^\)]+\)', '$1')
        $heading = [regex]::Replace($heading, '<[^>]+>', '')
        $heading = $heading.Trim().Trim('#').Trim()
        $heading = [regex]::Replace($heading, '[`*_~]', '')
        $anchor = [regex]::Replace($heading, '\s', '-')
        [void]$anchors.Add($anchor)
    }
    foreach ($match in [regex]::Matches($Text, '(?i)<a\s+(?:name|id)=["''](?<anchor>[^"'']+)["'']')) {
        [void]$anchors.Add($match.Groups['anchor'].Value)
    }
    return ,$anchors
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

try {
    foreach ($requiredRoot in @($wikiRoot, $rawRoot, $domainRoot)) {
        if (-not (Test-Path -LiteralPath $requiredRoot -PathType Container)) { throw "Missing Knowledge directory: $requiredRoot" }
    }

    $wikiFiles = @(Get-ChildItem -LiteralPath $wikiRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    $rawFiles = @(Get-ChildItem -LiteralPath $rawRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    $domainFiles = @(Get-ChildItem -LiteralPath $domainRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    $validDomains = @{}
    foreach ($file in $domainFiles) { $validDomains[$file.BaseName] = $true }
    $rawByRelative = @{}
    foreach ($file in $rawFiles) { $rawByRelative[(Get-RelativeProjectPath $file.FullName)] = $file }
    $wikiByRelative = @{}
    foreach ($file in $wikiFiles) { $wikiByRelative[(Get-RelativeProjectPath $file.FullName)] = $file }

    foreach ($rawFile in $rawFiles) {
        $relative = Get-RelativeProjectPath $rawFile.FullName
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $rawFile.FullName
        $frontmatter = Get-Frontmatter $text
        if ($null -eq $frontmatter) { Add-Failure 'raw_frontmatter_missing' $relative 'YAML frontmatter is required.'; continue }
        foreach ($field in @('source', 'source_url', 'date', 'domains', 'type')) {
            if (-not (Test-FrontmatterField $frontmatter $field)) { Add-Failure 'raw_frontmatter_field_missing' $relative $field }
        }
        foreach ($domain in @(Get-FrontmatterValues $frontmatter 'domains')) {
            if (-not $validDomains.ContainsKey($domain)) { Add-Failure 'raw_unknown_domain' $relative $domain }
        }
    }

    $wikiDomains = @{}
    $wikiSources = @{}
    $rawReferenceCounts = @{}
    foreach ($rawPath in $rawByRelative.Keys) { $rawReferenceCounts[$rawPath] = 0 }
    $anchorCache = @{}
    $wikiLinkCount = 0
    foreach ($wikiFile in $wikiFiles) {
        $relative = Get-RelativeProjectPath $wikiFile.FullName
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $wikiFile.FullName
        $frontmatter = Get-Frontmatter $text
        if ($null -eq $frontmatter) { Add-Failure 'wiki_frontmatter_missing' $relative 'YAML frontmatter is required.'; continue }
        foreach ($field in @('domains', 'sources', 'date', 'type', 'groups')) {
            if (-not (Test-FrontmatterField $frontmatter $field)) { Add-Failure 'wiki_frontmatter_field_missing' $relative $field }
        }
        $domains = @(Get-FrontmatterValues $frontmatter 'domains' | Sort-Object -Unique)
        $sources = @(Get-FrontmatterValues $frontmatter 'sources' | ForEach-Object { $_.Replace('\', '/') } | Sort-Object -Unique)
        $groups = @(Get-FrontmatterValues $frontmatter 'groups')
        $types = @(Get-FrontmatterValues $frontmatter 'type')
        $wikiDomains[$relative] = $domains
        $wikiSources[$relative] = $sources
        if ($domains.Count -eq 0) { Add-Failure 'wiki_domains_empty' $relative 'At least one domain is required.' }
        if ($domains.Count -ge 4) { Add-Warning 'wiki_domains_review' $relative ("domains={0}" -f $domains.Count) }
        foreach ($domain in $domains) {
            if (-not $validDomains.ContainsKey($domain)) { Add-Failure 'wiki_unknown_domain' $relative $domain }
        }
        if ($sources.Count -eq 0) { Add-Failure 'wiki_sources_empty' $relative 'At least one source is required.' }
        if ($types.Count -ne 1 -or $types[0] -notin @('concept', 'entity', 'comparison', 'summary')) { Add-Failure 'wiki_type_invalid' $relative ($types -join ',') }
        foreach ($source in $sources) {
            if (-not $rawByRelative.ContainsKey($source)) { Add-Failure 'wiki_source_missing' $relative $source }
        }
        $sectionSources = Get-SourceSectionRawLinks $text
        if ($null -eq $sectionSources) {
            Add-Failure 'wiki_source_section_missing' $relative 'Missing level-2 source section.'
        } else {
            $frontSet = @($sources | Sort-Object -Unique)
            $sectionSet = @($sectionSources | Sort-Object -Unique)
            if (($frontSet -join "`n") -ne ($sectionSet -join "`n")) {
                Add-Failure 'wiki_source_section_mismatch' $relative ("frontmatter={0}; section={1}" -f ($frontSet -join ','), ($sectionSet -join ','))
            }
            foreach ($source in $sectionSet) {
                if ($rawReferenceCounts.ContainsKey($source)) { $rawReferenceCounts[$source]++ }
            }
        }
        foreach ($rawLink in @(Get-RawWikiLinks $text | Sort-Object -Unique)) {
            if (-not $rawByRelative.ContainsKey($rawLink)) { Add-Failure 'wiki_raw_link_missing' $relative $rawLink }
        }
        $lineCount = @(Get-Content -Encoding UTF8 -LiteralPath $wikiFile.FullName).Count
        if ($lineCount -ge 500) { Add-Warning 'wiki_capacity_must_split' $relative ("lines={0}" -f $lineCount) }
        elseif ($lineCount -ge 300) { Add-Warning 'wiki_capacity_evaluate_split' $relative ("lines={0}" -f $lineCount) }

        foreach ($target in @(Get-MarkdownLinks $text)) {
            if ($target -match '^(?i)(https?|mailto|obsidian):') { continue }
            $resolved = Resolve-LocalTarget -SourcePath $wikiFile.FullName -Target $target
            if ($null -ne $resolved.error) { Add-Failure 'wiki_link_invalid' $relative ("$target::$($resolved.error)"); continue }
            if (-not [string]::IsNullOrWhiteSpace($resolved.path) -and -not (Test-Path -LiteralPath $resolved.path -PathType Leaf)) {
                Add-Failure 'wiki_link_target_missing' $relative $target
                continue
            }
            if ($resolved.path.StartsWith(($wikiRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetExtension($resolved.path) -eq '.md') {
                $wikiLinkCount++
                if ($target -notlike '*#*') { continue }
                if (-not $anchorCache.ContainsKey($resolved.path)) {
                    $targetText = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolved.path
                    $anchorCache[$resolved.path] = Get-HeadingAnchors $targetText
                }
                $fragmentPart = [Uri]::UnescapeDataString($target.Substring($target.IndexOf([char]35) + 1))
                if (-not $anchorCache[$resolved.path].Contains($fragmentPart)) {
                    Add-Failure 'wiki_link_anchor_missing_target' $relative $target
                }
            }
        }
    }

    $domainNavigationHeading = ConvertFrom-Json '"\u76f8\u5173 Wiki \u9875\u9762"'
    $domainWikiLinks = @{}
    foreach ($domainFile in $domainFiles) {
        $relative = Get-RelativeProjectPath $domainFile.FullName
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $domainFile.FullName
        if ($text -match '(?i)raw-sources/') { Add-Failure 'domain_raw_link_forbidden' $relative 'Domain files may only link Wiki pages.' }
        $navigationText = ''
        $navigationMatch = [regex]::Match($text, '(?ms)^## ' + [regex]::Escape($domainNavigationHeading) + '\s*$\r?\n(?<body>.*?)(?=^##\s|\z)')
        if ($navigationMatch.Success) { $navigationText = $navigationMatch.Groups['body'].Value }
        $links = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($target in @(Get-MarkdownLinks $navigationText)) {
            if ($target -match '^(?i)(https?|mailto|obsidian):') { continue }
            $resolved = Resolve-LocalTarget -SourcePath $domainFile.FullName -Target $target
            if ($null -ne $resolved.error) { Add-Failure 'domain_link_invalid' $relative ("$target::$($resolved.error)"); continue }
            if ($resolved.path.StartsWith(($wikiRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetExtension($resolved.path) -eq '.md') {
                if (-not (Test-Path -LiteralPath $resolved.path -PathType Leaf)) { Add-Failure 'domain_wiki_target_missing' $relative $target; continue }
                [void]$links.Add((Get-RelativeProjectPath $resolved.path))
            }
        }
        $domainWikiLinks[$domainFile.BaseName] = $links
    }

    foreach ($wikiPath in $wikiDomains.Keys) {
        foreach ($domain in @($wikiDomains[$wikiPath])) {
            if ($validDomains.ContainsKey($domain) -and -not $domainWikiLinks[$domain].Contains($wikiPath)) {
                Add-Failure 'domain_missing_declared_wiki' ("domains/{0}.md" -f $domain) $wikiPath
            }
        }
    }
    foreach ($domain in $domainWikiLinks.Keys) {
        foreach ($wikiPath in @($domainWikiLinks[$domain])) {
            if ($wikiDomains.ContainsKey($wikiPath) -and $wikiDomains[$wikiPath] -notcontains $domain) {
                Add-Failure 'domain_links_undeclared_wiki' ("domains/{0}.md" -f $domain) $wikiPath
            }
        }
    }

    $rawListPath = Join-Path $projectRoot 'system/registry/raw-list.md'
    if (-not (Test-Path -LiteralPath $rawListPath -PathType Leaf)) {
        Add-Failure 'raw_list_missing' 'system/registry/raw-list.md' 'Registry is required.'
    } else {
        $listed = @{}
        foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $rawListPath) {
            if ($line -notmatch '^\|\s*[^|]+\.md\s*\|') { continue }
            $columns = @($line -split '\|')
            if ($columns.Count -lt 7) { continue }
            $name = $columns[1].Trim()
            $relative = 'raw-sources/' + $name
            $countMatch = [regex]::Match($columns[5].Trim(), '^(?<count>\d+)')
            if (-not $countMatch.Success) { Add-Failure 'raw_list_count_invalid' 'system/registry/raw-list.md' $name; continue }
            $count = [int]$countMatch.Groups['count'].Value
            if ($listed.ContainsKey($relative)) { Add-Failure 'raw_list_duplicate' 'system/registry/raw-list.md' $name } else { $listed[$relative] = $count }
        }
        foreach ($rawPath in $rawByRelative.Keys) {
            if (-not $listed.ContainsKey($rawPath)) { Add-Failure 'raw_list_entry_missing' 'system/registry/raw-list.md' $rawPath; continue }
            if ($listed[$rawPath] -ne $rawReferenceCounts[$rawPath]) {
                Add-Failure 'raw_list_reference_count_drift' 'system/registry/raw-list.md' ("{0}: listed={1} actual={2}" -f $rawPath, $listed[$rawPath], $rawReferenceCounts[$rawPath])
            }
            if ($rawReferenceCounts[$rawPath] -eq 0) { Add-Warning 'raw_orphan' $rawPath 'No Wiki source section references this raw.' }
        }
        foreach ($rawPath in $listed.Keys) {
            if (-not $rawByRelative.ContainsKey($rawPath)) { Add-Failure 'raw_list_stale_entry' 'system/registry/raw-list.md' $rawPath }
        }
    }

    $quickReferencePath = Join-Path $projectRoot 'system/registry/quick-reference.md'
    if (Test-Path -LiteralPath $quickReferencePath -PathType Leaf) {
        $quickText = Get-Content -Raw -Encoding UTF8 -LiteralPath $quickReferencePath
        $quickSection = [regex]::Match($quickText, '(?ms)^## Wiki\s*\r?\n(?<body>.*?)(?=^##\s+|\z)')
        $quickNames = @([regex]::Matches($quickSection.Groups['body'].Value, '(?m)^-\s+(?<name>[^\r\n]+)$') | ForEach-Object { $_.Groups['name'].Value.Trim() })
        $wikiNames = @($wikiFiles | ForEach-Object { $_.BaseName })
        foreach ($name in $wikiNames) { if ($quickNames -notcontains $name) { Add-Failure 'quick_reference_wiki_missing' 'system/registry/quick-reference.md' $name } }
        foreach ($name in $quickNames) { if ($wikiNames -notcontains $name) { Add-Failure 'quick_reference_wiki_stale' 'system/registry/quick-reference.md' $name } }
    } else {
        Add-Failure 'quick_reference_missing' 'system/registry/quick-reference.md' 'Registry is required.'
    }

    $indexPath = Join-Path $projectRoot 'system/registry/index.md'
    if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
        $indexText = Get-Content -Raw -Encoding UTF8 -LiteralPath $indexPath
        $indexPaths = @([regex]::Matches($indexText, '(?m)^-\s+`(?<path>wiki/[^`]+\.md)`\s+') | ForEach-Object { $_.Groups['path'].Value } | Sort-Object -Unique)
        foreach ($wikiPath in $wikiByRelative.Keys) { if ($indexPaths -notcontains $wikiPath) { Add-Failure 'index_wiki_missing' 'system/registry/index.md' $wikiPath } }
        foreach ($wikiPath in $indexPaths) { if (-not $wikiByRelative.ContainsKey($wikiPath)) { Add-Failure 'index_wiki_stale' 'system/registry/index.md' $wikiPath } }
    } else {
        Add-Failure 'index_missing' 'system/registry/index.md' 'Registry is required.'
    }

    $hashGroups = @($wikiFiles | Group-Object { Get-Sha256 $_.FullName } | Where-Object { $_.Count -gt 1 })
    foreach ($group in $hashGroups) { Add-Failure 'wiki_exact_duplicate' 'wiki' (($group.Group | ForEach-Object Name) -join ', ') }

    $jsonCount = 0
    if ($IncludeHistoricalJson) {
        $jsonRoot = Join-Path $projectRoot 'system/maintenance/ingest-runs'
        foreach ($jsonFile in @(Get-ChildItem -LiteralPath $jsonRoot -Filter '*.json' -File -Recurse)) {
            $jsonCount++
            try { [void](Get-Content -Raw -Encoding UTF8 -LiteralPath $jsonFile.FullName | ConvertFrom-Json) }
            catch { Add-Failure 'historical_json_invalid' (Get-RelativeProjectPath $jsonFile.FullName) $_.Exception.Message }
        }
    }

    $receipt = [pscustomobject][ordered]@{
        schema_version = 1
        status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
        summary = [pscustomobject][ordered]@{
            raw = $rawFiles.Count
            wiki = $wikiFiles.Count
            domains = $domainFiles.Count
            source_edges = [int](($rawReferenceCounts.Values | Measure-Object -Sum).Sum)
            wiki_links = $wikiLinkCount
            historical_json = $jsonCount
            failures = $failures.Count
            warnings = $warnings.Count
        }
        failures = @($failures.ToArray())
        warnings = @($warnings.ToArray())
    }
    $json = @(($receipt | ConvertTo-Json -Depth 12) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputFull = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputPath)) }
        if (-not $outputFull.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "OutputPath escapes project root: $outputFull" }
        $outputParent = Split-Path -Parent $outputFull
        if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) { [void](New-Item -ItemType Directory -Path $outputParent -Force) }
        [IO.File]::WriteAllText($outputFull, ($json + "`n"), $utf8NoBom)
    }
    Write-Output $json
    if ($failures.Count -gt 0) { exit 2 }
    exit 0
} catch {
    [Console]::Error.WriteLine("KNOWLEDGE_GRAPH_CHECK_FAILED: $($_.Exception.Message)")
    [Console]::Error.WriteLine("KNOWLEDGE_GRAPH_CHECK_LOCATION: $($_.InvocationInfo.ScriptLineNumber)")
    [Console]::Error.WriteLine("KNOWLEDGE_GRAPH_CHECK_STACK: $($_.ScriptStackTrace)")
    exit 3
}
