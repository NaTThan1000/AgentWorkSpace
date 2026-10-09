[CmdletBinding()]
param([string]$Root = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$failures = New-Object System.Collections.Generic.List[string]
$scriptFiles = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Filter '*.ps1')
$desktopOnlyMarker = '#requires -PSEdition ' + 'Desktop'

foreach ($file in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        $relative = $file.FullName.Substring($rootPath.Length).TrimStart([char]0x5C, [char]0x2F)
        $failures.Add("PowerShell parse error in ${relative}: $($parseError.Message)")
    }
    $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    if ($text.Contains($desktopOnlyMarker)) {
        $failures.Add("Desktop-only PowerShell requirement: $($file.Name)")
    }
}

$defaultRootScripts = @(
    'system/maintenance/initialize-knowledge.ps1',
    'system/maintenance/setup-wizard.ps1',
    'system/maintenance/checklists/check-raw-depth.ps1',
    'system/maintenance/checklists/check-depth-remediation.ps1',
    'system/maintenance/checklists/audit-ingest-depth-history.ps1',
    'system/maintenance/checklists/check-raw-style.ps1',
    'system/maintenance/checklists/content-backtest.ps1',
    'system/maintenance/checklists/source-content-audit.ps1',
    'system/maintenance/checklists/source-audit-vnext.ps1',
    'system/maintenance/checklists/ingest-control.ps1',
    'system/maintenance/checklists/render-ingest-package.ps1',
    'system/maintenance/checklists/prepare-ingest-context.ps1',
    'system/maintenance/checklists/clippings-path-resolver.ps1',
    'system/maintenance/checklists/run-ingest-maintenance.ps1',
    'system/maintenance/checklists/sync-capacity-risks.ps1',
    'system/maintenance/checklists/verify-wiki-split.ps1',
    'system/maintenance/checklists/run-query-contract.ps1',
    'system/maintenance/checklists/run-release-contract.ps1',
    'system/maintenance/checklists/run-platform-contract.ps1'
)
foreach ($relative in $defaultRootScripts) {
    $path = Join-Path $rootPath $relative
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $paramTokens = $null; $paramErrors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$paramTokens, [ref]$paramErrors)
    $paramSection = if ($null -eq $scriptAst.ParamBlock) { '' } else { $scriptAst.ParamBlock.Extent.Text }
    if ($paramSection.Contains('$PSScriptRoot')) { $failures.Add("Script must not evaluate PSScriptRoot in param(): $relative") }
}

$initializerPath = Join-Path $rootPath 'system/maintenance/initialize-knowledge.ps1'
if (Test-Path -LiteralPath $initializerPath) {
    $initializer = [IO.File]::ReadAllText($initializerPath, [Text.Encoding]::UTF8)
    foreach ($token in @(
        'portableInvalidNameChars',
        'system/maintenance/initialize-knowledge.ps1',
        'system/integrations/ima-config.local.json',
        'DirectorySeparatorChar',
        'OrdinalIgnoreCase'
    )) {
        if (-not $initializer.Contains($token)) { $failures.Add("Portable initializer token missing: $token") }
    }
    foreach ($forbidden in @('system\maintenance\initialize-knowledge.ps1', 'system\integrations\ima-config.local.json')) {
        if ($initializer.Contains($forbidden)) { $failures.Add("Platform-specific path literal remains in initializer: $forbidden") }
    }
}

$setupPath = Join-Path $rootPath 'system/maintenance/SETUP.md'
if (Test-Path -LiteralPath $setupPath) {
    $setup = [IO.File]::ReadAllText($setupPath, [Text.Encoding]::UTF8)
    foreach ($token in @('macOS', 'pwsh', './system/maintenance/setup-wizard.ps1', 'PowerShell 7')) {
        if (-not $setup.Contains($token)) { $failures.Add("SETUP.md missing cross-platform token: $token") }
    }
}

if ($failures.Count -gt 0) {
    $failures | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Platform contract: PASS ($($scriptFiles.Count) PowerShell scripts)"
