[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

node (Join-Path $PSScriptRoot 'game-analysis-adapter.contract.mjs')
if ($LASTEXITCODE -ne 0) { throw "Game-analysis adapter contract failed with exit code $LASTEXITCODE." }
