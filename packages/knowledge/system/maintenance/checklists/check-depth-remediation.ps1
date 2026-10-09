[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string[]]$RawPath = @(),
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function U {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function Get-TableRows {
    param([string]$Body, [string[]]$Columns)
    $lines = @($Body -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 })
    $header = @($lines | Where-Object { $_.TrimStart().StartsWith('|') } | Select-Object -First 1)
    if ($header.Count -ne 1) { throw 'missing matrix header' }
    foreach ($column in $Columns) { if (-not $header[0].Contains($column)) { throw "missing column: $column" } }
    $rows = @($lines | Where-Object { $_.TrimStart().StartsWith('|') -and $_ -ne $header[0] -and $_ -notmatch '^\s*\|\s*:?-{3,}' })
    if ($rows.Count -eq 0) { throw 'no matrix row' }
    $parsed = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne $Columns.Count) { throw 'invalid matrix column count' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell)) { throw 'blank matrix cell' }
            if ($cell -match '^(?:\u662f|\u5426|\u65e0|N/?A|-)$') { throw 'non-specific matrix evidence marker' }
        }
        [void]$parsed.Add(@($cells))
    }
    return @($parsed.ToArray())
}

try {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    $heading = U '# \u6df1\u5ea6\u8986\u76d6\u56de\u8bfb\u8865\u5ba1'
    $matrixHeading = U '## \u9010\u7ae0\u56de\u8bfb\u77e9\u9635'
    $summaryHeading = U '## \u5355\u7bc7\u7ed3\u8bba'
    $marker = 'DEPTH_REREAD_REMEDIATION_V1'
    if (-not $text.StartsWith($heading, [StringComparison]::Ordinal)) { throw 'missing exact remediation heading' }
    $matrixSection = [regex]::Match($text, '(?ms)^' + [regex]::Escape($matrixHeading) + '\s*\r?\n(?<body>.*?)(?=^##\s|\z)')
    if (-not $matrixSection.Success) { throw 'missing reread matrix section' }
    if ($matrixSection.Groups['body'].Value.IndexOf($marker, [StringComparison]::Ordinal) -lt 0) { throw "missing $marker" }
    $matrixBody = $matrixSection.Groups['body'].Value.Substring(0, $matrixSection.Groups['body'].Value.IndexOf($marker, [StringComparison]::Ordinal)).TrimEnd()
    $columns = @('raw', (U '\u539f\u6587\u6838\u5fc3\u7ae0\u8282'), (U '\u539f\u6587\u4f4d\u7f6e'), (U '\u8bba\u8bc1\u94fe'), (U '\u5b9a\u4e49'), (U '\u63a8\u5bfc'), (U '\u6848\u4f8b'), (U '\u5f15\u7528\u6216\u6570\u636e'), ('raw ' + (U '\u5bf9\u5e94\u4f4d\u7f6e')), (U '\u8986\u76d6\u5224\u5b9a'))
    $matrixRows = @(Get-TableRows -Body $matrixBody -Columns $columns)
    $summarySection = [regex]::Match($text, '(?ms)^' + [regex]::Escape($summaryHeading) + '\s*\r?\n(?<body>.*?)(?=^##\s|\z)')
    if (-not $summarySection.Success) { throw 'missing per-raw conclusion section' }
    $summaryColumns = @('raw', (U '\u6b63\u6587\u5b8c\u6574\u6027\u7ed3\u8bba'), (U '\u540e\u7eed\u5904\u7f6e'))
    $summaryRows = @(Get-TableRows -Body $summarySection.Groups['body'].Value -Columns $summaryColumns)
    $matrixRawPaths = @($matrixRows | ForEach-Object { [string]$_[0] } | Select-Object -Unique)
    $summaryRawPaths = @($summaryRows | ForEach-Object { [string]$_[0] } | Select-Object -Unique)
    $expectedRawPaths = @($RawPath | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\\', '/') } | Where-Object { $_ -ne '' })
    foreach ($raw in $expectedRawPaths) {
        if ($matrixRawPaths -notcontains $raw) { throw "raw is absent from reread matrix: $raw" }
        if ($summaryRawPaths -notcontains $raw) { throw "raw is absent from per-raw conclusions: $raw" }
    }
    foreach ($raw in $matrixRawPaths) { if ($expectedRawPaths.Count -gt 0 -and $expectedRawPaths -notcontains $raw) { throw "unexpected raw in reread matrix: $raw" } }
    $requiresRewrite = $false
    foreach ($row in $matrixRows) {
        $verdict = [string]$row[9]
        if ($verdict -notmatch (U '^(?:\u5df2\u8986\u76d6|\u53d1\u73b0\u9057\u6f0f\uff0c\u9700\u6269\u5199|\u5b58\u7591\u5f85\u4eba\u5de5\u5224\u65ad)')) { throw "invalid coverage verdict: $verdict" }
        if ($verdict -match (U '\u53d1\u73b0\u9057\u6f0f|\u5b58\u7591')) { $requiresRewrite = $true }
    }
    foreach ($row in $summaryRows) {
        $verdict = [string]$row[1]
        if ($verdict -notmatch (U '^(?:\u6b63\u6587\u5145\u5206|\u9700\u5c40\u90e8\u6269\u5199|\u5b58\u7591\u5f85\u4eba\u5de5\u5224\u65ad)')) { throw "invalid body conclusion: $verdict" }
        if ($verdict -notmatch (U '^\u6b63\u6587\u5145\u5206')) { $requiresRewrite = $true }
    }
    $result = [pscustomobject][ordered]@{ status = 'passed'; requires_rewrite = $requiresRewrite; raw_count = $summaryRawPaths.Count; path = $full }
    if ($AsJson) { Write-Output ($result | ConvertTo-Json -Compress) } else { Write-Output ('PASS: ' + $full + '; requires_rewrite=' + $requiresRewrite) }
} catch {
    [Console]::Error.WriteLine("DEPTH_REMEDIATION_CHECK_FAILED: $($_.Exception.Message)")
    exit 2
}
