[CmdletBinding()]
param(
    [ValidateSet('Sync', 'Check')]
    [string]$Mode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))

function Convert-UnicodeLiteral {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function Read-Utf8File {
    param([string]$RelativePath)
    $path = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing file: $RelativePath" }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $path
}

function Get-SourceCount {
    param([string]$WikiContent)
    $frontmatter = [regex]::Match($WikiContent, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { throw 'Wiki missing frontmatter.' }
    $sources = [regex]::Match($frontmatter.Groups['body'].Value, '(?ms)^sources:\s*\r?\n(?<items>(?:[ \t]+-\s+.*\r?\n?)+)')
    if (-not $sources.Success) { throw 'Wiki missing sources list.' }
    return @([regex]::Matches($sources.Groups['items'].Value, '(?m)^[ \t]+-\s+\S.*$')).Count
}

function Get-Basis {
    param([hashtable]$Risk, [int]$SoftThreshold, [int]$SourceThreshold)
    $lineLabel = Convert-UnicodeLiteral '\u884c'
    $sourceLabel = Convert-UnicodeLiteral '\u6765\u6e90'
    $sourceCountLabel = Convert-UnicodeLiteral '\u6765\u6e90\u6570'
    $reachesLabel = Convert-UnicodeLiteral '\u8fbe\u5230'
    $comma = Convert-UnicodeLiteral '\uff0c'
    $assessmentLabel = Convert-UnicodeLiteral '\u62c6\u5206\u8bc4\u4f30\u7ebf'
    if ($Risk.LineTriggered -and $Risk.SourceTriggered) {
        return "$($Risk.Sources) $sourceLabel$comma$reachesLabel $SoftThreshold $lineLabel / $sourceCountLabel $SourceThreshold $assessmentLabel"
    }
    if ($Risk.LineTriggered) { return "$reachesLabel $SoftThreshold $lineLabel$assessmentLabel" }
    return "$($Risk.Sources) $sourceLabel$comma$reachesLabel$sourceCountLabel$assessmentLabel"
}

function Get-Closure {
    param([string]$ExistingClosure, [hashtable]$Risk)
    $sourceReorganization = Convert-UnicodeLiteral '\u6765\u6e90\u91cd\u7ec4'
    $defaultClosure = Convert-UnicodeLiteral '\u5f85\u8865\u5145\u4eba\u5de5\u62c6\u5206\u5224\u65ad\uff1b\u540e\u7eed\u901a\u8fc7\u6765\u6e90\u91cd\u7ec4\u6216\u5f62\u6210\u72ec\u7acb\u5b50\u9898\u518d\u590d\u6838\u3002'
    $closure = $ExistingClosure.Trim()
    if ([string]::IsNullOrWhiteSpace($closure)) { $closure = $defaultClosure }
    if ($Risk.SourceTriggered -and -not $closure.Contains($sourceReorganization)) {
        $suffix = Convert-UnicodeLiteral '\u540e\u7eed\u65b0\u589e\u540c\u7c7b\u6765\u6e90\u524d\u901a\u8fc7\u6765\u6e90\u91cd\u7ec4\u6216\u5f62\u6210\u72ec\u7acb\u5b50\u9898\u518d\u590d\u6838\u3002'
        $closure = $closure.TrimEnd([char[]]@([char]0x3002, ';', [char]0xff1b)) + [char]0x3002 + $suffix
    }
    return $closure
}

try {
    $wikiRules = Read-Utf8File 'wiki/README.md'
    $statusPath = Join-Path $projectRoot 'system/registry/KNOWLEDGE_STATUS.md'
    $status = Read-Utf8File 'system/registry/KNOWLEDGE_STATUS.md'
    $lineCountLabel = Convert-UnicodeLiteral '\u884c\u6570'
    $sourceCountLabel = Convert-UnicodeLiteral '\u6765\u6e90\u6570'
    $mustSplitLabel = Convert-UnicodeLiteral '\u5fc5\u987b\u62c6\u5206'
    $thresholdPattern = '(?m)^\|\s*' + [regex]::Escape($lineCountLabel) + '\s*\u2265\s*(?<threshold>\d+)(?<condition>[^|]*)\|\s*(?<action>[^|]+)\|'
    $thresholds = @([regex]::Matches($wikiRules, $thresholdPattern))
    $sourceThresholdRow = @($thresholds | Where-Object { $_.Groups['condition'].Value.Contains($sourceCountLabel) })
    $hardThresholdRow = @($thresholds | Where-Object { $_.Groups['action'].Value.Contains($mustSplitLabel) })
    if ($sourceThresholdRow.Count -ne 1 -or $hardThresholdRow.Count -ne 1) { throw 'Cannot derive exactly one soft/source and hard capacity threshold.' }
    $softThreshold = [int]$sourceThresholdRow[0].Groups['threshold'].Value
    $sourceMatch = [regex]::Match($sourceThresholdRow[0].Groups['condition'].Value, [regex]::Escape($sourceCountLabel) + '\s*\u2265\s*(?<threshold>\d+)')
    if (-not $sourceMatch.Success) { throw 'Cannot derive source capacity threshold.' }
    $sourceThreshold = [int]$sourceMatch.Groups['threshold'].Value

    $risks = @{}
    foreach ($wikiFile in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'wiki') -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' })) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $wikiFile.FullName
        $lines = [IO.File]::ReadAllLines($wikiFile.FullName, [Text.Encoding]::UTF8).Count
        $sources = Get-SourceCount $content
        if ($lines -ge $softThreshold -or $sources -ge $sourceThreshold) {
            $risks[$wikiFile.BaseName] = @{ Lines = $lines; Sources = $sources; LineTriggered = $lines -ge $softThreshold; SourceTriggered = $sources -ge $sourceThreshold }
        }
    }

    $contentHealthHeading = Convert-UnicodeLiteral '\u4e09\u3001\u5185\u5bb9\u5065\u5eb7'
    $capacityRiskHeading = Convert-UnicodeLiteral '\u5bb9\u91cf\u98ce\u9669'
    $healthSection = [regex]::Match($status, '(?ms)^##\s+' + [regex]::Escape($contentHealthHeading) + '\s*\r?\n(?<body>.*?)(?=^##\s|\z)')
    if (-not $healthSection.Success) { throw 'Missing content-health section.' }
    $capacitySection = [regex]::Match($healthSection.Groups['body'].Value, '(?ms)^###\s+' + [regex]::Escape($capacityRiskHeading) + '\s*\r?\n(?<body>.*?)(?=^###\s|\z)')
    if (-not $capacitySection.Success) { throw 'Missing capacity-risk section.' }

    $rowPattern = '^\|\s*`(?<title>[^`]+)`\s*\|\s*(?<lines>\d+)\s*\|\s*(?<basis>[^|]*)\|\s*(?<closure>[^|]*)\|\s*$'
    $sectionLines = [System.Collections.Generic.List[string]]@(($capacitySection.Groups['body'].Value -split '\r?\n'))
    $seen = @{}
    $lastRowIndex = -1
    $changes = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $sectionLines.Count; $index++) {
        $match = [regex]::Match($sectionLines[$index], $rowPattern)
        if (-not $match.Success) { continue }
        $title = $match.Groups['title'].Value.Trim()
        if (-not $risks.ContainsKey($title)) {
            [void]$changes.Add("remove:$title")
            $sectionLines.RemoveAt($index)
            $index--
            continue
        }
        $lastRowIndex = $index
        $risk = $risks[$title]
        $canonical = '| `' + $title + '` | ' + $risk.Lines + ' | ' + (Get-Basis -Risk $risk -SoftThreshold $softThreshold -SourceThreshold $sourceThreshold) + ' | ' + (Get-Closure -ExistingClosure $match.Groups['closure'].Value -Risk $risk) + ' |'
        $seen[$title] = $true
        if ($sectionLines[$index] -ne $canonical) {
            [void]$changes.Add("update:$title")
            $sectionLines[$index] = $canonical
        }
    }
    if ($lastRowIndex -lt 0) {
        # A zero-library table is valid. Its separator is the insertion boundary for the first risk.
        for ($tableIndex = 0; $tableIndex -lt $sectionLines.Count; $tableIndex++) {
            if ($sectionLines[$tableIndex] -match '^\|[-:| ]+\|$') { $lastRowIndex = $tableIndex; break }
        }
        if ($lastRowIndex -lt 0) { throw 'Capacity-risk section has no valid table header.' }
    }
    $missing = @($risks.Keys | Where-Object { -not $seen.ContainsKey($_) } | Sort-Object)
    $offset = 0
    foreach ($title in $missing) {
        $risk = $risks[$title]
        $canonical = '| `' + $title + '` | ' + $risk.Lines + ' | ' + (Get-Basis -Risk $risk -SoftThreshold $softThreshold -SourceThreshold $sourceThreshold) + ' | ' + (Get-Closure -ExistingClosure '' -Risk $risk) + ' |'
        $sectionLines.Insert($lastRowIndex + 1 + $offset, $canonical)
        $offset++
        [void]$changes.Add("add:$title")
    }
    $newBody = $sectionLines -join "`n"
    # capacitySection is matched inside healthSection.Body, so its group offset is relative.
    # Convert it to an absolute offset before replacing the file-level text.
    $capacityBodyStart = $healthSection.Groups['body'].Index + $capacitySection.Groups['body'].Index
    $expected = $status.Substring(0, $capacityBodyStart) + $newBody + $status.Substring($capacityBodyStart + $capacitySection.Groups['body'].Length)

    if ($Mode -eq 'Check') {
        if ($expected -ne $status) {
            throw ('Capacity-risk status is stale (' + ($changes -join ', ') + '). Run sync-capacity-risks.ps1 -Mode Sync before staging.')
        }
        Write-Output ([pscustomobject][ordered]@{ status = 'passed'; mode = 'Check'; required = $risks.Count; changes = @() } | ConvertTo-Json)
        exit 0
    }

    [IO.File]::WriteAllText($statusPath, $expected, $utf8NoBom)
    Write-Output ([pscustomobject][ordered]@{ status = 'synced'; mode = 'Sync'; required = $risks.Count; changes = @($changes) } | ConvertTo-Json)
} catch {
    [Console]::Error.WriteLine("CAPACITY_RISK_SYNC_FAILED: $($_.Exception.Message)")
    exit 2
}
