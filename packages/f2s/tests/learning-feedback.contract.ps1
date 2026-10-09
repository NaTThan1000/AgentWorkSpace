[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('f2s-feedback-' + [guid]::NewGuid().ToString('N'))))
function Invoke-Tool {
    param([string]$Script, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $Script) @Arguments 2>&1) } finally { $ErrorActionPreference = $previous }
    return @{ code = $LASTEXITCODE; output = ($output -join "`n") }
}
try {
    [IO.Directory]::CreateDirectory($fixture) | Out-Null
    $argsList = @('-ProjectPath', $fixture, '-PrototypeId', 'fixture', '-PrototypeVersion', 'v1', '-UpstreamSession', 'bs-20260815-120000-a1b2c3', '-DecisionId', 'DEC-001')
    $create = Invoke-Tool -Script 'scripts/new-learning-feedback-candidate.ps1' -Arguments $argsList
    if ($create.code -ne 0) { throw $create.output }
    $result = $create.output | ConvertFrom-Json
    if ($result.knowledge_write -ne $false -or $result.status -ne 'draft') { throw 'Candidate must remain local draft' }
    $before = [IO.File]::ReadAllText($result.feedback_path)
    $validate = Invoke-Tool -Script 'scripts/validate-learning-feedback-candidate.ps1' -Arguments @('-FeedbackPath', $result.feedback_path)
    if ($validate.code -ne 0) { throw $validate.output }
    $again = Invoke-Tool -Script 'scripts/new-learning-feedback-candidate.ps1' -Arguments $argsList
    if ($again.code -eq 0 -or [IO.File]::ReadAllText($result.feedback_path) -cne $before) { throw 'Candidate overwrite protection failed' }
    [IO.File]::WriteAllText($result.feedback_path, $before + "`n> Knowledge write: " + [char]96 + 'true' + [char]96)
    $bad = Invoke-Tool -Script 'scripts/validate-learning-feedback-candidate.ps1' -Arguments @('-FeedbackPath', $result.feedback_path)
    if ($bad.code -eq 0) { throw 'Contradictory Knowledge declaration must fail' }
    [IO.File]::WriteAllText($result.feedback_path, $before.Replace('DEC-001', 'INVALID'))
    $badReference = Invoke-Tool -Script 'scripts/validate-learning-feedback-candidate.ps1' -Arguments @('-FeedbackPath', $result.feedback_path)
    if ($badReference.code -eq 0) { throw 'Bad upstream reference must fail' }
    $legacyRoot = Join-Path $fixture 'legacy'
    [IO.Directory]::CreateDirectory((Join-Path $legacyRoot 'legacy-demo')) | Out-Null
    $legacy = Invoke-Tool -Script 'scripts/new-learning-feedback-candidate.ps1' -Arguments @('-DemoRoot', $legacyRoot, '-PrototypeId', 'legacy-demo', '-PrototypeVersion', 'v1', '-UpstreamSession', 'bs-20260815-120000-a1b2c3', '-DecisionId', 'DEC-001')
    if ($legacy.code -ne 0) { throw 'Legacy DemoRoot support failed' }
    Write-Output 'PASS learning-feedback.contract project-local and legacy paths'
} finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $fixture.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target' }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
