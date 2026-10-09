[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$BudgetConfigPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'session-common.ps1')

Get-SessionValidation -SessionPath $SessionPath -SessionRoot $SessionRoot -BudgetConfigPath $BudgetConfigPath |
    ConvertTo-Json -Depth 16
