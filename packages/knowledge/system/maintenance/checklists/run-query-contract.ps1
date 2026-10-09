[CmdletBinding()]
param([string]$Root = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$failures = New-Object System.Collections.Generic.List[string]

function Require-Text([string]$RelativePath, [string[]]$Tokens) {
    $path = Join-Path $rootPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing file: $RelativePath"); return }
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    foreach ($token in $Tokens) {
        if (-not $text.Contains($token)) { $failures.Add("${RelativePath}: missing token $token") }
    }
}

if (Test-Path -LiteralPath (Join-Path $rootPath 'agents')) { $failures.Add('Published package must not contain agents/.') }
Require-Text 'system/protocols/RUNTIME_ROUTING.md' @('QUERY_PROTOCOL.md', 'INGEST_PROTOCOL.md')
Require-Text 'system/protocols/QUERY_PROTOCOL.md' @('query-evidence.mjs', 'raw', 'Wiki')
Require-Text 'system/maintenance/checklists/knowledge-health-check.md' @('raw', 'Wiki', 'Query')

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Query contract: PASS'
