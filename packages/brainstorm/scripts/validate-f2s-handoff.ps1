# Compatibility entrypoint for callers before 1.1.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$GapPath = '',
    [string]$BriefPath = '',
    [string]$HandoffPath = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'validate-fromdemotospec-handoff.ps1') @PSBoundParameters
