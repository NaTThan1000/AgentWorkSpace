$script:BrainstormGameConceptUtf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-GameConceptCombinationValidation {
    param(
        [string]$SessionPath,
        [string]$SessionRoot = '',
        [string]$CombinationPath = ''
    )

    $statePath = Resolve-SessionStatePath -SessionPath $SessionPath
    $sessionDirectory = Split-Path -Parent $statePath
    $sessionValidation = Get-SessionValidation -SessionPath $sessionDirectory -SessionRoot $SessionRoot
    $state = Read-Utf8Json -Path $statePath
    if ([string]::IsNullOrWhiteSpace($CombinationPath)) {
        $CombinationPath = Join-Path $sessionDirectory 'game-concept-combinations.md'
    }
    $CombinationPath = [IO.Path]::GetFullPath($CombinationPath)
    $sessionPrefix = [IO.Path]::GetFullPath($sessionDirectory).TrimEnd([char]92, [char]47) + [IO.Path]::DirectorySeparatorChar
    Assert-PlaybookContract -Condition ($CombinationPath.StartsWith($sessionPrefix, [StringComparison]::OrdinalIgnoreCase)) -Message 'CombinationPath must stay inside the session directory.'
    Assert-PlaybookContract -Condition (Test-Path -LiteralPath $CombinationPath -PathType Leaf) -Message "Missing Game Concept combination gate: $CombinationPath"

    $recordPath = Resolve-SafeRelativePath -BasePath $sessionDirectory -RelativePath ([string]$state.record_path)
    $record = [IO.File]::ReadAllText($recordPath, $script:BrainstormGameConceptUtf8NoBom)
    $content = [IO.File]::ReadAllText($CombinationPath, $script:BrainstormGameConceptUtf8NoBom)
    Assert-PlaybookContract -Condition ($content.Contains('> Playbook ID: `game-concept`')) -Message 'Combination gate Playbook ID must be game-concept.'
    Assert-PlaybookContract -Condition ($content.Contains("> Session ID: ``$([string]$state.session_id)``")) -Message 'Combination gate Session ID does not match the session.'
    Assert-PlaybookContract -Condition ($content.Contains('> Semantic review: `required`')) -Message 'Combination gate must retain semantic review required.'

    $ideaHeaders = @('Idea ID', 'Parent IDs', 'Source', 'Method ID', 'Disposition', 'Adoption', 'Idea', 'Destination', 'Supersedes', 'Decision reason')
    $ideaRows = @(Get-MarkdownTableRows -Content $record -Heading 'Idea Ledger' -ExpectedHeaders $ideaHeaders)
    $ideaIds = @{}
    foreach ($row in $ideaRows) { $ideaIds[[string]$row.cells[0]] = $true }
    $decisionRows = @(Get-MarkdownTableRows -Content $record -Heading 'Decision Record' -ExpectedHeaders @('Decision ID', 'Candidate IDs', 'Decision', 'Criteria', 'Evidence IDs', 'Decider'))
    $decisionIds = @{}
    foreach ($row in $decisionRows) { $decisionIds[[string]$row.cells[0]] = $row }

    Assert-PlaybookContract -Condition ($content.Contains('> Combination schema: `2`')) -Message 'Active combinations require schema 2.'
    $packageRows = @(Get-MarkdownTableRows -Content $content -Heading 'Package Options' -ExpectedHeaders @(
        'Package ID', 'Name', 'Experience fragment', 'Mechanism and coherence',
        'Included Idea IDs', 'Deferred Idea IDs', 'Trade-off'
    ))
    $packageIds = @{}
    $packageSignatures = @{}
    foreach ($row in $packageRows) {
        $cells = @($row.cells)
        $packageId = [string]$cells[0]
        Assert-PlaybookContract -Condition ($packageId -cmatch '^PKG-[0-9]{3,}$') -Message "Invalid Package ID: $packageId"
        Assert-PlaybookContract -Condition (-not $packageIds.ContainsKey($packageId)) -Message "Duplicate Package ID: $packageId"
        foreach ($index in @(1, 2, 3, 6)) {
            Assert-PlaybookContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$cells[$index]) -and [string]$cells[$index] -cne '-') -Message "Package field is empty: $packageId"
        }
        $includedIds = @(Split-ControlReferences -Value ([string]$cells[4]))
        Assert-PlaybookContract -Condition ($includedIds.Count -ge 1) -Message "Package requires an Idea source: $packageId"
        Assert-PlaybookContract -Condition (@($includedIds | Sort-Object -Unique).Count -eq $includedIds.Count) -Message "Package contains duplicate Idea IDs: $packageId"
        foreach ($ideaId in $includedIds) {
            Assert-PlaybookContract -Condition ($ideaIds.ContainsKey($ideaId)) -Message "Unknown included Idea ID: $packageId->$ideaId"
        }
        foreach ($ideaId in @(Split-ControlReferences -Value ([string]$cells[5]))) {
            Assert-PlaybookContract -Condition ($ideaIds.ContainsKey($ideaId) -and -not ($includedIds -ccontains $ideaId)) -Message "Invalid deferred Idea ID: $packageId->$ideaId"
        }
        $packageSignature = (([string]$cells[2]) + '|' + ([string]$cells[3])).ToLowerInvariant()
        Assert-PlaybookContract -Condition (-not $packageSignatures.ContainsKey($packageSignature)) -Message "Packages repeat the same experience and mechanism: $packageId"
        $packageSignatures[$packageSignature] = $true
        $packageIds[$packageId] = $includedIds
    }

    $selectionRows = @(Get-MarkdownTableRows -Content $content -Heading 'Package Selection' -ExpectedHeaders @(
        'Gate status', 'Selected package ID', 'Decision IDs', 'Selection rationale', 'Deferred package IDs'
    ))
    Assert-PlaybookContract -Condition ($selectionRows.Count -eq 1) -Message 'Package Selection requires exactly one row.'
    $selection = @($selectionRows[0].cells)
    $gateStatus = [string]$selection[0]
    Assert-PlaybookContract -Condition (@('open', 'paused', 'selected') -ccontains $gateStatus) -Message "Invalid combination gate status: $gateStatus"
    $selectedPackageId = [string]$selection[1]
    $selectedDecisionIds = @(Split-ControlReferences -Value ([string]$selection[2]))
    $deferredPackageIds = @(Split-ControlReferences -Value ([string]$selection[4]))
    if ($gateStatus -ceq 'selected') {
        Assert-PlaybookContract -Condition ($packageIds.ContainsKey($selectedPackageId)) -Message "Unknown selected Package ID: $selectedPackageId"
        Assert-PlaybookContract -Condition ($selectedDecisionIds.Count -ge 1) -Message 'Selected combination gate requires a Decision ID.'
        foreach ($decisionId in $selectedDecisionIds) {
            Assert-PlaybookContract -Condition ($decisionIds.ContainsKey($decisionId)) -Message "Unknown combination Decision ID: $decisionId"
            Assert-PlaybookContract -Condition (@('user', 'joint') -ccontains [string]$decisionIds[$decisionId].cells[5]) -Message 'Package selection requires user/joint decisions.'
        }
        Assert-PlaybookContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$selection[3]) -and [string]$selection[3] -cne '-') -Message 'Selected combination gate requires a rationale.'
        $expectedDeferred = @($packageIds.Keys | Where-Object { $_ -cne $selectedPackageId })
        Assert-PlaybookContract -Condition ($deferredPackageIds.Count -eq $expectedDeferred.Count -and @($deferredPackageIds | Sort-Object -Unique).Count -eq $deferredPackageIds.Count) -Message 'Account for every existing unselected package exactly once.'
        foreach ($packageId in $deferredPackageIds) {
            Assert-PlaybookContract -Condition ($packageId -cne $selectedPackageId -and $packageIds.ContainsKey($packageId)) -Message "Invalid deferred Package ID: $packageId"
        }
    } else {
        Assert-PlaybookContract -Condition ($selectedPackageId -ceq '-' -and $selectedDecisionIds.Count -eq 0 -and $deferredPackageIds.Count -eq 0) -Message 'Open or paused combinations must not claim a package selection.'
    }

    Assert-PlaybookContract -Condition (-not [string]::IsNullOrWhiteSpace([string]$selection[3]) -and [string]$selection[3] -cne '-') -Message 'Selection/open state requires a reason and continuation boundary.'

    return [pscustomobject][ordered]@{
        structure_passed = $true
        combination_schema = 2
        playbook_id = 'game-concept'
        session_id = [string]$state.session_id
        session_status = [string]$sessionValidation.status
        gate_status = $gateStatus
        package_count = $packageRows.Count
        package_ids = @($packageIds.Keys | Sort-Object)
        selected_package_id = if ($gateStatus -ceq 'selected') { $selectedPackageId } else { $null }
        decision_ids = @($selectedDecisionIds)
        semantic_review = 'required'
    }
}
