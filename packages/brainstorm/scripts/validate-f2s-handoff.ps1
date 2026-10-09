[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$GapPath = '',
    [string]$BriefPath = '',
    [string]$HandoffPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'adapter-common.ps1')

$gapResult = Get-F2SGapValidation -SessionPath $SessionPath -SessionRoot $SessionRoot -GapPath $GapPath -BriefPath $BriefPath
Assert-AdapterContract -Condition ([string]$gapResult.gap_status -ceq 'ready') -Message 'F2S handoff validation requires a ready gap.'
$context = $gapResult.context
if ([string]::IsNullOrWhiteSpace($HandoffPath)) { $HandoffPath = Join-Path $context.session_directory 'f2s-handoff.md' }
$HandoffPath = Resolve-AdapterSessionPath -SessionDirectory $context.session_directory -ArtifactPath $HandoffPath
Assert-AdapterContract -Condition (Test-Path -LiteralPath $HandoffPath -PathType Leaf) -Message "Missing F2S handoff: $HandoffPath"
$content = [IO.File]::ReadAllText($HandoffPath, $script:BrainstormAdapterUtf8NoBom)
$f2s = Get-AdapterDefinition -AdapterId 'f2s-handoff'
Assert-AdapterContract -Condition (-not $content.Contains('{{')) -Message 'F2S handoff contains unresolved template tokens.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Adapter ID') -ceq 'f2s-handoff') -Message 'F2S handoff adapter ID is invalid.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Session ID') -ceq [string]$context.state.session_id) -Message 'F2S handoff session ID mismatch.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Handoff status') -ceq 'ready') -Message 'F2S handoff status must be ready.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'External contract') -ceq [string]$f2s.external_contract.path) -Message 'F2S handoff external contract path drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Contract version') -ceq [string]$f2s.external_contract.version) -Message 'F2S handoff contract version drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Last verified against') -ceq [string]$f2s.external_contract.last_verified_against) -Message 'F2S handoff verification revision drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Structural review') -ceq 'passed') -Message 'F2S handoff structural review must be passed.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Semantic review') -ceq 'passed') -Message 'F2S handoff semantic review must be passed.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'External flow started') -ceq 'false') -Message 'F2S handoff must not start the external flow.'

$requiredHeadings = @('## Production definition', '## Optional parameters', '## Provenance')
foreach ($heading in $requiredHeadings) {
    Assert-AdapterContract -Condition ($content.Contains($heading)) -Message "F2S handoff is missing heading: $heading"
}
$parameterHeading = 'Optional parameters'
# Older closed handoffs remain historical evidence; validate the inventory when present.
if ($content.Contains('> Reception inventory:')) {
    Assert-AdapterContract ((Get-MarkdownMetadata -Content $content -Label 'Reception inventory') -ceq '1') 'Unsupported reception inventory.'
    Assert-AdapterContract ((Get-MarkdownMetadata -Content $content -Label 'Decision ledger') -ceq [string]$context.state.record_path) 'Decision ledger path differs from source.'
    $ledgerIds = @(Split-ControlReferences -Value (Get-MarkdownMetadata -Content $content -Label 'Ledger decision IDs'))
    Assert-AdapterContract ((($ledgerIds | Sort-Object) -join ',') -ceq ((@($context.decision_ids.Keys) | Sort-Object) -join ',')) 'Reception inventory must cover the complete decision ledger.'
}
$parameterRows = @(Get-MarkdownTableRows -Content $content -Heading $parameterHeading -ExpectedHeaders @('Parameter ID', 'Name', 'Default', 'Range', 'Source IDs'))
Assert-AdapterContract -Condition ($parameterRows.Count -eq @($gapResult.gap.tunable_parameters).Count) -Message 'Handoff parameter count must match source gap.'
foreach ($field in @($gapResult.gap.fields)) {
        Assert-AdapterContract ($content.Contains('### ' + [string]$field.field_id)) 'V2 handoff field missing'
        $blockMatch = [regex]::Match($content, '(?ms)^### ' + [regex]::Escape([string]$field.field_id) + '\r?\n(.*?)(?=^###? |\z)')
        Assert-AdapterContract ($blockMatch.Success) 'Handoff field block missing'
        $block = $blockMatch.Groups[1].Value
        Assert-AdapterContract ($block.Contains('Coverage: ' + [string]$field.coverage)) 'Handoff coverage differs from gap'
        foreach ($value in @($field.mapped_content) + @($field.next_action, $field.gap_or_question)) {
            $normalized = ([string]$value).Replace("`r", ' ').Replace("`n", ' ').Replace('|', '\|').Trim()
            Assert-AdapterContract ($block.Contains($normalized)) 'Handoff field lost mapped content or next action'
        }
}
foreach ($row in $parameterRows) {
    $sourceIds = @(Split-ControlReferences -Value ([string]$row.cells[4]))
    Assert-AdapterContract -Condition ([string]$row.cells[0] -cmatch '^F2S-PARAM-[0-9]{3,}$') -Message "Invalid handoff parameter ID: $($row.cells[0])"
    Assert-AdapterSourceIds -SourceIds $sourceIds -AllIds $context.all_ids -Label ([string]$row.cells[0])
    $parameter = @($gapResult.gap.tunable_parameters | Where-Object { [string]$_.parameter_id -ceq [string]$row.cells[0] })
    Assert-AdapterContract -Condition ($parameter.Count -eq 1) -Message 'Handoff parameter identity differs from gap.'
    foreach ($pair in @(@(1,'name'), @(2,'default'), @(3,'range'))) {
        $expected = ([string]$parameter[0].($pair[1])).Replace([char]13, ' ').Replace([char]10, ' ').Replace('|', '\|').Trim()
        Assert-AdapterContract -Condition ([string]$row.cells[[int]$pair[0]] -ceq $expected) -Message 'Handoff parameter value differs from gap.'
    }

}
$provenanceRows = @(Get-MarkdownTableRows -Content $content -Heading 'Provenance' -ExpectedHeaders @('Reviewer', 'Decision IDs', 'Brainstorm source IDs'))
Assert-AdapterContract -Condition ($provenanceRows.Count -eq 1) -Message 'F2S handoff requires one Provenance row.'
$provenance = @($provenanceRows[0].cells)
$reviewers = @('agent','user','joint')
Assert-AdapterContract -Condition ($reviewers -ccontains [string]$provenance[0]) -Message 'F2S handoff reviewer is invalid.'
Assert-AdapterContract -Condition ([string]$provenance[0] -ceq [string]$gapResult.gap.reviewer) -Message 'Handoff reviewer differs from reviewed gap.'
$actualDecisions = @(Split-ControlReferences -Value ([string]$provenance[1]))
Assert-AdapterContract -Condition ((($actualDecisions | Sort-Object) -join ',') -ceq ((@($gapResult.gap.decision_ids) | Sort-Object) -join ',')) -Message 'Handoff decisions differ from reviewed gap.'
foreach ($decisionId in $actualDecisions) {
    Assert-AdapterContract -Condition ($context.decision_ids.ContainsKey($decisionId)) -Message "Unknown handoff Decision ID: $decisionId"
}
$handoffSources = @(Split-ControlReferences -Value ([string]$provenance[2]))
Assert-AdapterContract -Condition ($handoffSources.Count -ge 1) -Message 'F2S handoff requires Brainstorm source IDs.'
Assert-AdapterSourceIds -SourceIds $handoffSources -AllIds $context.all_ids -Label 'handoff-provenance'
$expectedSources = @(@($gapResult.gap.fields | ForEach-Object { @($_.source_ids) }) + @($gapResult.gap.tunable_parameters | ForEach-Object { @($_.source_ids) })) | ForEach-Object { $_ } | Sort-Object -Unique
Assert-AdapterContract -Condition ((($handoffSources | Sort-Object -Unique) -join ',') -ceq ($expectedSources -join ',')) -Message 'Handoff provenance differs from reviewed gap.'


[pscustomobject][ordered]@{
    structure_passed = $true
    adapter_id = 'f2s-handoff'
    session_id = [string]$context.state.session_id
    handoff_status = 'ready'
    reception_inventory_checked = $content.Contains('> Reception inventory:')
    tunable_parameter_count = $parameterRows.Count
    external_flow_started = $false
    semantic_review = 'passed'
} | ConvertTo-Json -Depth 16
