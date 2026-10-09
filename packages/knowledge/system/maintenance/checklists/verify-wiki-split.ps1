[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlanPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $root = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes Knowledge root: $Path" }
    return $full
}

function Get-StringArray {
    param($Value, [string]$Label)
    if ($null -eq $Value) { throw "Missing array: $Label" }
    $items = @($Value | ForEach-Object { [string]$_ })
    if ($items.Count -eq 0 -or @($items | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw "Invalid array: $Label" }
    if (@($items | Select-Object -Unique).Count -ne $items.Count) { throw "Duplicate values in $Label" }
    return $items
}

function Get-WikiMeta {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    if (-not $RelativePath.StartsWith('wiki/')) { throw "Wiki path must start with wiki/: $RelativePath" }
    $full = Get-ProjectPath $RelativePath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Wiki not found: $RelativePath" }
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    $frontmatter = [regex]::Match($text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { throw "Missing frontmatter: $RelativePath" }
    $sourcesMatch = [regex]::Match($frontmatter.Groups['body'].Value, '(?ms)^sources:\s*\r?\n(?<items>(?:[ \t]+-\s+.*\r?\n?)+)')
    if (-not $sourcesMatch.Success) { throw "Missing sources list: $RelativePath" }
    $sources = @([regex]::Matches($sourcesMatch.Groups['items'].Value, '(?m)^[ \t]+-\s+(?<path>\S.*)$') | ForEach-Object { $_.Groups['path'].Value.Trim() })
    $domainsMatch = [regex]::Match($frontmatter.Groups['body'].Value, '(?m)^domains:\s*\[(?<items>[^\]]*)\]')
    if (-not $domainsMatch.Success) { throw "Missing domains list: $RelativePath" }
    $domains = @($domainsMatch.Groups['items'].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $groupsMatch = [regex]::Match($frontmatter.Groups['body'].Value, '(?m)^groups:\s*\[(?<items>[^\]]*)\]')
    $groups = @(if ($groupsMatch.Success) { $groupsMatch.Groups['items'].Value.Split(',') | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' } } else { @() })
    $systemMatch = [regex]::Match($frontmatter.Groups['body'].Value, '(?m)^system:\s*["'']?(?<value>[^\r\n"'']+)["'']?\s*$')
    $titleMatch = [regex]::Match($text, '(?m)^#\s+(?<value>.+)$')
    if (-not $titleMatch.Success) { throw "Missing H1 title: $RelativePath" }
    $headings = @([regex]::Matches($text, '(?m)^##\s+(?<value>.+)$') | ForEach-Object { $_.Groups['value'].Value.Trim() })
    return [pscustomobject]@{
        path = $RelativePath; text = $text; title = $titleMatch.Groups['value'].Value.Trim(); sources = $sources; domains = $domains; groups = $groups
        system = $(if ($systemMatch.Success) { $systemMatch.Groups['value'].Value.Trim() } else { $null }); headings = $headings
        lines = [IO.File]::ReadAllLines($full, [Text.Encoding]::UTF8).Count
    }
}

function Test-ExactSet {
    param([string[]]$Actual, [string[]]$Expected)
    return (@($Actual | Where-Object { $Expected -notcontains $_ }).Count -eq 0 -and @($Expected | Where-Object { $Actual -notcontains $_ }).Count -eq 0)
}

function Add-Check {
    param([System.Collections.Generic.List[object]]$Checks, [string]$Id, [bool]$Passed, [string]$Details)
    [void]$Checks.Add([pscustomobject][ordered]@{ id = $Id; passed = $Passed; details = $Details })
}

try {
    $planFull = Get-ProjectPath $PlanPath
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) { throw "Plan not found: $PlanPath" }
    $plan = Get-Content -Raw -Encoding UTF8 -LiteralPath $planFull | ConvertFrom-Json
    if ($plan.schema_version -notin @(1, 2)) { throw 'Unsupported split-plan schema_version.' }
    if ([string]::IsNullOrWhiteSpace($plan.batch_id)) { throw 'Missing split-plan batch_id.' }
    foreach ($side in @('source', 'target')) {
        if ($null -eq $plan.$side) { throw "Missing split-plan $side." }
        foreach ($field in @('path', 'title', 'system')) {
            if ([string]::IsNullOrWhiteSpace([string]$plan.$side.$field)) { throw "Missing split-plan $side.$field." }
        }
    }

    $sourcePlanSources = Get-StringArray $plan.source.sources 'source.sources'
    $targetPlanSources = Get-StringArray $plan.target.sources 'target.sources'
    $sourcePlanDomains = Get-StringArray $plan.source.domains 'source.domains'
    $targetPlanDomains = Get-StringArray $plan.target.domains 'target.domains'
    $movedSections = @($plan.moved_sections)
    if ($movedSections.Count -eq 0) { throw 'split-plan requires moved_sections.' }
    $propagationDomains = Get-StringArray $plan.propagation.domain_files 'propagation.domain_files'
    $quickReferenceTitles = Get-StringArray $plan.propagation.quick_reference_titles 'propagation.quick_reference_titles'
    $statusTitles = Get-StringArray $plan.propagation.status_titles 'propagation.status_titles'

    $source = Get-WikiMeta $plan.source.path
    $target = Get-WikiMeta $plan.target.path
    $checks = New-Object 'System.Collections.Generic.List[object]'
    Add-Check $checks 'plan_paths_distinct' ($source.path -ne $target.path) "$($source.path) -> $($target.path)"
    Add-Check $checks 'page_titles_match_plan' ($source.title -eq $plan.source.title -and $target.title -eq $plan.target.title) "$($source.title) / $($target.title)"
    Add-Check $checks 'systems_match_plan' ($source.system -eq $plan.source.system -and $target.system -eq $plan.target.system -and $source.system -eq $target.system) "$($source.system)"
    Add-Check $checks 'domains_match_plan' (Test-ExactSet $source.domains $sourcePlanDomains -and Test-ExactSet $target.domains $targetPlanDomains) (($source.domains -join ',') + ' / ' + ($target.domains -join ','))
    Add-Check $checks 'sources_match_plan' (Test-ExactSet $source.sources $sourcePlanSources -and Test-ExactSet $target.sources $targetPlanSources) "source=$($source.sources.Count); target=$($target.sources.Count)"
    Add-Check $checks 'sources_disjoint' (@($source.sources | Where-Object { $target.sources -contains $_ }).Count -eq 0) 'No raw source may remain in both split pages.'
    Add-Check $checks 'split_source_floor' ($source.sources.Count -ge 3 -and $target.sources.Count -ge 3) "source=$($source.sources.Count); target=$($target.sources.Count); minimum=3"

    if ($plan.schema_version -eq 2) {
        if ($null -eq $plan.group_adjudication -or $null -eq $plan.group_adjudication.source -or $null -eq $plan.group_adjudication.target) { throw 'split-plan schema v2 requires group_adjudication for source and target.' }
        $groupPass = $true
        $groupProblems = New-Object System.Collections.Generic.List[string]
        foreach ($side in @(@{ name = 'source'; actual = $source.groups }, @{ name = 'target'; actual = $target.groups })) {
            $decision = $plan.group_adjudication.($side.name)
            foreach ($field in @('retained_group_ids', 'removed_group_ids', 'candidate_group_ids')) {
                if ($null -eq $decision.$field) { throw "split-plan group_adjudication.$($side.name).$field is required." }
                $values = @($decision.$field | ForEach-Object { [string]$_ })
                if (@($values | Where-Object { $_ -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' }).Count -gt 0 -or @($values | Sort-Object -Unique).Count -ne $values.Count) { throw "Invalid group IDs in group_adjudication.$($side.name).$field." }
            }
            $retained = @($decision.retained_group_ids | ForEach-Object { [string]$_ })
            $removed = @($decision.removed_group_ids | ForEach-Object { [string]$_ })
            $candidates = @($decision.candidate_group_ids | ForEach-Object { [string]$_ })
            if (-not (Test-ExactSet $side.actual $retained)) { $groupPass = $false; [void]$groupProblems.Add("$($side.name):frontmatter!=retained") }
            if (@($retained | Where-Object { $_ -in $removed -or $_ -in $candidates }).Count -gt 0 -or @($removed | Where-Object { $_ -in $candidates }).Count -gt 0) { $groupPass = $false; [void]$groupProblems.Add("$($side.name):overlapping decisions") }
        }
        Add-Check $checks 'group_adjudication_applied' $groupPass $(if ($groupPass) { 'source and target Groups were explicitly retained, removed, or recorded as Candidates.' } else { $groupProblems -join '; ' })
    } else {
        Add-Check $checks 'group_adjudication_applied' $true 'legacy schema v1 split-plan predates Group adjudication.'
    }

    $sectionPass = $true
    $sectionProblems = New-Object System.Collections.Generic.List[string]
    foreach ($section in $movedSections) {
        $from = [string]$section.source_heading
        $to = [string]$section.target_heading
        if ([string]::IsNullOrWhiteSpace($from) -or [string]::IsNullOrWhiteSpace($to)) { throw 'Each moved_sections entry requires source_heading and target_heading.' }
        if ($source.headings -contains $from -or -not ($target.headings -contains $to)) { $sectionPass = $false; [void]$sectionProblems.Add("$from -> $to") }
    }
    Add-Check $checks 'moved_sections_relocated' $sectionPass $(if ($sectionPass) { "moved=$($movedSections.Count)" } else { $sectionProblems -join '; ' })

    $sourceLink = './' + [IO.Path]::GetFileName($target.path) + '#'
    $targetLink = './' + [IO.Path]::GetFileName($source.path) + '#'
    Add-Check $checks 'reciprocal_links' ($source.text.Contains($sourceLink) -and $target.text.Contains($targetLink)) "$sourceLink / $targetLink"

    $anchorPass = $true
    $anchorDetails = New-Object System.Collections.Generic.List[string]
    foreach ($rewrite in @($plan.propagation.anchor_rewrites)) {
        $path = [string]$rewrite.path; $old = [string]$rewrite.old; $new = [string]$rewrite.new
        if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($old) -or [string]::IsNullOrWhiteSpace($new)) { throw 'Each anchor rewrite requires path, old and new.' }
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath (Get-ProjectPath $path)
        if ($text.Contains($old) -or -not $text.Contains($new)) { $anchorPass = $false; [void]$anchorDetails.Add($path) }
    }
    Add-Check $checks 'anchor_rewrites_applied' $anchorPass $(if ($anchorPass) { "rewrites=$(@($plan.propagation.anchor_rewrites).Count)" } else { $anchorDetails -join ', ' })

    $domainPass = $true
    foreach ($domainPath in $propagationDomains) {
        $domainText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Get-ProjectPath $domainPath)
        if (-not ($domainText.Contains('../' + $source.path) -and $domainText.Contains('../' + $target.path))) { $domainPass = $false }
    }
    Add-Check $checks 'domain_navigation_synced' $domainPass ($propagationDomains -join ', ')

    $indexText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Get-ProjectPath 'system/registry/index.md')
    $quickText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Get-ProjectPath 'system/registry/quick-reference.md')
    $statusText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Get-ProjectPath 'system/registry/KNOWLEDGE_STATUS.md')
    Add-Check $checks 'registry_index_synced' ($indexText.Contains($source.path) -and $indexText.Contains($target.path)) "$($source.path) / $($target.path)"
    Add-Check $checks 'quick_reference_synced' (@($quickReferenceTitles | Where-Object { -not $quickText.Contains($_) }).Count -eq 0) ($quickReferenceTitles -join ', ')
    Add-Check $checks 'capacity_status_synced' (@($statusTitles | Where-Object { -not $statusText.Contains('| `' + $_ + '` |') }).Count -eq 0) ($statusTitles -join ', ')

    $status = if (@($checks | Where-Object { -not $_.passed }).Count -eq 0) { 'passed' } else { 'failed' }
    $receipt = [pscustomobject][ordered]@{
        schema_version = 1; batch_id = $plan.batch_id; status = $status; plan = $PlanPath.Replace('\\','/'); plan_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $planFull).Hash.ToLowerInvariant()
        source = [pscustomobject]@{ path = $source.path; lines = $source.lines; sources = $source.sources.Count }
        target = [pscustomobject]@{ path = $target.path; lines = $target.lines; sources = $target.sources.Count }
        checks = @($checks.ToArray()); generated_at = [DateTime]::UtcNow.ToString('o')
    }
    $json = @(($receipt | ConvertTo-Json -Depth 12) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputFull = Get-ProjectPath $OutputPath
        [IO.File]::WriteAllText($outputFull, ($json + "`n"), $utf8NoBom)
    }
    Write-Output $json
    if ($status -ne 'passed') { exit 2 }
} catch {
    [Console]::Error.WriteLine("WIKI_SPLIT_VERIFY_FAILED: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)")
    exit 3
}
