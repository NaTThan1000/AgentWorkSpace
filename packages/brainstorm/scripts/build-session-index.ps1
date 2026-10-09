[CmdletBinding()]
param(
    [string]$SessionRoot = '',
    [string]$OutputPath = '',
    [string]$BudgetConfigPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'session-common.ps1')

if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = Join-Path (Get-BrainstormProjectRoot) 'workspace\sessions'
}
$SessionRoot = [IO.Path]::GetFullPath($SessionRoot)
Write-SessionIndex -SessionRoot $SessionRoot -OutputPath $OutputPath -BudgetConfigPath $BudgetConfigPath |
    ConvertTo-Json -Depth 16
