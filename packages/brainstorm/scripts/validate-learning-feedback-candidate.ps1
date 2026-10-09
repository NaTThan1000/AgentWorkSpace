[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [Parameter(Mandatory = $true)][string]$ArtifactId,
    [string]$SessionRoot = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'session-common.ps1')
$statePath = Resolve-SessionStatePath -SessionPath $SessionPath
$sessionDirectory = Split-Path -Parent $statePath
[void](Get-SessionValidation -SessionPath $sessionDirectory -SessionRoot $SessionRoot)
$state = Read-Utf8Json -Path $statePath
$recordPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$state.record_path)
$record = [IO.File]::ReadAllText($recordPath, $script:BrainstormUtf8NoBom)
$artifactRows = @(Get-MarkdownTableRows -Content $record -Heading 'Artifact Index' -ExpectedHeaders @('Artifact ID', 'Kind', 'Path', 'Source IDs', 'Status', 'Purpose'))
$artifact = @($artifactRows | Where-Object { [string]$_.cells[0] -ceq $ArtifactId })
Assert-SessionContract -Condition ($artifact.Count -eq 1) -Message "Unknown ArtifactId: $ArtifactId"
Assert-SessionContract -Condition ([string]$artifact[0].cells[1] -ceq 'learning-feedback') -Message "Artifact is not a learning-feedback candidate: $ArtifactId"
$artifactPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$artifact[0].cells[2])
$content = [IO.File]::ReadAllText($artifactPath, $script:BrainstormUtf8NoBom)
foreach ($required in @('> Contract: `brainstorm-learning-feedback-v1`', '> Candidate status:', '> Knowledge write: `false`', '## Project Decision', '## Imported F2S Feedback', '## Candidate Assessment', '## Human Review Gate', '## Boundary')) {
    Assert-SessionContract -Condition ($content.Contains($required)) -Message "Learning candidate is missing: $required"
}
$decisionMatch = [regex]::Match($content, '(?m)^> Decision ID: `(DEC-[0-9]{3,})`\s*$')
Assert-SessionContract -Condition ($decisionMatch.Success) -Message 'Learning candidate has no valid Decision ID.'
$decisionRows = @(Get-MarkdownTableRows -Content $record -Heading 'Decision Record' -ExpectedHeaders @('Decision ID', 'Candidate IDs', 'Decision', 'Criteria', 'Evidence IDs', 'Decider'))
$decision = @($decisionRows | Where-Object { [string]$_.cells[0] -ceq $decisionMatch.Groups[1].Value })
Assert-SessionContract -Condition ($decision.Count -eq 1 -and @('user', 'joint') -ccontains [string]$decision[0].cells[5]) -Message 'Learning candidate Decision must remain user or joint.'
$statusMatch = [regex]::Match($content, '(?m)^> Candidate status: `([^`]+)`\s*$')
Assert-SessionContract -Condition ($statusMatch.Success -and @('collecting-evidence', 'review-required', 'accepted-for-host', 'rejected') -ccontains $statusMatch.Groups[1].Value) -Message 'Invalid learning candidate status.'
[pscustomobject][ordered]@{
    structure_passed = $true
    artifact_id = $ArtifactId
    decision_id = $decisionMatch.Groups[1].Value
    candidate_status = $statusMatch.Groups[1].Value
    knowledge_write = $false
    review_required = $true
} | ConvertTo-Json -Depth 8
