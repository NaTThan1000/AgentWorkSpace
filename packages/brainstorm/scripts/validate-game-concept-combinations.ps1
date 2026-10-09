[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$CombinationPath = ''
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'session-common.ps1')
. (Join-Path $scriptRoot 'playbook-common.ps1')
. (Join-Path $scriptRoot 'game-concept-common.ps1')

Get-GameConceptCombinationValidation -SessionPath $SessionPath -SessionRoot $SessionRoot -CombinationPath $CombinationPath |
    ConvertTo-Json -Depth 16
