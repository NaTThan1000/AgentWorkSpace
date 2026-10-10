[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$GapPath = '',
    [string]$BriefPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'adapter-common.ps1')

$result = Get-FromDemoToSpecGapValidation -SessionPath $SessionPath -SessionRoot $SessionRoot -GapPath $GapPath -BriefPath $BriefPath
[pscustomobject][ordered]@{
    structure_passed = [bool]$result.structure_passed
    adapter_id = [string]$result.adapter_id
    session_id = [string]$result.session_id
    gap_status = [string]$result.gap_status
    gap_count = [int]$result.gap_count
    tunable_parameter_count = [int]$result.tunable_parameter_count
    external_flow_started = [bool]$result.external_flow_started
    semantic_review = [string]$result.semantic_review
} | ConvertTo-Json -Depth 16
