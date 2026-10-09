[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$ContextBriefPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'adapter-common.ps1')

$context = Get-SessionAdapterContext -SessionPath $SessionPath -SessionRoot $SessionRoot
if ([string]::IsNullOrWhiteSpace($ContextBriefPath)) { $ContextBriefPath = Join-Path $context.session_directory 'knowledge-context-brief.md' }
$ContextBriefPath = Resolve-AdapterSessionPath -SessionDirectory $context.session_directory -ArtifactPath $ContextBriefPath
Assert-AdapterContract -Condition (Test-Path -LiteralPath $ContextBriefPath -PathType Leaf) -Message "Missing ContextBrief: $ContextBriefPath"
$content = [IO.File]::ReadAllText($ContextBriefPath, $script:BrainstormAdapterUtf8NoBom)
$knowledge = Get-AdapterDefinition -AdapterId 'knowledge-context-brief'

Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Adapter ID') -ceq 'knowledge-context-brief') -Message 'ContextBrief adapter ID is invalid.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Session ID') -ceq [string]$context.state.session_id) -Message 'ContextBrief session ID mismatch.'
$queryIntent = Get-MarkdownMetadata -Content $content -Label 'Query intent'
Assert-AdapterContract -Condition (@('query', 'deep-query') -ccontains $queryIntent) -Message "Invalid ContextBrief query intent: $queryIntent"
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'External contract') -ceq [string]$knowledge.external_contract.path) -Message 'ContextBrief external contract path drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Contract version') -ceq [string]$knowledge.external_contract.version) -Message 'ContextBrief contract version drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Last verified against') -ceq [string]$knowledge.external_contract.last_verified_against) -Message 'ContextBrief verification revision drifted.'
Assert-AdapterContract -Condition ((Get-MarkdownMetadata -Content $content -Label 'Semantic review') -ceq 'required') -Message 'ContextBrief must retain semantic_review=required.'

$expectedFields = @(
    'task', 'target_experience', 'target_player', 'current_loop_or_system', 'project_stage',
    'constraints', 'observed_symptoms', 'locked_decisions', 'available_evidence'
)
$rows = @(Get-MarkdownTableRows -Content $content -Heading 'Context Fields' -ExpectedHeaders @('Field', 'Value', 'Source IDs'))
Assert-AdapterContract -Condition ($rows.Count -eq $expectedFields.Count) -Message 'ContextBrief must contain exactly nine fields.'
for ($index = 0; $index -lt $expectedFields.Count; $index++) {
    $cells = @($rows[$index].cells)
    $field = [string]$cells[0]
    $value = [string]$cells[1]
    $sourceIds = @(Split-ControlReferences -Value ([string]$cells[2]))
    Assert-AdapterContract -Condition ($field -ceq $expectedFields[$index]) -Message "ContextBrief field order drifted: $field"
    if ($field -ceq 'task') {
        Assert-AdapterContract -Condition (-not [string]::IsNullOrWhiteSpace($value) -and $value -cne '-') -Message 'ContextBrief task is required.'
    }
    if ($value -ceq '-') {
        Assert-AdapterContract -Condition ($sourceIds.Count -eq 0) -Message "Unknown ContextBrief field must not invent sources: $field"
    } else {
        Assert-AdapterContract -Condition ($sourceIds.Count -ge 1) -Message "Filled ContextBrief field requires source IDs: $field"
        Assert-AdapterSourceIds -SourceIds $sourceIds -AllIds $context.all_ids -Label $field
    }
}

$resultRows = @(Get-MarkdownTableRows -Content $content -Heading 'Result Link' -ExpectedHeaders @('Knowledge availability', 'Query result', 'Evidence IDs', 'Notes'))
Assert-AdapterContract -Condition ($resultRows.Count -eq 1) -Message 'ContextBrief requires exactly one Result Link row.'
$result = @($resultRows[0].cells)
$availability = [string]$result[0]
$queryResult = [string]$result[1]
$evidenceIds = @(Split-ControlReferences -Value ([string]$result[2]))
$notes = [string]$result[3]
Assert-AdapterContract -Condition (@('available', 'unavailable') -ccontains $availability) -Message "Invalid Knowledge availability: $availability"
Assert-AdapterContract -Condition (@('pending', 'completed', 'unavailable') -ccontains $queryResult) -Message "Invalid Knowledge query result: $queryResult"
if ($availability -ceq 'unavailable') {
    Assert-AdapterContract -Condition ($queryResult -ceq 'unavailable' -and $evidenceIds.Count -eq 0) -Message 'Unavailable Knowledge must not claim query evidence.'
    Assert-AdapterContract -Condition (-not [string]::IsNullOrWhiteSpace($notes) -and $notes -cne '-') -Message 'Unavailable Knowledge requires a degradation note.'
} else {
    Assert-AdapterContract -Condition ($queryResult -cne 'unavailable') -Message 'Available Knowledge cannot use unavailable result.'
}
if ($queryResult -ceq 'pending') {
    Assert-AdapterContract -Condition ($evidenceIds.Count -eq 0) -Message 'Pending Knowledge query must not claim Evidence IDs.'
}
if ($queryResult -ceq 'completed') {
    Assert-AdapterContract -Condition (-not [string]::IsNullOrWhiteSpace($notes) -and $notes -cne '-') -Message 'Completed Query must describe actual scope and source limitations.'
    Assert-AdapterContract -Condition ($evidenceIds.Count -ge 1) -Message 'Completed Knowledge query requires Evidence IDs.'
    foreach ($evidenceId in $evidenceIds) {
        Assert-AdapterContract -Condition ($context.evidence_ids.ContainsKey($evidenceId)) -Message "Unknown Knowledge Evidence ID: $evidenceId"
        Assert-AdapterContract -Condition ([string]$context.evidence_ids[$evidenceId].cells[1] -ceq 'knowledge') -Message "ContextBrief result must link Knowledge evidence: $evidenceId"
    }
}

[pscustomobject][ordered]@{
    structure_passed = $true
    adapter_id = 'knowledge-context-brief'
    session_id = [string]$context.state.session_id
    query_intent = $queryIntent
    knowledge_availability = $availability
    query_result = $queryResult
    evidence_count = $evidenceIds.Count
    launches_external_flow = $false
    semantic_review = 'required'
} | ConvertTo-Json -Depth 16
