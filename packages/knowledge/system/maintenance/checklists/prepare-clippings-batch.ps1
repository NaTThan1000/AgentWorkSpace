[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReviewPath,
    [Parameter(Mandatory = $true)][string]$Topic,
    [Parameter(Mandatory = $true)][ValidateRange(1, 999)][int]$BatchNumber,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-FullPath {
    param([string]$Path, [switch]$MustExist)
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $Path)) }
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $Path" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
    return $full
}

function Get-TitleKey {
    param([string]$Value)
    return ([regex]::Replace($Value.Trim().ToLowerInvariant(), '[\p{P}\p{Z}\p{Cf}\p{S}]', ''))
}

function Assert-UsableClipping {
    param([string]$Path)
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -eq 0) { throw "Clippings batch item is empty: $($file.Name)" }
    $head = @(Get-Content -Encoding UTF8 -LiteralPath $Path -TotalCount 20) -join "`n"
    if ($head -match '(?m)^capture_status:\s*missing\s*$') { throw "Clippings batch item needs source recovery: $($file.Name)" }
}

$reviewFull = Get-FullPath -Path $ReviewPath -MustExist
$outputFull = Get-FullPath -Path $OutputPath
$reviewText = (Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewFull).Replace("`r`n", "`n")
$declaredCount = -1
$titles = New-Object System.Collections.Generic.List[string]

$topicMatches = @([regex]::Matches($reviewText, '(?m)^###(?!#)\s+(?<heading>[^\n]+?)\s*$') | ForEach-Object { $_ })
$selectedTopicIndex = -1
for ($index = 0; $index -lt $topicMatches.Count; $index++) {
    $heading = $topicMatches[$index].Groups['heading'].Value.Trim()
    $normalized = ([regex]::Replace($heading, '\s*[\(\uFF08]\d+\s*\u7BC7[\)\uFF09]\s*$', '')).Trim()
    if ($normalized -eq $Topic) {
        if ($selectedTopicIndex -ge 0) { throw "Clippings topic is ambiguous: $Topic" }
        $selectedTopicIndex = $index
    }
}

if ($selectedTopicIndex -lt 0) { throw "Clippings topic was not found: $Topic" }
$topicStart = $topicMatches[$selectedTopicIndex].Index + $topicMatches[$selectedTopicIndex].Length
$topicEnd = if ($selectedTopicIndex + 1 -lt $topicMatches.Count) { $topicMatches[$selectedTopicIndex + 1].Index } else { $reviewText.Length }
$topicBody = $reviewText.Substring($topicStart, $topicEnd - $topicStart)
$batchMatches = @([regex]::Matches($topicBody, '(?m)^####\s+(?<heading>[^\n]+?)\s*$') | ForEach-Object { $_ })
$selectedBatchIndex = -1
for ($index = 0; $index -lt $batchMatches.Count; $index++) {
    $numberMatch = [regex]::Match($batchMatches[$index].Groups['heading'].Value, '^\u7B2C\s*(?<number>\d+)\s*\u6279(?:\s*[:\uFF1A]|\s|$)')
    if ($numberMatch.Success -and [int]$numberMatch.Groups['number'].Value -eq $BatchNumber) {
        if ($selectedBatchIndex -ge 0) { throw "Clippings batch is ambiguous: topic='$Topic' batch=$BatchNumber" }
        $selectedBatchIndex = $index
    }
}
if ($selectedBatchIndex -lt 0) { throw "Clippings batch was not found: topic='$Topic' batch=$BatchNumber" }
$batchHeading = $batchMatches[$selectedBatchIndex].Groups['heading'].Value
$countMatch = [regex]::Match($batchHeading, '[\(\uFF08](?<count>\d+)\s*(?:\u7BC7)?[\)\uFF09]')
if ($countMatch.Success) { $declaredCount = [int]$countMatch.Groups['count'].Value }
$batchStart = $batchMatches[$selectedBatchIndex].Index + $batchMatches[$selectedBatchIndex].Length
$batchEnd = if ($selectedBatchIndex + 1 -lt $batchMatches.Count) { $batchMatches[$selectedBatchIndex + 1].Index } else { $topicBody.Length }
$batchBody = $topicBody.Substring($batchStart, $batchEnd - $batchStart)
foreach ($itemMatch in @([regex]::Matches($batchBody, '(?m)^\s*-\s+(?<title>[^\n]+?)\s*$') | ForEach-Object { $_ })) {
    [void]$titles.Add($itemMatch.Groups['title'].Value.Trim())
}

if ($titles.Count -eq 0) { throw "Clippings batch has no items: topic='$Topic' batch=$BatchNumber" }
if ($declaredCount -ge 0 -and $declaredCount -ne $titles.Count) {
    throw "Clippings batch declared count does not match bullets: declared=$declaredCount actual=$($titles.Count)"
}

$titleIndex = @{}
foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Clippings') -Filter '*.md' -File | Where-Object { $_.Name -match '^\d{8}-' })) {
    $keys = New-Object System.Collections.Generic.List[string]
    [void]$keys.Add((Get-TitleKey -Value ($file.BaseName -replace '^\d{8}-', '')))
    $head = @(Get-Content -Encoding UTF8 -LiteralPath $file.FullName -TotalCount 20) -join "`n"
    $titleMatch = [regex]::Match($head, '(?m)^title:\s*["'']?(?<title>.*?)["'']?\s*$')
    if ($titleMatch.Success) { [void]$keys.Add((Get-TitleKey -Value $titleMatch.Groups['title'].Value.Trim('"', "'"))) }
    foreach ($key in @($keys | Select-Object -Unique)) {
        if (-not $titleIndex.ContainsKey($key)) { $titleIndex[$key] = New-Object System.Collections.Generic.List[string] }
        [void]$titleIndex[$key].Add(('Clippings/' + $file.Name))
    }
}

$items = New-Object System.Collections.Generic.List[string]
foreach ($title in $titles) {
    $key = Get-TitleKey -Value $title
    if (-not $titleIndex.ContainsKey($key)) { throw "Clippings batch item has no canonical file: $title" }
    $matches = @($titleIndex[$key] | Select-Object -Unique)
    if ($matches.Count -ne 1) { throw "Clippings batch item is ambiguous: $title -> $($matches -join ', ')" }
    Assert-UsableClipping -Path (Join-Path $projectRoot $matches[0])
    [void]$items.Add($matches[0])
}

$parent = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$json = @(($items.ToArray() | ConvertTo-Json) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
[IO.File]::WriteAllText($outputFull, $json + "`n", $utf8NoBom)
Write-Output ([pscustomobject][ordered]@{ status = 'prepared'; topic = $Topic; batch = $BatchNumber; count = $items.Count; output_path = $OutputPath; items = $items.ToArray() } | ConvertTo-Json -Depth 10)
exit 0
