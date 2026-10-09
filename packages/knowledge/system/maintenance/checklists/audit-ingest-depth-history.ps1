[CmdletBinding()]
param(
    [string]$RunsRoot = 'system/maintenance/ingest-runs',
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$safeProject = $projectRoot.Replace('\', '/')

function U {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

$heading = U '### \u8986\u76d6\u81ea\u68c0\uff08\u7f16\u5199\u89c4\u5219 #7\uff09'
$marker = 'RAW_DEPTH_AUDIT_V1'
$columns = @((U '\u539f\u6587\u6838\u5fc3\u7ae0\u8282'), (U '\u539f\u6587\u4f4d\u7f6e'), (U '\u8bba\u8bc1\u94fe'), (U '\u5b9a\u4e49'), (U '\u63a8\u5bfc'), (U '\u6848\u4f8b'), (U '\u5f15\u7528\u6216\u6570\u636e'), ('raw ' + (U '\u5bf9\u5e94\u4f4d\u7f6e')))

function Get-ProjectPath {
    param([string]$Path)
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $Path)) }
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $full" }
    return $full
}

function Test-DepthText {
    param([string]$Text)
    $section = [regex]::Match($Text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^###\s|^##\s|\z)')
    if (-not $section.Success) { return 'missing exact depth heading' }
    $body = $section.Groups['body'].Value
    $markerIndex = $body.IndexOf($marker, [StringComparison]::Ordinal)
    if ($markerIndex -lt 0) { return "missing $marker" }
    $matrix = $body.Substring(0, $markerIndex).TrimEnd()
    $lines = @($matrix -split "\r?\n" | Where-Object { $_.Trim().Length -gt 0 })
    $header = @($lines | Where-Object { $_.TrimStart().StartsWith('|') } | Select-Object -First 1)
    if ($header.Count -ne 1) { return 'missing matrix header' }
    foreach ($column in $columns) { if (-not $header[0].Contains($column)) { return "missing column: $column" } }
    $rows = @($lines | Where-Object { $_.TrimStart().StartsWith('|') -and $_ -notmatch '^\s*\|\s*:?-{3,}' -and $_ -ne $header[0] })
    if ($rows.Count -eq 0) { return 'no core-section mapping row' }
    foreach ($row in $rows) {
        $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne $columns.Count) { return 'invalid matrix column count' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell)) { return 'blank matrix cell' }
            if ($cell -match '^(?:\u662f|\u5426|\u65e0|N/?A|-)$') { return 'non-specific matrix evidence marker' }
        }
    }
    return $null
}

try {
    $runsFull = Get-ProjectPath $RunsRoot
    if (-not (Test-Path -LiteralPath $runsFull -PathType Container)) { throw "Runs root does not exist: $RunsRoot" }
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($directory in @(Get-ChildItem -LiteralPath $runsFull -Directory | Sort-Object Name)) {
        $manifestPath = Join-Path $directory.FullName 'run.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { [void]$results.Add([pscustomobject][ordered]@{ batch_id=$directory.Name; status='manual-review'; raw_count=0; failed_raw=0; reason='legacy run has no manifest' }); continue }
        $run = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
        $revision = [string]$run.commits.stage1
        $raws = @($run.artifacts | Where-Object { [string]$_.kind -eq 'raw' -and [string]$_.disposition -eq 'ingested' })
        if ([string]::IsNullOrWhiteSpace($revision) -or $raws.Count -eq 0) { [void]$results.Add([pscustomobject][ordered]@{ batch_id=$directory.Name; status='manual-review'; raw_count=$raws.Count; failed_raw=0; reason='no replayable Stage 1 revision or raw artifact mapping' }); continue }
        $issues = New-Object System.Collections.Generic.List[string]
        foreach ($raw in $raws) {
            $relative = ([string]$raw.path).Replace('\\', '/')
            $text = @(& git -c "safe.directory=$safeProject" -C $projectRoot show "$revision`:$relative" 2>$null) -join "`n"
            if ($LASTEXITCODE -ne 0) { [void]$issues.Add("${relative}: unreadable Stage 1 content"); continue }
            $issue = Test-DepthText -Text $text
            if ($null -ne $issue) { [void]$issues.Add("${relative}: $issue") }
        }
        $status = if ($issues.Count -eq 0) { 'pass' } else { 'rewrite-required' }
        [void]$results.Add([pscustomobject][ordered]@{ batch_id=$directory.Name; status=$status; raw_count=$raws.Count; failed_raw=$issues.Count; reason=($issues -join '; ') })
    }
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('# Ingest depth history audit')
    [void]$lines.Add('')
    [void]$lines.Add('Scope: replay each Stage 1 revision and validate the eight-column raw-depth matrix. rewrite-required means the historical depth evidence must be rebuilt; it does not by itself assert the raw body is wrong. manual-review means the legacy run cannot be replayed.')
    [void]$lines.Add('')
    [void]$lines.Add('| batch | result | raw | failed raw | reason |')
    [void]$lines.Add('|---|---|---:|---:|---|')
    foreach ($result in $results) { [void]$lines.Add("| $($result.batch_id) | $($result.status) | $($result.raw_count) | $($result.failed_raw) | $($result.reason) |") }
    [void]$lines.Add('')
    [void]$lines.Add(('Summary: pass=' + @($results | Where-Object { $_.status -eq 'pass' }).Count + '; rewrite-required=' + @($results | Where-Object { $_.status -eq 'rewrite-required' }).Count + '; manual-review=' + @($results | Where-Object { $_.status -eq 'manual-review' }).Count + '.'))
    $markdown = ($lines -join "`n") + "`n"
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputFull = Get-ProjectPath $OutputPath
        $parent = Split-Path -Parent $outputFull
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [IO.File]::WriteAllText($outputFull, $markdown, $utf8NoBom)
    }
    Write-Output $markdown
} catch {
    [Console]::Error.WriteLine("INGEST_DEPTH_HISTORY_AUDIT_FAILED: $($_.Exception.Message)")
    exit 2
}
