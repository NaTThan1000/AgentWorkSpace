param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path,

  [ValidateRange(0, 99)]
  [int]$MaxPlainSections = 0,

  [ValidateRange(40, 1000)]
  [int]$MaxCompactParagraphChars = 140,

  [ValidateRange(80, 3000)]
  [int]$MaxCompactSectionChars = 280
)

$failed = $false
$annotationHeading = '## ' + [char]0x6279 + [char]0x6CE8
$normalizedPaths = @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($normalizedPaths.Count -eq 0) {
  Write-Error 'raw-style requires at least one path.'
  exit 1
}

foreach ($item in $normalizedPaths) {
  $text = Get-Content -LiteralPath $item -Encoding utf8 -Raw
  $lines = @($text -split "\r?\n")
  $heads = @()
  $mediaContractFailed = $false

  $hasMediaCallout = $text -match '(?m)^>\s*\[!\u5a92\u4f53(?:\u964d\u7ea7|\u8bf4\u660e)\]'
  $hasFixedMediaMarker = $text -match '\u539f\u6587\u542b\u4fe1\u606f\u56fe\u7247\uff0c\u672a\u8f6c\u5f55'
  if ($hasMediaCallout -and -not $hasFixedMediaMarker) {
    Write-Error ('raw-style media callout misses the source-content fixed marker: ' + $item)
    $failed = $true
    $mediaContractFailed = $true
  }

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^## ') {
      $heads += $i
    }
  }

  $contentHeads = @()
  foreach ($head in $heads) {
    if ($lines[$head] -eq $annotationHeading) {
      continue
    }

    $end = $lines.Count - 1
    $next = @($heads | Where-Object { $_ -gt $head } | Select-Object -First 1)
    if ($next.Count -gt 0) {
      $end = $next[0] - 1
    }

    $body = @()
    if (($head + 1) -le $end) {
      $body = @($lines[($head + 1)..$end])
    }

    if ($body -match 'RAW_DEPTH_AUDIT_V1') {
      continue
    }

    $contentHeads += [PSCustomObject]@{
      Title = $lines[$head]
      Body = $body
    }
  }

  if ($contentHeads.Count -eq 0) {
    Write-Error ('raw-style check found no content section: ' + $item)
    $failed = $true
    continue
  }

  $plain = @()
  $carrierSections = 0
  $compactProseSections = 0
  foreach ($section in $contentHeads) {
    $nonBlank = @($section.Body | Where-Object { $_.Trim().Length -gt 0 })
    $hasLocation = $nonBlank.Count -gt 0 -and $nonBlank[0].TrimStart().StartsWith('>')
    $hasScanCarrier = @($section.Body | Where-Object {
      $_ -match '^### ' -or
      $_ -match '^\s*(?:[-*]\s+|\d+[.)]\s+)' -or
      $_ -match '^\|.*\|\s*$'
    }).Count -gt 0
    $paragraphs = New-Object System.Collections.Generic.List[string]
    $paragraphLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $section.Body) {
      $trimmed = $line.Trim()
      if ($trimmed.Length -eq 0) {
        if ($paragraphLines.Count -gt 0) {
          [void]$paragraphs.Add(($paragraphLines.ToArray() -join ''))
          $paragraphLines.Clear()
        }
        continue
      }
      if ($trimmed.StartsWith('>') -or $trimmed -match '^(?:#{1,6}\s+|[-*]\s+|\d+[.)]\s+|\||```|~~~)') {
        if ($paragraphLines.Count -gt 0) {
          [void]$paragraphs.Add(($paragraphLines.ToArray() -join ''))
          $paragraphLines.Clear()
        }
        continue
      }
      [void]$paragraphLines.Add($trimmed)
    }
    if ($paragraphLines.Count -gt 0) {
      [void]$paragraphs.Add(($paragraphLines.ToArray() -join ''))
    }
    $paragraphLengths = @($paragraphs | ForEach-Object { $_.Length })
    $paragraphChars = 0
    foreach ($length in $paragraphLengths) { $paragraphChars += $length }
    $hasCompactParagraphStructure = (
      $paragraphs.Count -ge 1 -and
      @($paragraphLengths | Where-Object { $_ -gt $MaxCompactParagraphChars }).Count -eq 0 -and
      $paragraphChars -le $MaxCompactSectionChars
    )

    if (-not $hasLocation) {
      Write-Error ('raw-style location marker missing: ' + $item + ' :: ' + $section.Title)
      $failed = $true
    }

    if ($hasScanCarrier) {
      $carrierSections++
    } elseif ($hasCompactParagraphStructure) {
      $compactProseSections++
    } else {
      $plain += $section.Title
    }
  }

  if ($plain.Count -gt $MaxPlainSections) {
    Write-Error ('raw-style has too many plain sections (' + $plain.Count + '/' + $contentHeads.Count + '): ' + $item + ' :: ' + ($plain -join ' | '))
    $failed = $true
  } elseif (-not $mediaContractFailed) {
    Write-Output ('PASS: ' + $item + ' (' + $contentHeads.Count + ' content section(s), ' + $carrierSections + ' carrier section(s), ' + $compactProseSections + ' compact prose section(s), ' + $plain.Count + ' plain section(s))')
  }
}

if ($failed) { exit 1 }
