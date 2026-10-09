[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('scoring', 'stage1', 'stage2', 'stage3')]
    [string]$Stage,
    [Parameter(Mandatory = $true)]
    [string]$RunPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [ValidateSet('summary', 'full')]
    [string]$OutputMode = 'summary'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:utf8NoBom = New-Object Text.UTF8Encoding($false)
$script:projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))

function Get-ProjectPath {
    param([string]$Path, [switch]$MustExist)
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $script:projectRoot $Path)) }
    $prefix = $script:projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $Path" }
    $probe = $full
    while ($probe -and $probe -ne $script:projectRoot) {
        if (Test-Path -LiteralPath $probe) { if (((Get-Item -LiteralPath $probe -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked paths are not valid evidence/output targets: $Path" } }
        $probe = Split-Path -Parent $probe
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
    return $full
}
function Convert-UnicodeLiteral {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}
function Get-RelativePath { param([string]$FullPath) $FullPath.Substring($script:projectRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/') }
function Get-FileRecord {
    param([string]$Path, [string]$Role, [bool]$Required)
    $full = Get-ProjectPath -Path $Path
    $exists = Test-Path -LiteralPath $full -PathType Leaf
    if ($Required -and -not $exists) { throw "Required context evidence is missing: $Path" }
    $sha256 = if ($exists) { (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    $bytes = if ($exists) { (Get-Item -LiteralPath $full).Length } else { 0 }
    return [pscustomobject][ordered]@{ path = Get-RelativePath -FullPath $full; role = $Role; required = $Required; exists = $exists; sha256 = $sha256; bytes = $bytes }
}
function Write-Utf8 { param([string]$Path, [string]$Text) $parent = Split-Path -Parent $Path; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; [IO.File]::WriteAllText($Path, $Text, $script:utf8NoBom) }

try {
    $runFull = Get-ProjectPath -Path $RunPath -MustExist
    $outputFull = Get-ProjectPath -Path $OutputPath
    $run = Get-Content -Raw -Encoding UTF8 -LiteralPath $runFull | ConvertFrom-Json
    $required = New-Object 'System.Collections.Generic.List[object]'
    [void]$required.Add((Get-FileRecord -Path (Get-RelativePath -FullPath $runFull) -Role 'run_manifest' -Required $true))
    [void]$required.Add((Get-FileRecord -Path 'system/protocols/INGEST_WRITER_ROUTING.md' -Role 'writer_execution_policy' -Required $true))
    $rawStyleSample = $null
    if ([int]$run.schema_version -ge 8 -and $Stage -eq 'stage1') {
        foreach ($rule in @('raw-standard-v2.md','raw-writing-v2.md','raw-review-contract-notes.md')) {
            [void]$required.Add((Get-FileRecord -Path ('system/maintenance/checklists/' + $rule) -Role 'raw_v2_required_rule' -Required $true))
        }
        $rawStyleSamplePath = Convert-UnicodeLiteral 'raw-sources/\u4ece0\u52301\u521b\u9020\u5f00\u653e\u4e16\u754c\u8bbe\u8ba1\u6d41\u7a0b-\u5929\u7f8e\u6c5f\u5cb8\u6816-20260705.md'
        $rawStyleSample = Get-FileRecord -Path $rawStyleSamplePath -Role 'raw_style_reference_sample' -Required $true
        [void]$required.Add($rawStyleSample)
    }
    foreach ($item in @($run.items)) {
        if ([string]$item -match '^(Clippings|raw-sources)/') { [void]$required.Add((Get-FileRecord -Path ([string]$item) -Role 'input_or_raw' -Required $true)) }
    }
    $prior = switch ($Stage) { 'scoring' { @() } 'stage1' { @('scoring') } 'stage2' { @('scoring','stage1') } 'stage3' { @('scoring','stage1','stage2') } }
    foreach ($package in $prior) {
        $record = $run.packages.$package
        if ($null -eq $record) { throw "Prior package is missing for $Stage context: $package" }
        [void]$required.Add((Get-FileRecord -Path ([string]$record.path) -Role ("sealed_" + $package) -Required $true))
    }
    if ($Stage -in @('stage1','stage2','stage3')) {
        foreach ($audit in @($run.content_audits)) { [void]$required.Add((Get-FileRecord -Path ([string]$audit.path) -Role 'content_audit_receipt' -Required $true)) }
    }
    $workset = @($run.content_audits | Where-Object { $_.PSObject.Properties['status'] -and $_.status -ne 'passed' } | ForEach-Object { [pscustomobject][ordered]@{ raw_path = $_.raw_path; receipt_path = $_.path } })
    $expandable = @($run.artifacts | ForEach-Object { $_.path } | Sort-Object -Unique)
    $requiredRows = @($required.ToArray())
    $requiredBytes = [int64](($requiredRows | Measure-Object -Property bytes -Sum).Sum)
    $knownAgentIds = @()
    $executionBudget = $null
    if ($null -ne $run.PSObject.Properties['execution_control']) {
        $actualSessionCount = 0
        if ($run.execution_control.PSObject.Properties['agent_sessions']) {
            $sessions = @($run.execution_control.agent_sessions)
            $actualSessionCount = $sessions.Count
            $knownAgentIds = @($sessions | ForEach-Object { [string]$_.agent_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        }
        if ($actualSessionCount -eq 0) {
        foreach ($attempt in @($run.execution_control.raw_review_attempts)) {
            if ($attempt.PSObject.Properties['agent_id'] -and -not [string]::IsNullOrWhiteSpace([string]$attempt.agent_id)) { $knownAgentIds += [string]$attempt.agent_id }
        }
        if ($run.execution_control.PSObject.Properties['raw_review_history']) {
            foreach ($attempt in @($run.execution_control.raw_review_history)) {
                if ($attempt.PSObject.Properties['agent_id'] -and -not [string]::IsNullOrWhiteSpace([string]$attempt.agent_id)) { $knownAgentIds += [string]$attempt.agent_id }
            }
        }
        foreach ($writerStage in @('stage1', 'stage3')) {
            $writerRecord = $run.execution_control.writer_stages.$writerStage
            if ($null -ne $writerRecord) { $knownAgentIds += @($writerRecord.agent_ids | ForEach-Object { [string]$_ }) }
        }
        foreach ($writerRecord in @($run.execution_control.writer_stage_history)) {
            $knownAgentIds += @($writerRecord.agent_ids | ForEach-Object { [string]$_ })
        }
        $knownAgentIds = @($knownAgentIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        $actualSessionCount = $knownAgentIds.Count
        }
        $executionBudget = [pscustomobject][ordered]@{
            fresh_parent_context_recommended = [bool]$run.execution_control.fresh_parent_context_recommended
            child_session_cap = [int]$run.execution_control.child_session_cap
            distinct_agent_count = $knownAgentIds.Count
            actual_child_session_count = $actualSessionCount
            remaining_child_session_slots = [int]$run.execution_control.child_session_cap - $actualSessionCount
            routine_batch_target = 'Group compatible files: normally 2-3 Raw writers, one primary Terra reviewer, and 2-3 Wiki writers; reserve only for broad rewrite or Astra escalation.'
            context_rule = 'Use this compact manifest and direct file paths. Do not fork full conversation history or paste prior tool output into child prompts.'
            raw_review_flow = 'reserve/bind one primary Terra session -> prepare-raw-review -> fill generated template -> preflight once -> complete -> apply exact small repairs or Luna rewrite -> same Terra targeted verification'
            writer_completion_action = if ($Stage -in @('stage1', 'stage3')) { "record-writer-stage -Package $Stage before sealing" } else { $null }
        }
    }
    $cost = [pscustomobject]([ordered]@{
        required_file_count = $requiredRows.Count
        required_bytes = $requiredBytes
        expandable_file_count = @($expandable).Count
        raw_review_attempt_count = if ($null -ne $executionBudget) { @($run.execution_control.raw_review_attempts).Count } else { 0 }
        distinct_agent_count = $knownAgentIds.Count
        actual_child_session_count = if ($null -ne $executionBudget) { [int]$executionBudget.actual_child_session_count } else { 0 }
    })
    $context = [pscustomobject]([ordered]@{
        schema_version = 2
        batch_id = [string]$run.batch_id
        stage = $Stage
        objective = "Provide semantic judgment for $Stage; do not repeat hashes, paths, counts, or fixed package formatting."
        evidence_prepared = $true
        sources_read = $false
        writer_execution = [pscustomobject][ordered]@{
            policy_path = 'system/protocols/INGEST_WRITER_ROUTING.md'
            applies_when = 'Codex host and GPT model family; resolve from actual host context.'
            dispatch_required_when_applicable = $Stage -in @('stage1','stage3')
            delegated_scope = switch ($Stage) { 'stage1' { 'Raw prose writing and revision only' } 'stage3' { 'Wiki prose integration and revision only, after Stage2 gate' } default { 'none; main session owns this stage' } }
            raw_style_reference_required = $Stage -eq 'stage1'
            raw_style_reference = $rawStyleSample
            raw_style_reference_contract = if ($Stage -eq 'stage1') { 'Read the complete sample before writing; use it only for paragraph rhythm, reasoning exposition, and semantic choice of prose/list/table. Do not copy its facts, conclusions, annotations, or fixed outline.' } else { $null }
            dispatch_status = 'not_dispatched_by_context_preparer'
            audit_rule = 'Preserve mandatory independent audits; writer cannot approve own output.'
            requested_model = if ($Stage -in @('stage1', 'stage3')) { 'gpt-5.6-luna' } else { $null }
            requested_reasoning_effort = if ($Stage -in @('stage1', 'stage3')) { 'max' } else { $null }
            completion_gate = if ($Stage -in @('stage1', 'stage3')) { 'record-writer-stage must bind final output hashes and actual agent IDs before package sealing.' } else { $null }
        }
        execution_budget = $executionBudget
        mode = if ($run.review_policy -eq 'interactive') { 'standard' } else { 'automatic' }
        current_stage_approval = if ($null -ne $run.PSObject.Properties['approvals']) { $run.approvals.$Stage } else { $null }
        reuse_rule = 'Reuse unchanged evidence only after checking source version and applicability; preparation is not reading or semantic acceptance.'
        stage_task = switch ($Stage) {
            'scoring' { 'Read complete source structure, decide ingest/conditional/skip from evidence; do not rescore history silently.' }
            'stage1' { 'Inventory complete source units before raw writing; read the bound raw_style_reference sample in full; retain definitions, reasoning, numbers, examples, conditions and media. Coverage and retention policy are separate. Include content_summary in each raw row.' }
            'stage2' { 'Read relevant Wiki synthesis; specify concrete additions, conditions, conflicts, destination and unconsumed content. Verify Stage1 checkpoint before writes.' }
            'stage3' { 'Describe actual knowledge increments and verify changed dependencies. List completed splits or explicit empty array; preserve actual backtest results and recovery state.' }
        }
        required_evidence = $requiredRows
        expandable_evidence = @($expandable)
        prior_sections = @($prior)
        failed_workset = @($workset)
        script_owned_facts = @('paths','sha256','counts','git revisions','fixed table headers','package markdown')
        allowed_exception_fields = @('semantic_exceptions','unresolved_risks','structure_change_requests','micro_failures')
        cost = $cost
    })
    $json = (@(($context | ConvertTo-Json -Depth 30) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n") + "`n"
    Write-Utf8 -Path $outputFull -Text $json
    $result = [pscustomobject][ordered]@{ status = 'prepared'; path = Get-RelativePath -FullPath $outputFull; sha256 = (Get-FileHash -LiteralPath $outputFull -Algorithm SHA256).Hash.ToLowerInvariant(); next_action = 'read required_evidence, then submit semantic section' }
    if ($OutputMode -eq 'full') { $result | Add-Member -NotePropertyName context -NotePropertyValue $context }
    Write-Output ($result | ConvertTo-Json -Depth 30)
} catch {
    [Console]::Error.WriteLine('INGEST_CONTEXT_PREPARE_FAILED: ' + $_.Exception.Message + ' @ ' + $_.InvocationInfo.PositionMessage)
    exit 1
}
