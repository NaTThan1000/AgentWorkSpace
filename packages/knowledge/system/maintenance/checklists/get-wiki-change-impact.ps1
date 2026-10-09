[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseRevision,
    [string]$TargetRevision = 'HEAD',
    [switch]$Staged
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$safeProject = $projectRoot.Replace('\', '/')

function Get-Values {
    param([string]$Text, [string]$Field)
    $frontmatter = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { return @() }
    $body = $frontmatter.Groups['body'].Value
    $name = [regex]::Escape($Field)
    $inline = [regex]::Match($body, '(?m)^' + $name + ':\s*\[(?<items>[^\]]*)\]\s*$')
    if ($inline.Success) { return @($inline.Groups['items'].Value -split '[,\uFF0C]' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' } | Sort-Object -Unique) }
    $block = [regex]::Match($body, '(?m)^' + $name + ':\s*\r?\n(?<items>(?:[ \t]+-\s+.*\r?\n?)+)')
    if ($block.Success) { return @([regex]::Matches($block.Groups['items'].Value, '(?m)^[ \t]+-\s+(?<item>.+?)\s*$') | ForEach-Object { $_.Groups['item'].Value.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' } | Sort-Object -Unique) }
    return @()
}

function Get-H2 {
    param([string]$Text)
    return @([regex]::Matches($Text, '(?m)^##\s+(?<heading>.+?)\s*$') | ForEach-Object { $_.Groups['heading'].Value.Trim() } | Where-Object { $_ -notin @('来源', '相关页面', '阅读路线') })
}

try {
    $changed = if ($Staged) {
        @(& git -c "safe.directory=$safeProject" -C $projectRoot diff --cached --name-only $BaseRevision -- 'wiki/')
    } else {
        @(& git -c "safe.directory=$safeProject" -C $projectRoot diff --name-only $BaseRevision $TargetRevision -- 'wiki/')
    }
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read changed Wiki paths.' }
    $impacts = New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in @($changed | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ -match '^wiki/.+\.md$' -and $_ -ne 'wiki/README.md' })) {
        $currentPath = Join-Path $projectRoot $path
        if (-not (Test-Path -LiteralPath $currentPath -PathType Leaf)) { continue }
        $before = @(& git -c "safe.directory=$safeProject" -C $projectRoot show "$BaseRevision`:$path") -join "`n"
        if ($LASTEXITCODE -ne 0) { $before = '' }
        $after = Get-Content -Raw -Encoding UTF8 -LiteralPath $currentPath
        $reasons = New-Object 'System.Collections.Generic.List[string]'
        $beforeTitle = [regex]::Match($before, '(?m)^#\s+(?<title>.+?)\s*$').Groups['title'].Value.Trim()
        $afterTitle = [regex]::Match($after, '(?m)^#\s+(?<title>.+?)\s*$').Groups['title'].Value.Trim()
        if ($beforeTitle -ne $afterTitle) { [void]$reasons.Add('title_changed') }
        if ((Get-H2 $before -join "`n") -ne (Get-H2 $after -join "`n")) { [void]$reasons.Add('core_headings_changed') }
        foreach ($field in @('sources', 'domains', 'groups')) { if ((Get-Values $before $field -join "`n") -ne (Get-Values $after $field -join "`n")) { [void]$reasons.Add("$field`_changed") } }
        if ($reasons.Count -gt 0) { [void]$impacts.Add([pscustomobject][ordered]@{ path = $path; related_pages_review_required = $true; reasons = @($reasons.ToArray()) }) }
    }
    [pscustomobject][ordered]@{ schema_version = 1; status = 'reported'; impacts = @($impacts.ToArray()) } | ConvertTo-Json -Depth 8
    exit 0
} catch {
    [Console]::Error.WriteLine("WIKI_CHANGE_IMPACT_FAILED: $($_.Exception.Message)")
    exit 3
}
