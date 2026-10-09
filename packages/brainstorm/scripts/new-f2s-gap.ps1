# Compatibility entrypoint for callers before 1.1.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$BriefPath = '',
    [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'new-fromdemotospec-gap.ps1') @PSBoundParameters
