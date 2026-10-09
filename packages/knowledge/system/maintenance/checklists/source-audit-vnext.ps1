[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('decision-template', 'validate')]
    [string]$Action,
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [Parameter(Mandatory = $true)]
    [string]$RawPath,
    [Parameter(Mandatory = $true)]
    [string]$DecisionPath,
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath,
    [ValidateSet('stage1', 'backtest')]
    [string]$Mode = 'stage1',
    [switch]$PersistReview,
    [ValidateSet('summary', 'full')]
    [string]$OutputMode = 'summary'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:utf8NoBom = New-Object Text.UTF8Encoding($false)
$script:projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$script:auditTool = Join-Path $PSScriptRoot 'source-content-audit.ps1'

function Get-ProjectPath {
    param([string]$Path, [switch]$MustExist)
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $script:projectRoot $Path)) }
    $prefix = $script:projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $Path" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
    return $full
}
function Get-RelativePath { param([string]$FullPath) $FullPath.Substring($script:projectRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/') }
function Get-Sha256 { param([string]$Path) (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Utf8 { param([string]$Path, [string]$Text) $parent = Split-Path -Parent $Path; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; [IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom) }
function Write-Json { param([string]$Path, [object]$Value) Write-Utf8 -Path $Path -Text ((@(($Value | ConvertTo-Json -Depth 30) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n") + "`n") }
function Invoke-Audit {
    param([string[]]$Arguments)
    $text = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:auditTool @Arguments) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "source-content-audit failed: $text" }
    return $text
}

try {
    $manifestFull = Get-ProjectPath -Path $ManifestPath -MustExist
    $rawFull = Get-ProjectPath -Path $RawPath -MustExist
    $decisionFull = Get-ProjectPath -Path $DecisionPath
    $receiptFull = Get-ProjectPath -Path $ReceiptPath
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestFull | ConvertFrom-Json
    if ($Action -eq 'decision-template') {
        $template = [pscustomobject][ordered]@{
            schema_version = 4
            mode = $Mode
            input = [pscustomobject][ordered]@{
                manifest_path = Get-RelativePath -FullPath $manifestFull
                manifest_sha256 = Get-Sha256 -Path $manifestFull
                raw_path = Get-RelativePath -FullPath $rawFull
                raw_sha256 = Get-Sha256 -Path $rawFull
            }
            reviewer_contract = [pscustomobject][ordered]@{ independent_pass = $false; writer_claims_used = $false }
            conclusion = 'TODO'
            rules = @()
        }
        Write-Json -Path $decisionFull -Value $template
        $result = [pscustomobject][ordered]@{ status = 'template_created'; path = Get-RelativePath -FullPath $decisionFull; sha256 = Get-Sha256 -Path $decisionFull; next_action = 'fill semantic rules, then validate' }
        if ($OutputMode -eq 'full') { $result | Add-Member -NotePropertyName decision_template -NotePropertyValue $template }
        Write-Output ($result | ConvertTo-Json -Depth 30)
        exit 0
    }
    $decision = Get-Content -Raw -Encoding UTF8 -LiteralPath $decisionFull | ConvertFrom-Json
    if ([int]$decision.schema_version -ne 4) { throw 'vNext decisions must use schema_version 4.' }
    if ([string]$decision.mode -ne $Mode) { throw 'Decision mode does not match requested mode.' }
    if ([string]$decision.input.manifest_sha256 -ne (Get-Sha256 -Path $manifestFull)) { throw 'Decision manifest hash does not match manifest.' }
    if ([string]$decision.input.raw_sha256 -ne (Get-Sha256 -Path $rawFull)) { throw 'Decision raw hash does not match raw.' }
    $legacyDecision = [pscustomobject][ordered]@{
        schema_version = 3
        manifest_sha256 = [string]$decision.input.manifest_sha256
        raw_sha256 = [string]$decision.input.raw_sha256
        reviewer_contract = $decision.reviewer_contract
        conclusion = [string]$decision.conclusion
        rules = @($decision.rules)
    }
    $stagingRoot = Join-Path (Split-Path -Parent $receiptFull) ('.audit-staging-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    $stagingDecision = Join-Path $stagingRoot 'decisions.v3.json'
    $stagingReview = Join-Path $stagingRoot 'compiled.review.json'
    Write-Json -Path $stagingDecision -Value $legacyDecision
    try {
        Invoke-Audit -Arguments @('-Action','template','-Mode',$Mode,'-ManifestPath',(Get-RelativePath -FullPath $manifestFull),'-RawPath',(Get-RelativePath -FullPath $rawFull),'-ReviewPath',(Get-RelativePath -FullPath $stagingReview)) | Out-Null
        Invoke-Audit -Arguments @('-Action','apply-decisions','-ReviewPath',(Get-RelativePath -FullPath $stagingReview),'-DecisionPath',(Get-RelativePath -FullPath $stagingDecision)) | Out-Null
        Invoke-Audit -Arguments @('-Action','validate','-Mode',$Mode,'-ReviewPath',(Get-RelativePath -FullPath $stagingReview),'-ReceiptPath',(Get-RelativePath -FullPath $receiptFull)) | Out-Null
        $receipt = Get-Content -Raw -Encoding UTF8 -LiteralPath $receiptFull | ConvertFrom-Json
        $reviewPersistence = if ($PersistReview) { 'persisted_debug' } else { 'compiled_in_memory' }
        $receipt | Add-Member -Force -NotePropertyName schema_version -NotePropertyValue 5
        $receipt | Add-Member -Force -NotePropertyName decision_schema_version -NotePropertyValue 4
        $receipt | Add-Member -Force -NotePropertyName review_persistence -NotePropertyValue $reviewPersistence
        $receipt | Add-Member -Force -NotePropertyName decision_path -NotePropertyValue (Get-RelativePath -FullPath $decisionFull)
        $receipt | Add-Member -Force -NotePropertyName decision_sha256 -NotePropertyValue (Get-Sha256 -Path $decisionFull)
        $reviewPath = if ($PersistReview) { Get-RelativePath -FullPath (Join-Path (Split-Path -Parent $receiptFull) 'review.json') } else { $null }
        $receipt | Add-Member -Force -NotePropertyName review_path -NotePropertyValue $reviewPath
        if ($PersistReview) { Copy-Item -LiteralPath $stagingReview -Destination (Join-Path (Split-Path -Parent $receiptFull) 'review.json') -Force }
        else { $receipt.PSObject.Properties.Remove('review_sha256') }
        Write-Json -Path $receiptFull -Value $receipt
        $result = [pscustomobject][ordered]@{ status = [string]$receipt.status; path = Get-RelativePath -FullPath $receiptFull; sha256 = Get-Sha256 -Path $receiptFull; next_action = 'record-content-audit'; review_persistence = [string]$receipt.review_persistence }
        if ($OutputMode -eq 'full') { $result | Add-Member -NotePropertyName receipt -NotePropertyValue $receipt }
        Write-Output ($result | ConvertTo-Json -Depth 30)
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
    }
} catch {
    [Console]::Error.WriteLine('SOURCE_AUDIT_VNEXT_FAILED: ' + $_.Exception.Message)
    exit 1
}
