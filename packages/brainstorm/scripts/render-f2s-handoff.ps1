# Compatibility entrypoint for callers before 1.1.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [string]$SessionRoot = '',
    [string]$GapPath = '',
    [string]$BriefPath = '',
    [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'render-fromdemotospec-handoff.ps1') @PSBoundParameters
