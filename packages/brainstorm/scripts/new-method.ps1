[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MethodId,
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,
    [Parameter(Mandatory = $true)]
    [ValidateSet('capture', 'framing', 'divergence', 'synthesis', 'convergence')]
    [string]$Category,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'method-common.ps1')

try {
    Assert-MethodContract -Condition ($MethodId -cmatch '^[a-z][a-z0-9-]*$') -Message 'MethodId must be a lowercase slug.'
    Assert-MethodContract -Condition (-not [string]::IsNullOrWhiteSpace($DisplayName)) -Message 'DisplayName must not be empty.'
    $root = Get-MethodProjectRoot -ProjectRoot $ProjectRoot -ScriptPath $MyInvocation.MyCommand.Path
    $catalogPath = Join-Path $root 'methods\catalog.json'
    $catalog = Read-MethodJson -Path $catalogPath
    Assert-MethodContract -Condition (@($catalog.methods | Where-Object { [string]$_.method_id -ceq $MethodId }).Count -eq 0) -Message "Method already exists: $MethodId"

    $relativePath = "methods/placeholders/$MethodId.md"
    $methodPath = Resolve-MethodRelativePath -ProjectRoot $root -RelativePath $relativePath
    Assert-MethodContract -Condition (-not (Test-Path -LiteralPath $methodPath)) -Message "Method path already exists: $relativePath"

    $document = @"
# $DisplayName

## Contract

- Method ID: ``$MethodId``
- Category: ``$Category``
- Status: ``placeholder``

## Placeholder readiness

- Source status: no verified sources
- Why unavailable: contract details and single-user AI adaptation are not reviewed
- Research required: locate authoritative sources and define behavior boundaries
- Ready conditions: sources reviewed; adaptation reviewed; positive and negative cases reviewed
- Recommended with: ``how-might-we``

## Purpose

Research required.

## Input contract

Research required.

## Use when

Research required.

## Avoid when

Research required.

## Procedure

Research required.

## Output contract

Research required.

## Exit conditions

Research required.

## Single-user + AI adaptation

Research required.

## Traceability

Research required.

## Sources

No verified sources yet.

## Behavior cases

### Positive case

Research required.

### Negative case

Research required.
"@

    $entry = [pscustomobject][ordered]@{
        method_id = $MethodId
        display_name = $DisplayName
        category = $Category
        status = 'placeholder'
        path = $relativePath
        source_ids = @()
        single_user_ai_adaptation = $false
        version = 1
        positive_case_id = $null
        negative_case_id = $null
        research_gap = 'Sources, contract details, adaptation, and behavior cases require review.'
        ready_conditions = @(
            'At least one authoritative or original source is reviewed.',
            'Single-user AI adaptation and method boundaries are documented.',
            'Positive and negative behavior cases pass semantic review.'
        )
        recommended_with = @('how-might-we')
    }
    $catalog.methods = @($catalog.methods) + @($entry)
    Write-MethodTextAtomic -Path $methodPath -Content $document
    try {
        Write-MethodTextAtomic -Path $catalogPath -Content (ConvertTo-MethodJson -Value $catalog)
    } catch {
        if (Test-Path -LiteralPath $methodPath -PathType Leaf) { Remove-Item -LiteralPath $methodPath -Force }
        throw
    }

    [pscustomobject][ordered]@{
        created = $true
        method_id = $MethodId
        status = 'placeholder'
        path = $relativePath
        promotion = 'manual-review-required'
    } | ConvertTo-Json -Depth 6
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
