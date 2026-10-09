[CmdletBinding()]
param(
    [string]$ProjectRoot = '',
    [string]$SessionPath = '',
    [string]$SessionRoot = '',
    [string]$ArtifactPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'playbook-common.ps1')

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $script:BrainstormPlaybookProjectRoot
}

if (-not [string]::IsNullOrWhiteSpace($SessionPath) -or -not [string]::IsNullOrWhiteSpace($ArtifactPath)) {
    Assert-PlaybookContract -Condition (-not [string]::IsNullOrWhiteSpace($SessionPath) -and -not [string]::IsNullOrWhiteSpace($ArtifactPath)) -Message 'Opportunity validation requires SessionPath and ArtifactPath together.'
    . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'session-common.ps1')
    Get-OpportunityThesisValidation -SessionPath $SessionPath -SessionRoot $SessionRoot -ArtifactPath $ArtifactPath | ConvertTo-Json -Depth 16
} else {
    Get-PlaybookCatalogValidation -ProjectRoot $ProjectRoot | ConvertTo-Json -Depth 16
}
