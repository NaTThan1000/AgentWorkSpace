[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'ingest-control',
        'source-content-audit',
        'source-audit-vnext',
        'render-ingest-package',
        'prepare-ingest-context',
        'measure-ingest-package-baseline',
        'content-backtest',
        'build-backtest-anchor-receipt',
        'run-ingest-maintenance',
        'finalize-ingest-stage3',
        'sync-capacity-risks',
        'check-powershell-syntax'
    )]
    [string]$Name
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$path = Join-Path $PSScriptRoot ($Name + '.ps1')

if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Registered ingest tool is missing: $Name"
}

$relative = [IO.Path]::GetFullPath($path).Substring(
    $projectRoot.TrimEnd('\', '/').Length + 1
).Replace('\', '/')

[pscustomobject][ordered]@{
    name = $Name
    path = $relative
} | ConvertTo-Json
