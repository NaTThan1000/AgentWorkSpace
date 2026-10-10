[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $Root 'scripts\new-presentation-calibration.ps1'
$Temp = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('fromdemotospec-calibration-' + [Guid]::NewGuid().ToString('N'))))
try {
    New-Item -ItemType Directory -Path $Temp -Force | Out-Null
    $output = @(& $Script -ProjectPath $Temp -PrototypeId 'fixture-demo' 2>&1)
    $code = $LASTEXITCODE
    $plan = ($output -join "`n") | ConvertFrom-Json
    if ($code -ne 0 -or $plan.schema_version -ne 2 -or $plan.policy -ne 'agent-runtime-v2' -or $plan.human_preview_required -ne $false -or @($plan.planned_paths).Count -ne 1) { throw 'Calibration plan failed' }
    if (Test-Path -LiteralPath (Join-Path $Temp 'presentation')) { throw 'Dry-run wrote files' }
    & $Script -ProjectPath $Temp -PrototypeId 'fixture-demo' -Apply | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Calibration apply failed' }
    $target = Join-Path $Temp 'presentation\calibration.md'
    $before = [IO.File]::ReadAllText($target)
    if (-not $before.Contains('fixture-demo') -or $before.Contains('{{prototype_id}}')) { throw 'Template expansion failed' }
    & $Script -ProjectPath $Temp -PrototypeId 'fixture-demo' -Apply | Out-Null
    if ($LASTEXITCODE -ne 3 -or [IO.File]::ReadAllText($target) -cne $before) { throw 'Overwrite protection failed' }
    $legacy = Join-Path $Temp 'legacy'
    New-Item -ItemType Directory -Path (Join-Path $legacy 'presentation\calibration') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $legacy 'presentation\calibration\00-brief.md'), 'legacy evidence')
    & $Script -ProjectPath $legacy -PrototypeId 'fixture-demo' -Apply | Out-Null
    if ($LASTEXITCODE -ne 3 -or (Test-Path -LiteralPath (Join-Path $legacy 'presentation\calibration.md'))) { throw 'Legacy project boundary failed' }
    Write-Output 'PASS presentation-calibration.contract v2'
} finally {
    $allowed = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $Temp.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target' }
    if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Recurse -Force }
}
