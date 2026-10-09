[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProposalPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$proposalFullPath = [IO.Path]::GetFullPath((Join-Path $rootPath $ProposalPath))
$outputFullPath = [IO.Path]::GetFullPath((Join-Path $rootPath $OutputPath))

function Get-FrontmatterBody([string]$Text) { $match = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---'); if ($match.Success) { return $match.Groups['body'].Value }; return $null }
function Get-FrontmatterScalar([string]$Body, [string]$Field) { if ($null -eq $Body) { return '' }; $match = [regex]::Match($Body, '(?m)^' + [regex]::Escape($Field) + ':\s*(?<value>[^\r\n#]+?)\s*$'); if ($match.Success) { return $match.Groups['value'].Value.Trim().Trim('"', "'") }; return '' }
function Get-FrontmatterList([string]$Body, [string]$Field) { if ($null -eq $Body) { return @() }; $name = [regex]::Escape($Field); $inline = [regex]::Match($Body, '(?m)^' + $name + ':\s*\[(?<items>[^\]]*)\]\s*$'); if ($inline.Success) { return @($inline.Groups['items'].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' }) }; $block = [regex]::Match($Body, '(?m)^' + $name + ':\s*\r?\n(?<items>(?:[ \t]+-\s+.*\r?\n?)+)'); if ($block.Success) { return @([regex]::Matches($block.Groups['items'].Value, '(?m)^[ \t]+-\s+(?<item>.+?)\s*$') | ForEach-Object { $_.Groups['item'].Value.Trim().Trim('"', "'") } | Where-Object { $_ -ne '' }) }; return @() }
function Get-Sha256([string]$Text) { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); return (([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
function Convert-UnicodeLiteral([string]$Value) { return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', { param($match) [char][Convert]::ToInt32($match.Groups[1].Value, 16) }) }
function Get-RelatedPageText([string]$Text, [string]$Heading) { $match = [regex]::Match($Text, '(?ms)^##[ \t]+' + [regex]::Escape($Heading) + '[ \t]*\r?\n(?<body>.*?)(?=^##[ \t]+|\z)'); if ($match.Success) { return $match.Groups['body'].Value }; return '' }

try {
    if (-not (Test-Path -LiteralPath $proposalFullPath -PathType Leaf)) { throw "Proposal does not exist: $ProposalPath" }
    $proposalText = Get-Content -Raw -Encoding UTF8 -LiteralPath $proposalFullPath
    $body = Get-FrontmatterBody $proposalText
    if ($null -eq $body) { throw 'Proposal frontmatter is required.' }
    $id = Get-FrontmatterScalar $body 'id'
    $approval = Get-FrontmatterScalar $body 'approval'
    $signals = @(Get-FrontmatterList $body 'discovery_signals')
    $exclusions = @(Get-FrontmatterList $body 'exclusion_signals')
    $queryCases = @(Get-FrontmatterList $body 'query_use_cases')
    if ($id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw "Proposal id is invalid: $id" }
    if ($approval -notin @('pending', 'approved', 'rejected')) { throw "Proposal approval is invalid: $approval" }
    if ($signals.Count -eq 0 -or $queryCases.Count -eq 0) { throw 'Proposal requires discovery_signals and query_use_cases.' }
    $wikiRoot = Join-Path $rootPath 'wiki'
    $indexPath = Join-Path $rootPath 'system/registry/index.md'
    $indexText = if (Test-Path -LiteralPath $indexPath -PathType Leaf) { Get-Content -Raw -Encoding UTF8 -LiteralPath $indexPath } else { '' }
    $relatedPageHeading = Convert-UnicodeLiteral '\u76F8\u5173\u9875\u9762'
    $shortlisted = New-Object 'System.Collections.Generic.List[object]'
    $files = @(Get-ChildItem -LiteralPath $wikiRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    foreach ($file in $files) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $frontmatter = Get-FrontmatterBody $text
        $domains = Get-FrontmatterScalar $frontmatter 'domains'
        $legacyThemes = @(Get-FrontmatterList $frontmatter 'related_themes')
        $headings = (@([regex]::Matches($text, '(?m)^#{1,3}\s+(.+?)\s*$')) | ForEach-Object { $_.Groups[1].Value }) -join ' '
        $relatedPageText = Get-RelatedPageText $text $relatedPageHeading
        $indexMatches = @([regex]::Matches($indexText, '(?m)^-[ \t]+`?' + [regex]::Escape('wiki/' + $file.Name) + '`?[ \t]+.*$') | ForEach-Object { $_.Value }) -join ' '
        $surfaces = [ordered]@{ title = $file.BaseName; domains = $domains; legacy_themes = ($legacyThemes -join ' '); headings = $headings; related_page_descriptions = $relatedPageText; registry_index = $indexMatches }
        $signalLocations = New-Object 'System.Collections.Generic.List[object]'
        $blockedLocations = New-Object 'System.Collections.Generic.List[object]'
        foreach ($surfaceName in $surfaces.Keys) {
            $surfaceText = [string]$surfaces[$surfaceName]
            foreach ($signal in $signals) { if (-not [string]::IsNullOrWhiteSpace($signal) -and $surfaceText.IndexOf($signal, [StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$signalLocations.Add([pscustomobject][ordered]@{ signal = $signal; surface = $surfaceName }) } }
            foreach ($signal in $exclusions) { if (-not [string]::IsNullOrWhiteSpace($signal) -and $surfaceText.IndexOf($signal, [StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$blockedLocations.Add([pscustomobject][ordered]@{ signal = $signal; surface = $surfaceName }) } }
        }
        $hits = @($signalLocations.ToArray() | ForEach-Object { $_.signal } | Sort-Object -Unique)
        $blocked = @($blockedLocations.ToArray() | ForEach-Object { $_.signal } | Sort-Object -Unique)
        if ($hits.Count -gt 0 -and $blocked.Count -eq 0) { [void]$shortlisted.Add([pscustomobject][ordered]@{ path = 'wiki/' + $file.Name; title = $file.BaseName; discovery_signals = @($hits); signal_locations = @($signalLocations.ToArray()); exclusion_signals = @(); decision = 'unresolved'; required_action = 'Read the complete Wiki and adjudicate include, exclude, or unresolved.' }) }
    }
    $revision = (& git -c ("safe.directory=" + $rootPath) -C $rootPath rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve repository revision.' }
    $definitionHash = Get-Sha256 ($body + "`n" + $proposalText.Substring($proposalText.IndexOf('---', 3) + 3))
    $shortlistArray = @($shortlisted.ToArray())
    $receipt = [pscustomobject][ordered]@{
        schema_version = 1
        kind = 'wiki_group_discovery_receipt'
        group_id = $id
        proposal_path = $ProposalPath.Replace('\\', '/')
        proposal_approval = $approval
        repository_revision = $revision
        definition_hash = $definitionHash
        screened_scope = [pscustomobject][ordered]@{ wiki_count = $files.Count; metadata_and_headings = $files.Count; related_page_descriptions = $files.Count; registry_index = if ([string]::IsNullOrWhiteSpace($indexText)) { 0 } else { 1 }; full_text_reviewed = 0 }
        discovery_signals = @($signals)
        exclusion_signals = @($exclusions)
        shortlisted = $shortlistArray
        decisions = @()
        review_when = @('Complete full-text adjudication for every shortlist item.', 'Rerun when proposal definition, signals, or repository revision changes.')
    }
    $parent = Split-Path -Parent $outputFullPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($outputFullPath, (($receipt | ConvertTo-Json -Depth 8) + "`n"), (New-Object Text.UTF8Encoding($false)))
    Write-Output (($receipt | Select-Object group_id, repository_revision, definition_hash, screened_scope, @{ n = 'shortlisted_count'; e = { @($_.shortlisted).Count } }) | ConvertTo-Json -Depth 5)
} catch { [Console]::Error.WriteLine("WIKI_GROUP_PREPARE_FAILED: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)"); exit 2 }
