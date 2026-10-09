[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PrototypeId,
    [Parameter(Mandatory = $true)][string]$PrototypeVersion,
    [Parameter(Mandatory = $true)][string]$UpstreamSession,
    [Parameter(Mandatory = $true)][string]$DecisionId,
    [string]$DemoRoot = '',
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($PrototypeId) -or $PrototypeId -match '[\r\n`/\\:]') { throw 'Invalid PrototypeId' }
if ([string]::IsNullOrWhiteSpace($PrototypeVersion) -or $PrototypeVersion -match '[\r\n`]') { throw 'Invalid PrototypeVersion' }
if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
    if (-not [string]::IsNullOrWhiteSpace($DemoRoot)) { throw 'Use ProjectPath or DemoRoot, not both' }
    $prototypePath = [IO.Path]::GetFullPath($ProjectPath)
} else {
    if ([string]::IsNullOrWhiteSpace($DemoRoot)) { $DemoRoot = Join-Path $projectRoot 'Demo' }
    $demoRootFull = [IO.Path]::GetFullPath($DemoRoot).TrimEnd([char]92, [char]47) + [IO.Path]::DirectorySeparatorChar
    $prototypePath = [IO.Path]::GetFullPath((Join-Path $DemoRoot $PrototypeId))
    if (-not $prototypePath.StartsWith($demoRootFull, [StringComparison]::OrdinalIgnoreCase)) { throw 'Prototype path escaped DemoRoot.' }
}
if (-not (Test-Path -LiteralPath $prototypePath -PathType Container)) { throw "Prototype directory does not exist: $prototypePath" }
if ($DecisionId -notmatch '^DEC-[0-9]{3,}$') { throw "Invalid upstream DecisionId: $DecisionId" }
if ($UpstreamSession -notmatch '^bs-[0-9]{8}-[0-9]{6}-[a-f0-9]{6}$') { throw "Invalid upstream session ID: $UpstreamSession" }
$outputPath = Join-Path $prototypePath 'agent-learning-feedback.md'
if (Test-Path -LiteralPath $outputPath) { throw "Learning feedback already exists: $outputPath" }
$templatePath = Join-Path $projectRoot 'templates\agent-learning-feedback.md'
$utf8 = New-Object Text.UTF8Encoding($false)
$content = [IO.File]::ReadAllText($templatePath, $utf8)
$content = $content.Replace('{{PROTOTYPE_ID}}', $PrototypeId).Replace('{{PROTOTYPE_VERSION}}', $PrototypeVersion).Replace('{{UPSTREAM_SESSION}}', $UpstreamSession).Replace('{{DECISION_ID}}', $DecisionId).Replace('{{CREATED_AT}}', (Get-Date).ToUniversalTime().ToString('o'))
[IO.File]::WriteAllText($outputPath, $content, $utf8)
[pscustomobject][ordered]@{ created = $true; feedback_path = $outputPath; knowledge_write = $false; status = 'draft' } | ConvertTo-Json -Depth 8
