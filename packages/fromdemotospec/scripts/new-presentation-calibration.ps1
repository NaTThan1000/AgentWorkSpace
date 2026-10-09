[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$PrototypeId,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
try {
    $project = [IO.Path]::GetFullPath($ProjectPath)
    if (-not (Test-Path -LiteralPath $project -PathType Container)) { throw "Project path does not exist: $project" }
    if ($PrototypeId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'Invalid PrototypeId' }
    $targetRoot = Join-Path $project 'presentation'
    $target = Join-Path $targetRoot 'calibration.md'
    $legacy = Join-Path $targetRoot 'calibration\00-brief.md'
    if (Test-Path -LiteralPath $target) { throw "Calibration file already exists: $target" }
    if (Test-Path -LiteralPath $legacy) { throw 'Legacy calibration exists; preserve it and plan an explicit project migration.' }
    $source = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates\presentation-calibration.md'
    $content = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8).Replace('{{prototype_id}}', $PrototypeId).Replace("`r`n", "`n")
    if ($Apply) {
        [IO.Directory]::CreateDirectory($targetRoot) | Out-Null
        [IO.File]::WriteAllText($target, $content, (New-Object Text.UTF8Encoding($false)))
    }
    [ordered]@{ schema_version = 2; policy = 'agent-runtime-v2'; mode = $(if ($Apply) { 'apply' } else { 'plan' }); prototype_id = $PrototypeId; calibration_root = $targetRoot; planned_paths = @($target); human_preview_required = $false } | ConvertTo-Json -Depth 4
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 3
}
