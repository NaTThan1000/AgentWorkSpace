[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$BriefPath = ''
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'session-common.ps1')
. (Join-Path $scriptRoot 'playbook-common.ps1')
. (Join-Path $scriptRoot 'game-concept-common.ps1')

function Assert-NonEmptyCells {
    param([object[]]$Rows, [int[]]$Indexes, [string]$Section)
    foreach ($row in @($Rows)) {
        foreach ($index in $Indexes) {
            Assert-PlaybookContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$row.cells[$index]) -and [string]$row.cells[$index] -cne '-') -Message "Empty required cell in section: $Section"
        }
    }
}

function Assert-SourceRows {
    param([object[]]$Rows, [int]$SourceIndex, [hashtable]$SourceIds, [string]$Section)
    Assert-PlaybookContract -Condition (@($Rows).Count -ge 1) -Message "Section requires at least one row: $Section"
    foreach ($row in @($Rows)) {
        $references = @(Split-ControlReferences -Value ([string]$row.cells[$SourceIndex]))
        Assert-PlaybookContract -Condition ($references.Count -ge 1) -Message "Section row requires Source IDs: $Section"
        foreach ($reference in $references) {
            Assert-PlaybookContract -Condition ($SourceIds.ContainsKey($reference)) -Message "Unknown brief source reference: $Section->$reference"
        }
    }
}

$statePath = Resolve-SessionStatePath -SessionPath $SessionPath
$sessionDirectory = Split-Path -Parent $statePath
$sessionValidation = Get-SessionValidation -SessionPath $sessionDirectory -SessionRoot $SessionRoot
$state = Read-Utf8Json -Path $statePath
if ([string]::IsNullOrWhiteSpace($BriefPath)) {
    $BriefPath = Join-Path $sessionDirectory 'game-concept-brief.md'
}
$BriefPath = [IO.Path]::GetFullPath($BriefPath)
$sessionPrefix = [IO.Path]::GetFullPath($sessionDirectory).TrimEnd([char]92, [char]47) + [IO.Path]::DirectorySeparatorChar
Assert-PlaybookContract -Condition ($BriefPath.StartsWith($sessionPrefix, [StringComparison]::OrdinalIgnoreCase)) -Message 'BriefPath must stay inside the session directory.'
Assert-PlaybookContract -Condition (Test-Path -LiteralPath $BriefPath -PathType Leaf) -Message "Missing Game Concept brief: $BriefPath"

$recordPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$state.record_path)
$record = [IO.File]::ReadAllText($recordPath, $script:BrainstormPlaybookUtf8NoBom)
$brief = [IO.File]::ReadAllText($BriefPath, $script:BrainstormPlaybookUtf8NoBom)
Assert-PlaybookContract -Condition ($brief.Contains('> Playbook ID: `game-concept`')) -Message 'Brief Playbook ID must be game-concept.'
Assert-PlaybookContract -Condition ($brief.Contains("> Session ID: ``$([string]$state.session_id)``")) -Message 'Brief Session ID does not match the session.'
Assert-PlaybookContract -Condition ($brief.Contains('> Semantic review: `required`')) -Message 'Brief must retain semantic review required.'
Assert-PlaybookContract -Condition ($brief.Contains('> Brief schema: `3`')) -Message 'Active briefs require schema 3.'
$briefSchema = 3
$combinationValidation = Get-GameConceptCombinationValidation -SessionPath $sessionDirectory -SessionRoot $SessionRoot
Assert-PlaybookContract -Condition ([string]$combinationValidation.gate_status -ceq 'selected') -Message 'Game Concept brief requires a selected combination gate.'
$selectedPackageId = [string]$combinationValidation.selected_package_id
Assert-PlaybookContract -Condition ($brief.Contains("> Selected package ID: ``$selectedPackageId``")) -Message 'Brief selected package does not match the combination gate.'

$sourceIds = @{}
$rawRows = @(Get-MarkdownTableRows -Content $record -Heading 'Raw Capture' -ExpectedHeaders @('Raw ID', 'Source', 'Original input', 'Interpretation status'))
foreach ($row in $rawRows) { $sourceIds[[string]$row.cells[0]] = $true }
$ideaHeaders = @('Idea ID', 'Parent IDs', 'Source', 'Method ID', 'Disposition', 'Adoption', 'Idea', 'Destination', 'Supersedes', 'Decision reason')
$ideaRows = @(Get-MarkdownTableRows -Content $record -Heading 'Idea Ledger' -ExpectedHeaders $ideaHeaders)
foreach ($row in $ideaRows) { $sourceIds[[string]$row.cells[0]] = $true }
$decisionIds = @{}
$decisionRows = @(Get-MarkdownTableRows -Content $record -Heading 'Decision Record' -ExpectedHeaders @('Decision ID', 'Candidate IDs', 'Decision', 'Criteria', 'Evidence IDs', 'Decider'))
foreach ($row in $decisionRows) { $decisionIds[[string]$row.cells[0]] = $row }
Assert-PlaybookContract -Condition ($sourceIds.Count -ge 1) -Message 'Game Concept brief requires at least one Raw or Idea source.'

foreach ($heading in @('Concept Frame', 'Experience Fragment', 'Player Fantasy', 'Core Verbs', 'Core Loop', 'Design Pillars', 'Anti-goals', 'Scope', 'Validation and Open Questions', 'Decision and Handoff')) {
    Assert-PlaybookContract -Condition ($brief.Contains('## ' + $heading)) -Message "Missing brief section: $heading"
}
$conceptRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Concept Frame' -ExpectedHeaders @('Concept', 'Target player / context', 'Emotional promise', 'Source IDs'))
$experienceRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Experience Fragment' -ExpectedHeaders @('Situation', 'Player action / choice', 'Visible consequence', 'Source IDs'))
$fantasyRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Player Fantasy' -ExpectedHeaders @('Fantasy', 'Player identity', 'Desired feeling', 'Source IDs'))
$verbRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Core Verbs' -ExpectedHeaders @('Verb', 'Player intent', 'Feedback / consequence', 'Source IDs'))
$loopRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Core Loop' -ExpectedHeaders @('Step ID', 'Player action', 'System response', 'Return / progression', 'Source IDs'))
$pillarRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Design Pillars' -ExpectedHeaders @('Pillar ID', 'Commitment', 'In-scope signal', 'Exclusion signal', 'Source IDs'))
$antiRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Anti-goals' -ExpectedHeaders @('Anti-goal ID', 'Avoid', 'Why', 'Source IDs'))
$scopeRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Scope' -ExpectedHeaders @('Bucket', 'Included / excluded', 'Rationale', 'Source IDs'))
$checkRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Validation and Open Questions' -ExpectedHeaders @('Item ID', 'Type', 'Statement', 'Source IDs', 'Next action'))
$handoffHeaders = @('Brief status', 'Selected package ID', 'Decision IDs', 'F2S intent', 'Missing')
$handoffRows = @(Get-MarkdownTableRows -Content $brief -Heading 'Decision and Handoff' -ExpectedHeaders $handoffHeaders)

foreach ($section in @(
    [pscustomobject]@{ name = 'Concept Frame'; rows = $conceptRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Experience Fragment'; rows = $experienceRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Player Fantasy'; rows = $fantasyRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Core Verbs'; rows = $verbRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Core Loop'; rows = $loopRows; source = 4; required = @(0, 1, 2, 3) },
    [pscustomobject]@{ name = 'Design Pillars'; rows = $pillarRows; source = 4; required = @(0, 1, 2, 3) },
    [pscustomobject]@{ name = 'Anti-goals'; rows = $antiRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Scope'; rows = $scopeRows; source = 3; required = @(0, 1, 2) },
    [pscustomobject]@{ name = 'Validation and Open Questions'; rows = $checkRows; source = 3; required = @(0, 1, 2, 4) }
)) {
    Assert-SourceRows -Rows $section.rows -SourceIndex $section.source -SourceIds $sourceIds -Section $section.name
    Assert-NonEmptyCells -Rows $section.rows -Indexes $section.required -Section $section.name
}

$seenIds = @{}
foreach ($item in @(
    [pscustomobject]@{ rows = $loopRows; pattern = '^LOOP-[0-9]{3,}$'; name = 'Core Loop' },
    [pscustomobject]@{ rows = $pillarRows; pattern = '^PILLAR-[0-9]{3,}$'; name = 'Design Pillars' },
    [pscustomobject]@{ rows = $antiRows; pattern = '^ANTI-[0-9]{3,}$'; name = 'Anti-goals' },
    [pscustomobject]@{ rows = $checkRows; pattern = '^CHECK-[0-9]{3,}$'; name = 'Validation and Open Questions' }
)) {
    foreach ($row in @($item.rows)) {
        $id = [string]$row.cells[0]
        Assert-PlaybookContract -Condition ($id -cmatch $item.pattern) -Message "Invalid row ID in $($item.name): $id"
        Assert-PlaybookContract -Condition (-not $seenIds.ContainsKey($id)) -Message "Duplicate brief row ID: $id"
        $seenIds[$id] = $true
    }
}

$scopeBuckets = @($scopeRows | ForEach-Object { [string]$_.cells[0] })
foreach ($bucket in $scopeBuckets) {
    Assert-PlaybookContract -Condition (@('prototype', 'first-playable', 'later', 'excluded') -ccontains $bucket) -Message "Invalid scope bucket: $bucket"
}
Assert-PlaybookContract -Condition ($scopeBuckets -ccontains 'prototype') -Message 'Scope requires a prototype bucket.'
Assert-PlaybookContract -Condition ($scopeBuckets -ccontains 'excluded') -Message 'Scope requires an excluded bucket.'
foreach ($row in $checkRows) {
    Assert-PlaybookContract -Condition (@('hypothesis', 'risk', 'question', 'test') -ccontains [string]$row.cells[1]) -Message "Invalid validation type: $($row.cells[1])"
}

Assert-PlaybookContract -Condition ($handoffRows.Count -eq 1) -Message 'Decision and Handoff requires exactly one row.'
$briefStatus = [string]$handoffRows[0].cells[0]
$decisionIndex = 2
$f2sIndex = 3
Assert-PlaybookContract -Condition ([string]$handoffRows[0].cells[1] -ceq $selectedPackageId) -Message 'Decision and Handoff package does not match the combination gate.'
$briefDecisionIds = @(Split-ControlReferences -Value ([string]$handoffRows[0].cells[$decisionIndex]))
$f2sIntent = [string]$handoffRows[0].cells[$f2sIndex]
Assert-PlaybookContract -Condition (@('draft', 'accepted', 'return-to-brainstorm') -ccontains $briefStatus) -Message "Invalid brief status: $briefStatus"
Assert-PlaybookContract -Condition (@('not-requested', 'requested') -ccontains $f2sIntent) -Message "Invalid F2S intent: $f2sIntent"
if ($briefStatus -ceq 'accepted') {
    Assert-PlaybookContract -Condition ($briefDecisionIds.Count -ge 1) -Message 'Accepted brief requires a Decision ID.'
}
foreach ($decisionId in $briefDecisionIds) {
    Assert-PlaybookContract -Condition ($decisionIds.ContainsKey($decisionId)) -Message "Unknown brief Decision ID: $decisionId"
    if ($briefStatus -ceq 'accepted') {
        Assert-PlaybookContract -Condition (@('user', 'joint') -ccontains [string]$decisionIds[$decisionId].cells[5]) -Message 'Accepted brief requires user/joint decisions.'
    }
}

[pscustomobject][ordered]@{
    structure_passed = $true
    playbook_id = 'game-concept'
    session_id = [string]$state.session_id
    session_status = [string]$sessionValidation.status
    brief_schema = $briefSchema
    selected_package_id = $selectedPackageId
    brief_status = $briefStatus
    f2s_intent = $f2sIntent
    available_source_id_count = $sourceIds.Count
    semantic_review = 'required'
} | ConvertTo-Json -Depth 16
