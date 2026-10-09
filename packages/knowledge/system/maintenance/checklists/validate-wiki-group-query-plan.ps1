[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [string]$OutputPath = '',
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-ProjectPath([string]$Path, [switch]$MustExist) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $rootPath $Path)) }
    $prefix = $rootPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes Knowledge root: $Path" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Path does not exist: $Path" }
    # Resolve-Path alone does not resolve junction targets. Refuse linked ancestors for plan evidence.
    $cursor = $full
    while ($cursor -and $cursor.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked query path is not allowed: $Path" }
        }
        $cursor = Split-Path -Parent $cursor
    }
    return $full
}

function Get-List($Value, [string]$Name) {
    if ($null -eq $Value) { return @() }
    $items = @()
    foreach ($item in $Value) {
        if ($null -eq $item) { continue }
        if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) { foreach ($nested in $item) { if ($null -ne $nested) { $items += [string]$nested } } }
        else { $items += [string]$item }
    }
    if (@($items | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw "Invalid blank item in $Name." }
    if (@($items | Sort-Object -Unique).Count -ne $items.Count) { throw "Duplicate item in $Name." }
    return $items
}

function Get-FrontmatterList([string]$Text, [string]$Field) {
    $frontmatter = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { return @() }
    $body = $frontmatter.Groups['body'].Value; $name = [regex]::Escape($Field)
    $inline = [regex]::Match($body, '(?m)^' + $name + ':\s*\[(?<items>[^\]]*)\]\s*$')
    if ($inline.Success) { return @($inline.Groups['items'].Value.Split(',') | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' }) }
    return @()
}

try {
    $planFull = Get-ProjectPath $PlanPath -MustExist
    $plan = Get-Content -Raw -Encoding UTF8 -LiteralPath $planFull | ConvertFrom-Json
    if ($plan.schema_version -notin @(1,2)) { throw 'Unsupported query-plan schema_version.' }
    $current = $plan.schema_version -eq 2
    if ($current) {
        if ([string]::IsNullOrWhiteSpace([string]$plan.need.question) -or $plan.need.kind -notin @('fact','understanding','diagnosis','comparison','survey')) { throw 'Current plan requires need.question and need.kind.' }
        foreach ($key in @('knowledge','wiki','raw')) { if ($plan.sources.$key -isnot [bool]) { throw "sources.$key must be a boolean." } }
        foreach ($key in @('wiki','raw')) { if ($plan.budget.$key -isnot [int] -or $plan.budget.$key -lt 0) { throw "budget.$key must be a nonnegative integer." } }
        $level = 'task'
    } else { $level = [string]$plan.level }
    if (-not $current -and $level -notin @('L0', 'L1', 'L2', 'L3')) { throw 'Query plan level must be L0, L1, L2, or L3.' }
    # Named binding keeps an empty JSON array from shifting the field name into $Value.
    $direct = Get-List -Value $plan.direct_wiki -Name 'direct_wiki'
    $related = Get-List -Value $plan.related_page_wiki -Name 'related_page_wiki'
    $evaluated = Get-List -Value $plan.evaluated_groups -Name 'evaluated_groups'
    $order = Get-List -Value $plan.candidate_order -Name 'candidate_order'
    if ([string]::IsNullOrWhiteSpace([string]$plan.stop_reason)) { throw 'Query plan requires a stop_reason.' }

    $groups = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $rootPath 'groups') -Filter '*.md' -File | Where-Object { $_.Name -notin @('README.md', 'group.template.md') })) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $id = [regex]::Match($text, '(?m)^id:\s*(?<value>[^\r\n]+)$').Groups['value'].Value.Trim()
        $status = [regex]::Match($text, '(?m)^status:\s*(?<value>[^\r\n]+)$').Groups['value'].Value.Trim()
        $approval = [regex]::Match($text, '(?m)^approval_status:\s*(?<value>[^\r\n]+)$').Groups['value'].Value.Trim()
        foreach ($term in @($id, ([regex]::Match($text, '(?m)^name:\s*(?<value>[^\r\n]+)$').Groups['value'].Value.Trim())) + (Get-FrontmatterList $text 'aliases')) { if (-not [string]::IsNullOrWhiteSpace($term)) { $groups[$term.ToLowerInvariant()] = [pscustomobject]@{ id = $id; active = ($status -eq 'active' -and $approval -eq 'approved') } } }
    }
    $resolvedGroups = @()
    foreach ($term in $evaluated) {
        $key = $term.ToLowerInvariant()
        if (-not $groups.ContainsKey($key) -or -not $groups[$key].active) { throw "Query plan uses an unknown or inactive Group: $term" }
        $resolvedGroups += $groups[$key].id
    }
    $resolvedGroups = @($resolvedGroups | Sort-Object -Unique)

    $selected = @($plan.selected_via_group | Where-Object { $null -ne $_ }); $skipped = @($plan.skipped_via_group | Where-Object { $null -ne $_ }); $rawExpansion = @($plan.raw_expansion | Where-Object { $null -ne $_ }); $axes = @($plan.coverage_axes | Where-Object { $null -ne $_ })
    foreach ($wikiPath in @($direct) + @($related)) { if ($wikiPath -notmatch '^wiki/.*\.md$' -or $wikiPath -match '(^|/)\.\.(/|$)') { throw 'Selected Wiki must be a wiki/ Markdown source.' }; [void](Get-ProjectPath $wikiPath -MustExist) }
    $selectionPairs = @{}
    foreach ($entry in @($selected) + @($skipped)) {
        if ($null -eq $entry) { throw 'Group selection entries cannot be null.' }
        $groupTerm = [string]$entry.group_id; $wikiPath = [string]$entry.wiki_path
        if ([string]::IsNullOrWhiteSpace($groupTerm) -or [string]::IsNullOrWhiteSpace($wikiPath)) { throw 'Group selection entries require group_id and wiki_path.' }
        if (-not $groups.ContainsKey($groupTerm.ToLowerInvariant()) -or -not $groups[$groupTerm.ToLowerInvariant()].active) { throw "Group selection uses an unknown or inactive Group: $groupTerm" }
        $groupId = $groups[$groupTerm.ToLowerInvariant()].id
        if ($groupId -notin $resolvedGroups) { throw "Group selection was not declared in evaluated_groups: $groupId" }
        if ($wikiPath -notmatch '^wiki/.*\.md$' -or $wikiPath -match '(^|/)\.\.(/|$)') { throw 'Group peer must be a wiki/ Markdown source.' }
        $wikiFull = Get-ProjectPath $wikiPath -MustExist
        $wikiGroups = Get-FrontmatterList (Get-Content -Raw -Encoding UTF8 -LiteralPath $wikiFull) 'groups'
        if ($groupId -notin $wikiGroups) { throw "Group peer is not an active member: $wikiPath -> $groupId" }
        $pair = $groupId + '|' + $wikiPath
        if ($selectionPairs.ContainsKey($pair)) { throw "Duplicate selected/skipped Group peer: $pair" }
        $selectionPairs[$pair] = $true
    }
    $selectedPaths = @($selected | ForEach-Object { [string]$_.wiki_path })
    if (@($selectedPaths | Sort-Object -Unique).Count -ne $selectedPaths.Count) { throw 'A Wiki may be selected via Group only once.' }
    if (@($selectedPaths | Where-Object { $_ -in $direct -or $_ -in $related }).Count -gt 0) { throw 'Group peers already selected as direct or related must not be counted as selected_via_group.' }

    foreach ($entry in $rawExpansion) {
        $rawPath = [string]$entry.raw_path; $via = [string]$entry.via
        if ([string]::IsNullOrWhiteSpace($rawPath) -or $via -notin @('direct', 'related_page', 'group_peer')) { throw 'raw_expansion requires raw_path and via=direct|related_page|group_peer.' }
        if ($rawPath -notmatch '^raw-sources/.*\.md$' -or $rawPath -match '(^|/)\.\.(/|$)') { throw 'Raw expansion must be a raw-sources/ Markdown source.' }
        [void](Get-ProjectPath $rawPath -MustExist)
        if ($current -and [string]::IsNullOrWhiteSpace([string]$entry.reason)) { throw 'Raw expansion requires the critical claim or gap in reason.' }
        if ($level -eq 'L2' -and $via -eq 'group_peer') { throw 'L2 must not expand raw through a Group peer.' }
        if ($level -in @('L0','L1')) { throw "$level must not expand raw." }
    }
    $allSelectedWiki = @()
    foreach ($wikiPath in @($direct; $related; $selectedPaths)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$wikiPath)) { $allSelectedWiki += [string]$wikiPath }
    }
    $allSelectedWiki = @($allSelectedWiki | Sort-Object -Unique)
    $wikiCount = $allSelectedWiki.Count
    $wikiBudget = if ($current) { $plan.budget.wiki } else { @{ L0 = 0; L1 = 6; L2 = 10; L3 = 18 }[$level] }
    $rawBudget = if ($current) { $plan.budget.raw } else { @{ L0 = 0; L1 = 0; L2 = 12; L3 = 30 }[$level] }
    if ($current) {
        if ((-not $plan.sources.knowledge -or -not $plan.sources.wiki) -and ($wikiCount -gt 0 -or $resolvedGroups.Count -gt 0 -or $skipped.Count -gt 0)) { throw 'Knowledge/Wiki source is disabled.' }
        if ((-not $plan.sources.knowledge -or -not $plan.sources.raw) -and $rawExpansion.Count -gt 0) { throw 'Raw source is disabled.' }
        if (@($order | Where-Object { $_ -notin @('direct_wiki','related_page_wiki','group_peer') }).Count -gt 0) { throw 'Unknown candidate_order discovery source.' }
        if (($selected.Count -gt 0 -or $skipped.Count -gt 0) -and ('group_peer' -notin $order -or $axes.Count -eq 0)) { throw 'Group evaluation requires actual candidate_order and coverage_axes.' }
    }
    if ($level -eq 'L0' -and ($wikiCount -gt 0 -or $resolvedGroups.Count -gt 0 -or $selected.Count -gt 0 -or $skipped.Count -gt 0)) { throw 'L0 must not read or evaluate Group/Wiki material.' }
    if ($wikiCount -gt $wikiBudget -or $rawExpansion.Count -gt $rawBudget) { throw "Query budget exceeded: wiki=$wikiCount/$wikiBudget; raw=$($rawExpansion.Count)/$rawBudget" }
    if (($level -in @('L2','L3')) -and ($selected.Count -gt 0 -or $skipped.Count -gt 0) -and (($order -join ',') -ne 'direct_wiki,related_page_wiki,group_peer')) { throw 'L2/L3 Group peers require candidate_order: direct_wiki, related_page_wiki, group_peer.' }

    $receipt = [pscustomobject][ordered]@{ schema_version = $plan.schema_version; kind = 'wiki_group_query_selection_receipt'; level = $level; direct_wiki = @($direct); related_page_wiki = @($related); evaluated_groups = @($resolvedGroups); selected_via_group = @($selected); skipped_via_group = @($skipped); coverage_axes = @($axes); raw_expansion = @($rawExpansion); group_metadata_count = $resolvedGroups.Count; wiki_budget_count = $wikiCount; wiki_budget = $wikiBudget; raw_budget_count = $rawExpansion.Count; raw_budget = $rawBudget; candidate_order = @($order); stop_reason = [string]$plan.stop_reason; status = 'passed'; claim_support = 'not_verified'; source_read = $false }
    if ($current) { $receipt | Add-Member -NotePropertyName need -NotePropertyValue $plan.need; $receipt | Add-Member -NotePropertyName sources -NotePropertyValue $plan.sources }
    $json = $receipt | ConvertTo-Json -Depth 12
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $outputFull = Get-ProjectPath $OutputPath; $parent = Split-Path -Parent $outputFull; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; [IO.File]::WriteAllText($outputFull, ($json + "`n"), $utf8NoBom) }
    Write-Output $json
} catch { [Console]::Error.WriteLine("WIKI_GROUP_QUERY_PLAN_FAILED: $($_.Exception.Message)"); exit 2 }
