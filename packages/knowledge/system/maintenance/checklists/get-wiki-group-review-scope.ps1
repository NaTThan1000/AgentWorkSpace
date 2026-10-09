[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReceiptPath,
    [Parameter(Mandatory = $true)][string]$DefinitionHash,
    [switch]$CandidateReopened,
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$receiptFullPath = [IO.Path]::GetFullPath((Join-Path $rootPath $ReceiptPath))

try {
    if ($DefinitionHash -notmatch '^[a-f0-9]{64}$') { throw 'DefinitionHash must be a lowercase SHA-256 value.' }
    if (-not (Test-Path -LiteralPath $receiptFullPath -PathType Leaf)) { throw "Review receipt does not exist: $ReceiptPath" }
    $receipt = Get-Content -Raw -Encoding UTF8 -LiteralPath $receiptFullPath | ConvertFrom-Json
    $baselineRevision = [string]$receipt.repository_revision
    $baselineHash = [string]$receipt.definition_hash
    $baselineWikiCount = [int]$receipt.screened_scope.wiki_count
    if ($baselineRevision -notmatch '^[a-f0-9]{40}$') { throw 'Receipt repository_revision is invalid.' }
    if ($baselineHash -notmatch '^[a-f0-9]{64}$') { throw 'Receipt definition_hash is invalid.' }
    if ($baselineWikiCount -lt 1) { throw 'Receipt screened_scope.wiki_count must be a positive integer from a full-library scan.' }
    $currentRevision = (& git -c ("safe.directory=" + $rootPath) -C $rootPath rev-parse HEAD).Trim()
    $revisionExitCode = if (Test-Path variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($revisionExitCode -ne 0) { throw 'Unable to resolve current repository revision.' }
    $baselineExists = (& git -c ("safe.directory=" + $rootPath) -C $rootPath cat-file -e ($baselineRevision + '^{commit}'))
    $baselineExitCode = if (Test-Path variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($baselineExitCode -ne 0) { throw "Receipt baseline revision is unavailable: $baselineRevision" }
    $currentWikiPaths = @(Get-ChildItem -LiteralPath (Join-Path $rootPath 'wiki') -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name | ForEach-Object { 'wiki/' + $_.Name })
    $currentWikiCount = $currentWikiPaths.Count
    $growthCount = [Math]::Max(0, $currentWikiCount - $baselineWikiCount)
    $growthThreshold = [Math]::Max(1, [Math]::Ceiling($baselineWikiCount * 0.1))
    $mode = 'incremental'
    $reason = if ($CandidateReopened) { 'A Group Candidate was reopened; review the changed Candidate and its affected Wiki incrementally.' } else { 'Definition unchanged; only Wiki files changed after the baseline require discovery review.' }
    if ($baselineHash -ne $DefinitionHash) {
        $mode = 'full'
        $reason = 'Definition hash changed; the existing discovery and adjudication baseline is invalid.'
        $paths = $currentWikiPaths
    } elseif ($growthCount -ge 20 -or $growthCount -ge $growthThreshold) {
        $mode = 'full'
        $reason = "Wiki count increased by $growthCount since the last full scan (threshold: 20 or $growthThreshold / 10%)."
        $paths = $currentWikiPaths
    } else {
        $paths = @(& git -c ("safe.directory=" + $rootPath) -C $rootPath diff --name-only ($baselineRevision + '..' + $currentRevision) -- wiki | Where-Object { $_ -match '^wiki/.+\.md$' -and $_ -ne 'wiki/README.md' } | Sort-Object -Unique)
        $diffExitCode = if (Test-Path variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
        if ($diffExitCode -ne 0) { throw 'Unable to calculate Wiki changes since baseline.' }
    }
    [pscustomobject][ordered]@{
        schema_version = 1
        kind = 'wiki_group_review_scope'
        group_id = [string]$receipt.group_id
        receipt_path = $ReceiptPath.Replace('\\', '/')
        baseline_revision = $baselineRevision
        current_revision = $currentRevision
        baseline_definition_hash = $baselineHash
        requested_definition_hash = $DefinitionHash
        baseline_wiki_count = $baselineWikiCount
        current_wiki_count = $currentWikiCount
        wiki_growth_count = $growthCount
        wiki_growth_threshold = $growthThreshold
        candidate_reopened = [bool]$CandidateReopened
        mode = $mode
        reason = $reason
        candidate_paths = @($paths)
    } | ConvertTo-Json -Depth 6
} catch {
    [Console]::Error.WriteLine("WIKI_GROUP_REVIEW_SCOPE_FAILED: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)")
    exit 2
}
