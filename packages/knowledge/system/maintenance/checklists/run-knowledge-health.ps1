[CmdletBinding()]
param(
    [ValidateSet('affected', 'full')][string]$Scope = 'affected',
    [string]$PreviousReport = '',
    [string[]]$ChangedPath = @(),
    [string[]]$ReviewEvent = @(),
    [ValidateSet('json', 'markdown')][string]$Format = 'json'
)
# Read-only: stdout only. Persist a report only to an explicitly authorized audit path.
$arguments = @((Join-Path $PSScriptRoot 'knowledge-health.mjs'), '--scope', $Scope, '--format', $Format)
if ($PreviousReport) { $arguments += @('--previous', $PreviousReport) }
foreach ($item in $ChangedPath) { $arguments += @('--changed', $item) }
foreach ($item in $ReviewEvent) { $arguments += @('--event', $item) }
& node @arguments
exit $LASTEXITCODE
