# Compatibility entrypoint for callers before 1.1.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SessionPath,
    [Parameter(Mandatory = $true)][string]$ArtifactId,
    [Parameter(Mandatory = $true)][string]$F2sFeedbackPath,
    [string]$SessionRoot = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'import-fromdemotospec-learning-feedback.ps1') @PSBoundParameters
