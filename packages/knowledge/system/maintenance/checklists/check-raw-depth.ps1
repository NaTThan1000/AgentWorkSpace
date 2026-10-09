param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path
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

$failed = $false
$marker = 'RAW_DEPTH_AUDIT_V1'
$heading = U '### \u8986\u76d6\u81ea\u68c0\uff08\u7f16\u5199\u89c4\u5219 #7\uff09'
$columns = @(
  (U '\u539f\u6587\u6838\u5fc3\u7ae0\u8282'), (U '\u539f\u6587\u4f4d\u7f6e'), (U '\u8bba\u8bc1\u94fe'), (U '\u5b9a\u4e49'),
  (U '\u63a8\u5bfc'), (U '\u6848\u4f8b'), (U '\u5f15\u7528\u6216\u6570\u636e'), ('raw ' + (U '\u5bf9\u5e94\u4f4d\u7f6e'))
)
$noEvidence = U '\u2014 \u539f\u6587\u65e0'

foreach ($item in @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })) {
  try {
    $text = Get-Content -LiteralPath $item -Encoding utf8 -Raw
    $section = [regex]::Match($text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^###\s|^##\s|\z)')
    if (-not $section.Success) { throw 'missing exact depth heading' }
    $body = $section.Groups['body'].Value
    $markerIndex = $body.IndexOf($marker, [StringComparison]::Ordinal)
    if ($markerIndex -lt 0) { throw "missing $marker" }
    $matrix = $body.Substring(0, $markerIndex).TrimEnd()
    if ($matrix.Length -eq 0) { throw 'coverage matrix is empty before marker' }
    $lines = @($matrix -split "\r?\n" | Where-Object { $_.Trim().Length -gt 0 })
    $header = @($lines | Where-Object { $_.TrimStart().StartsWith('|') } | Select-Object -First 1)
    if ($header.Count -ne 1) { throw 'coverage matrix header is missing' }
    foreach ($column in $columns) { if (-not $header[0].Contains($column)) { throw "coverage matrix missing required column: $column" } }
    $rows = @($lines | Where-Object { $_.TrimStart().StartsWith('|') -and $_ -notmatch '^\s*\|\s*:?-{3,}' -and $_ -ne $header[0] })
    if ($rows.Count -eq 0) { throw 'coverage matrix has no core-section row' }
    foreach ($row in $rows) {
      $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
      if ($cells.Count -ne $columns.Count) { throw "coverage matrix column count mismatch: $row" }
      for ($index = 0; $index -lt $cells.Count; $index++) {
        if ([string]::IsNullOrWhiteSpace($cells[$index])) { throw "coverage matrix has blank cell at column $($columns[$index])" }
        if ($cells[$index] -match '^(?:\u662f|\u5426|\u65e0|N/?A|-)$') { throw "coverage matrix requires concrete mapping or '$noEvidence'" }
      }
    }
    Write-Output ('PASS: ' + $item + ' (' + $rows.Count + ' mapped core section(s))')
  } catch {
    Write-Error ('raw-depth check failed: ' + $item + ' :: ' + $_.Exception.Message)
    $failed = $true
  }
}

if ($failed) { exit 1 }
