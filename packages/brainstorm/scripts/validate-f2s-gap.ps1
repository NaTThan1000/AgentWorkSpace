# Compatibility entrypoint for callers before 1.1.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$GapPath = '',
    [string]$BriefPath = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'validate-fromdemotospec-gap.ps1') @PSBoundParameters
