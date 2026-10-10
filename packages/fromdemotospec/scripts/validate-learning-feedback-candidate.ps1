[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FeedbackPath)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $FeedbackPath -PathType Leaf)) { throw "Feedback file does not exist: $FeedbackPath" }
$content = [IO.File]::ReadAllText($FeedbackPath, (New-Object Text.UTF8Encoding($false)))
foreach ($required in @('> Contract: `fromdemotospec-validation-feedback-v1`', '> Prototype ID:', '> Prototype version:', '> Upstream Brainstorm session:', '> Upstream Decision ID:', '> Decision impact:', '> Knowledge write: `false`', '## Validation Evidence', '## Decision Impact', '## Candidate Learning', '## Import Gate', '## Boundary')) {
    if (-not $content.Contains($required)) { throw "Learning feedback is missing: $required" }
}
$status = [regex]::Match($content, '(?m)^> Status: `([^`]+)`\s*$')
if (-not $status.Success -or @('draft', 'ready-for-import', 'imported', 'rejected') -notcontains $status.Groups[1].Value) { throw 'Invalid feedback status.' }
$session = [regex]::Match($content, '(?m)^> Upstream Brainstorm session: `(bs-[0-9]{8}-[0-9]{6}-[a-f0-9]{6})`\s*$')
$decision = [regex]::Match($content, '(?m)^> Upstream Decision ID: `(DEC-[0-9]{3,})`\s*$')
if (-not $session.Success -or -not $decision.Success) { throw 'Invalid upstream reference.' }
$knowledgeLines = [regex]::Matches($content, '(?m)^> Knowledge write:.*$')
if ($knowledgeLines.Count -ne 1 -or $knowledgeLines[0].Value.Trim() -cne '> Knowledge write: `false`') { throw 'Knowledge write declaration must occur once and remain false.' }

[pscustomobject][ordered]@{ structure_passed = $true; status = $status.Groups[1].Value; upstream_session = $session.Groups[1].Value; decision_id = $decision.Groups[1].Value; knowledge_write = $false } | ConvertTo-Json -Depth 8
