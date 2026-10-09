[CmdletBinding()]
param(
    [string]$MethodId,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'method-common.ps1')

try {
    $root = Get-MethodProjectRoot -ProjectRoot $ProjectRoot -ScriptPath $MyInvocation.MyCommand.Path
    $catalogPath = Join-Path $root 'methods\catalog.json'
    $sourcePath = Join-Path $root 'docs\research\public-sources.json'
    $catalog = Read-MethodJson -Path $catalogPath
    $registry = Read-MethodJson -Path $sourcePath

    Assert-MethodContract -Condition ([int]$catalog.schema_version -eq 1) -Message 'Method catalog schema_version must be 1.'
    Assert-MethodContract -Condition ([int]$registry.schema_version -eq 1) -Message 'Source registry schema_version must be 1.'
    foreach ($requiredPath in @('schemas\method-catalog.schema.json', 'schemas\public-sources.schema.json')) {
        Assert-MethodContract -Condition (Test-Path -LiteralPath (Join-Path $root $requiredPath) -PathType Leaf) -Message "Missing schema: $requiredPath"
    }

    $sourceIds = @{}
    foreach ($source in @($registry.sources)) {
        $sourceId = [string]$source.source_id
        Assert-MethodContract -Condition ($sourceId -cmatch '^SRC-[A-Z0-9]+-[0-9]{3}$') -Message "Invalid source_id: $sourceId"
        Assert-MethodContract -Condition (-not $sourceIds.ContainsKey($sourceId)) -Message "Duplicate source_id: $sourceId"
        Assert-MethodContract -Condition ([string]$source.url -cmatch '^https://') -Message "Source URL must use HTTPS: $sourceId"
        Assert-MethodContract -Condition ([string]$source.accessed_on -cmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') -Message "Invalid source access date: $sourceId"
        Assert-MethodContract -Condition (@('original-bibliographic', 'peer-reviewed-research', 'authoritative-practice', 'official-government', 'secondary-practice') -ccontains [string]$source.source_level) -Message "Invalid source level: $sourceId"
        Assert-MethodContract -Condition (@('verified', 'unverified', 'link-only') -ccontains [string]$source.license_status) -Message "Invalid license status: $sourceId"
        Assert-MethodContract -Condition (@('metadata-and-facts', 'attribution-noncommercial-adaptation', 'link-only') -ccontains [string]$source.reuse_scope) -Message "Invalid reuse scope: $sourceId"
        $sourceIds[$sourceId] = $true
    }

    $methodIds = @{}
    $selected = @()
    $readyCount = 0
    $placeholderCount = 0
    foreach ($method in @($catalog.methods)) {
        $id = [string]$method.method_id
        Assert-MethodContract -Condition ($id -cmatch '^[a-z][a-z0-9-]*$') -Message "Invalid method_id: $id"
        Assert-MethodContract -Condition (-not $methodIds.ContainsKey($id)) -Message "Duplicate method_id: $id"
        Assert-MethodContract -Condition ($script:MethodCategories -ccontains [string]$method.category) -Message "Invalid category: $id"
        Assert-MethodContract -Condition ($script:MethodStatuses -ccontains [string]$method.status) -Message "Invalid status: $id"
        Assert-MethodContract -Condition ([int]$method.version -ge 1) -Message "Invalid version: $id"
        Assert-MethodContract -Condition ([string]$method.path -cmatch '^methods/.+\.md$') -Message "Invalid method path: $id"

        $methodPath = Resolve-MethodRelativePath -ProjectRoot $root -RelativePath ([string]$method.path)
        Assert-MethodContract -Condition (Test-Path -LiteralPath $methodPath -PathType Leaf) -Message "Missing method document: $id"
        $content = [IO.File]::ReadAllText($methodPath, $script:MethodUtf8NoBom)
        foreach ($heading in $script:RequiredMethodHeadings) {
            Assert-MethodContract -Condition ($content.Contains($heading)) -Message "Method $id is missing heading: $heading"
        }
        Assert-MethodContract -Condition ($content.Contains("- Method ID: ``$id``")) -Message "Method document ID mismatch: $id"
        Assert-MethodContract -Condition ($content.Contains("- Category: ``$([string]$method.category)``")) -Message "Method document category mismatch: $id"
        Assert-MethodContract -Condition ($content.Contains("- Status: ``$([string]$method.status)``")) -Message "Method document status mismatch: $id"

        if ([string]$method.status -ceq 'ready') {
            $readyCount++
            Assert-MethodContract -Condition (@($method.source_ids).Count -ge 1) -Message "Ready method has no sources: $id"
            Assert-MethodContract -Condition ([bool]$method.single_user_ai_adaptation) -Message "Ready method lacks single-user AI adaptation: $id"
            Assert-MethodContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$method.positive_case_id)) -Message "Ready method lacks positive case: $id"
            Assert-MethodContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$method.negative_case_id)) -Message "Ready method lacks negative case: $id"
            Assert-MethodContract -Condition ($content.Contains([string]$method.positive_case_id)) -Message "Positive case ID is missing from method document: $id"
            Assert-MethodContract -Condition ($content.Contains([string]$method.negative_case_id)) -Message "Negative case ID is missing from method document: $id"
        }
        if ([string]$method.status -ceq 'placeholder') {
            $placeholderCount++
            Assert-MethodContract -Condition ([string]$method.path -cmatch '^methods/placeholders/.+\.md$') -Message "Placeholder path is outside methods/placeholders: $id"
            Assert-MethodContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$method.research_gap)) -Message "Placeholder lacks a research gap: $id"
            Assert-MethodContract -Condition (@($method.ready_conditions).Count -ge 3) -Message "Placeholder lacks ready conditions: $id"
            Assert-MethodContract -Condition (@($method.recommended_with).Count -ge 1) -Message "Placeholder lacks method combinations: $id"
            Assert-MethodContract -Condition (-not [bool]$method.single_user_ai_adaptation) -Message "Placeholder must not claim a reviewed single-user AI adaptation: $id"
            Assert-MethodContract -Condition ($null -eq $method.positive_case_id -and $null -eq $method.negative_case_id) -Message "Placeholder behavior case IDs must remain null: $id"
            Assert-MethodContract -Condition ($content.Contains('## Placeholder readiness')) -Message "Placeholder lacks readiness section: $id"
            foreach ($label in @('Source status:', 'Why unavailable:', 'Research required:', 'Ready conditions:', 'Recommended with:')) {
                Assert-MethodContract -Condition ($content.Contains($label)) -Message "Placeholder $id lacks readiness label: $label"
            }
        }
        foreach ($sourceId in @($method.source_ids)) {
            Assert-MethodContract -Condition ($sourceIds.ContainsKey([string]$sourceId)) -Message "Unknown source reference: $id->$sourceId"
            Assert-MethodContract -Condition ($content.Contains("``$sourceId``")) -Message "Method document omits source reference: $id->$sourceId"
        }
        $methodIds[$id] = $true
        if ([string]::IsNullOrWhiteSpace($MethodId) -or $id -ceq $MethodId) {
            $selected += $method
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($MethodId)) {
        Assert-MethodContract -Condition ($selected.Count -eq 1) -Message "Unknown method_id: $MethodId"
    }
    Assert-MethodContract -Condition ($readyCount -ge 1) -Message 'Catalog must contain at least one ready method.'

    [pscustomobject][ordered]@{
        structure_passed = $true
        method_count = @($selected).Count
        ready_count = $readyCount
        placeholder_count = $placeholderCount
        method_ids = @($selected | ForEach-Object { [string]$_.method_id })
        source_count = $sourceIds.Count
        semantic_review = 'required'
    } | ConvertTo-Json -Depth 8
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
