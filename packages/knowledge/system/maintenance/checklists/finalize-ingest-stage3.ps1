[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Prepare','Seal')][string]$Phase,
    [Parameter(Mandatory = $true)][string]$RunPath,
    [Parameter(Mandatory = $true)][string]$Stage1Revision,
    [string]$AgentIds = '',
    [string]$Stage3SemanticPath = '',
    [string]$GateAuditSemanticPath = '',
    [string]$Stage3PackagePath = '',
    [string]$GateAuditPackagePath = '',
    [string]$MaintenancePath = '',
    [ValidateSet('summary','full')][string]$OutputMode = 'summary'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$hostExecutable = (Get-Process -Id $PID).Path
$control = Join-Path $PSScriptRoot 'ingest-control.ps1'

function Project-Path([string]$Value, [switch]$MustExist) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw 'A required path is empty.' }
    $full = if ([IO.Path]::IsPathRooted($Value)) { [IO.Path]::GetFullPath($Value) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $Value)) }
    $prefix = $projectRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $full" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $full" }
    return $full
}

function Relative-Path([string]$Full) {
    return $Full.Substring($projectRoot.TrimEnd('\','/').Length + 1).Replace('\','/')
}

function Invoke-Control([string[]]$Arguments) {
    $text = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $control @Arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "ingest-control failed: $text" }
    return $text
}

function Read-Json([string]$Path) {
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Get-SectionStatus([string]$RunFull, [string]$Section) {
    $run = Read-Json $RunFull
    $data = Read-Json (Project-Path ([string]$run.package_data.path) -MustExist)
    return [string]$data.sections.$Section.status
}

try {
    $runFull = Project-Path $RunPath -MustExist
    $runDirectory = Split-Path -Parent $runFull
    if ($Phase -eq 'Prepare') {
        & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sync-wiki-source-ledgers.ps1') -Mode Sync -ProjectRoot $projectRoot | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Wiki source-ledger sync failed.' }
        & $hostExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sync-capacity-risks.ps1') -Mode Sync | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Capacity-risk sync failed.' }
        $changed = @(& git -c "safe.directory=$($projectRoot.Replace('\','/'))" -c core.quotepath=false -C $projectRoot status --short)
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Stage3 changes.' }
        [pscustomobject][ordered]@{ status='prepared'; phase='Prepare'; changed_count=$changed.Count; changed=@($changed); next_action='Review the listed content and ledgers, stage exactly the intended Stage3 changes once, then run this entry with -Phase Seal.' } | ConvertTo-Json -Depth 10
        exit 0
    }

    foreach ($required in @($Stage3SemanticPath,$GateAuditSemanticPath)) { if ([string]::IsNullOrWhiteSpace($required)) { throw 'Seal requires Stage3SemanticPath and GateAuditSemanticPath.' } }
    $runRelative = Relative-Path $runFull
    [void](Invoke-Control @('-Action','sync-agent-sessions','-RunPath',$runRelative))
    if (@(& git -C $projectRoot diff --cached --name-only).Count -eq 0) { throw 'Seal requires the intended Stage3 changes to be staged once.' }
    $stage3Package = if ($Stage3PackagePath) { Project-Path $Stage3PackagePath } else { Join-Path $runDirectory 'package-stage3.md' }
    $gatePackage = if ($GateAuditPackagePath) { Project-Path $GateAuditPackagePath } else { Join-Path $runDirectory 'package-gate-audit.md' }
    $maintenance = if ($MaintenancePath) { Project-Path $MaintenancePath } else { Join-Path $runDirectory 'maintenance.json' }
    $stage3SemanticRelative = Relative-Path (Project-Path $Stage3SemanticPath -MustExist)
    $gateSemanticRelative = Relative-Path (Project-Path $GateAuditSemanticPath -MustExist)
    $reused = New-Object System.Collections.Generic.List[string]
    if ((Get-SectionStatus $runFull 'stage3') -eq 'open') {
        if ([string]::IsNullOrWhiteSpace($AgentIds)) { throw 'An open Stage3 section requires AgentIds for the completed content writer.' }
        [void](Invoke-Control @('-Action','record-writer-stage','-RunPath',$runRelative,'-Package','stage3','-SemanticDataPath',$stage3SemanticRelative,'-AgentIds',$AgentIds))
        [void](Invoke-Control @('-Action','seal-package-section','-RunPath',$runRelative,'-Package','stage3','-SemanticDataPath',$stage3SemanticRelative))
        [void](Invoke-Control @('-Action','render-package','-RunPath',$runRelative,'-Package','stage3','-OutputPath',(Relative-Path $stage3Package)))
    } else { [void]$reused.Add('stage3') }
    [void](Invoke-Control @('-Action','record-package','-RunPath',$runRelative,'-Package','stage3','-PackagePath',(Relative-Path $stage3Package)))

    $runState = Read-Json $runFull
    $maintenanceReusable = $null -ne $runState.packages.maintenance -and (Test-Path -LiteralPath $maintenance -PathType Leaf)
    if ($maintenanceReusable) {
        $maintenanceRelative = Relative-Path $maintenance
        $maintenanceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $maintenance).Hash.ToLowerInvariant()
        if ([string]$runState.packages.maintenance.path -ne $maintenanceRelative -or [string]$runState.packages.maintenance.sha256 -ne $maintenanceHash) { throw 'Recorded maintenance receipt drifted; preserve it and reopen with a new evidence path.' }
        [void](Invoke-Control @('-Action','record-package','-RunPath',$runRelative,'-Package','maintenance','-PackagePath',(Relative-Path $maintenance)))
        [void]$reused.Add('maintenance')
    } else {
        $maintenanceText = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-ingest-maintenance.ps1') -Stage1Revision $Stage1Revision -Staged -OutputPath (Relative-Path $maintenance) -OutputMode $OutputMode 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Stage3 maintenance failed: $maintenanceText" }
        [void](Invoke-Control @('-Action','record-package','-RunPath',$runRelative,'-Package','maintenance','-PackagePath',(Relative-Path $maintenance)))
    }

    if ((Get-SectionStatus $runFull 'gate_audit') -eq 'open') {
        [void](Invoke-Control @('-Action','seal-package-section','-RunPath',$runRelative,'-Package','gate_audit','-SemanticDataPath',$gateSemanticRelative))
        [void](Invoke-Control @('-Action','render-package','-RunPath',$runRelative,'-Package','gate_audit','-OutputPath',(Relative-Path $gatePackage)))
    } else { [void]$reused.Add('gate_audit') }
    [void](Invoke-Control @('-Action','record-package','-RunPath',$runRelative,'-Package','gate_audit','-PackagePath',(Relative-Path $gatePackage)))
    [pscustomobject][ordered]@{ status='sealed'; phase='Seal'; reused=@($reused | ForEach-Object { $_ }); stage3_package=Relative-Path $stage3Package; maintenance=Relative-Path $maintenance; gate_audit_package=Relative-Path $gatePackage; next_action='Stage the generated run-local evidence, create the single Stage3 commit, then run check-stage3.' } | ConvertTo-Json -Depth 10
} catch {
    [Console]::Error.WriteLine('FINALIZE_INGEST_STAGE3_FAILED: ' + $_.Exception.Message)
    exit 2
}
