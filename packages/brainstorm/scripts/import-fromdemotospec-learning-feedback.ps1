[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [Parameter(Mandatory = $true)][string]$ArtifactId,
    [Parameter(Mandatory = $true)][string]$F2sFeedbackPath,
    [string]$SessionRoot = ''
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDirectory 'session-common.ps1')

function Get-Sha256Hex {
    param([string]$LiteralPath)
    $stream = [IO.File]::OpenRead($LiteralPath)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
    } finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

$candidateArgs = @('-SessionPath', $SessionPath, '-ArtifactId', $ArtifactId)
if (-not [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $candidateArgs += @('-SessionRoot', $SessionRoot)
}
$candidateResult = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDirectory 'validate-learning-feedback-candidate.ps1') @candidateArgs)
if ($LASTEXITCODE -ne 0) { throw 'Learning candidate validation failed before import.' }
$candidate = ($candidateResult -join "`n") | ConvertFrom-Json
Assert-SessionContract -Condition (Test-Path -LiteralPath $F2sFeedbackPath -PathType Leaf) -Message "Missing F2S feedback: $F2sFeedbackPath"
$feedbackPath = [IO.Path]::GetFullPath($F2sFeedbackPath)
$feedback = [IO.File]::ReadAllText($feedbackPath, $script:BrainstormUtf8NoBom)
foreach ($required in @('> Contract: `f2s-validation-feedback-v1`', '> Status: `ready-for-import`', '> Knowledge write: `false`', '> Upstream Decision ID:')) {
    Assert-SessionContract -Condition ($feedback.Contains($required)) -Message "F2S feedback is missing import requirement: $required"
}
$prototype = [regex]::Match($feedback, '(?m)^> Prototype ID: `([^`]+)`\s*$')
$version = [regex]::Match($feedback, '(?m)^> Prototype version: `([^`]+)`\s*$')
$decision = [regex]::Match($feedback, '(?m)^> Upstream Decision ID: `(DEC-[0-9]{3,})`\s*$')
$impact = [regex]::Match($feedback, '(?m)^> Decision impact: `([^`]+)`\s*$')
Assert-SessionContract -Condition ($prototype.Success -and $version.Success -and $decision.Success -and $impact.Success) -Message 'F2S feedback metadata is incomplete.'
Assert-SessionContract -Condition ($decision.Groups[1].Value -ceq [string]$candidate.decision_id) -Message 'F2S feedback Decision ID does not match the Brainstorm candidate.'
$hash = (Get-Sha256Hex -LiteralPath $feedbackPath).ToLowerInvariant()

$statePath = Resolve-SessionStatePath -SessionPath $SessionPath
$sessionDirectory = Split-Path -Parent $statePath
$state = Read-Utf8Json -Path $statePath
$recordPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$state.record_path)
$record = [IO.File]::ReadAllText($recordPath, $script:BrainstormUtf8NoBom)
$artifactRows = @(Get-MarkdownTableRows -Content $record -Heading 'Artifact Index' -ExpectedHeaders @('Artifact ID', 'Kind', 'Path', 'Source IDs', 'Status', 'Purpose'))
$artifact = @($artifactRows | Where-Object { [string]$_.cells[0] -ceq $ArtifactId })
$artifactPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$artifact[0].cells[2])
$content = [IO.File]::ReadAllText($artifactPath, $script:BrainstormUtf8NoBom)
Assert-SessionContract -Condition (-not $content.Contains($hash)) -Message 'This F2S feedback was already imported.'
$updated = Add-MarkdownTableRow -Content $content -Heading 'Imported F2S Feedback' -Cells @($hash, $prototype.Groups[1].Value, $version.Groups[1].Value, $decision.Groups[1].Value, $impact.Groups[1].Value, 'imported')
Write-Utf8TextAtomic -Path $artifactPath -Value $updated

[pscustomobject][ordered]@{
    imported = $true
    artifact_id = $ArtifactId
    feedback_sha256 = $hash
    knowledge_write = $false
    candidate_status = 'collecting-evidence'
} | ConvertTo-Json -Depth 8
