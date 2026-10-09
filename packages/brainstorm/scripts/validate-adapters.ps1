[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'adapter-common.ps1')

Get-AdapterCatalogValidation | ConvertTo-Json -Depth 16
