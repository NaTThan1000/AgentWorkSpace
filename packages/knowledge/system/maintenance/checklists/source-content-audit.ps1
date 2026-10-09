[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('manifest', 'template', 'apply-decisions', 'validate')]
  [string]$Action,

  # Separate multiple project-relative source paths with semicolons.
  [string]$SourcePath,
  [string]$RawPath,
  [string]$ManifestPath,
  [string]$ReviewPath,
  [string]$DecisionPath,
  [string]$ReceiptPath,

  [ValidateSet('stage1', 'backtest')]
  [string]$Mode = 'stage1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$utf8NoBom = New-Object Text.UTF8Encoding($false)
. (Join-Path $PSScriptRoot 'clippings-path-resolver.ps1')

function Write-Utf8 {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function U {
  param([string]$Value)
  return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
    param($match)
    return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
  })
}

function Write-Json {
  param([string]$Path, [object]$Value)
  $json = @(($Value | ConvertTo-Json -Depth 20) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
  Write-Utf8 -Path $Path -Text ($json + "`n")
}

function Get-ProjectPath {
  param([string]$Path, [switch]$MustExist)
  if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A required path is missing.' }
  $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $projectRoot $Path }
  $full = [IO.Path]::GetFullPath($candidate)
  $prefix = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the Knowledge project: $Path"
  }
  if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    $full = Resolve-ClippingPathMigration -ProjectRoot $projectRoot -RequestedFullPath $full
  }
  if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $Path" }
  return $full
}

function Get-RelativePath {
  param([string]$FullPath)
  return [IO.Path]::GetFullPath($FullPath).Substring(
    [IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/').Length + 1
  ).Replace('\', '/')
}

function Get-Sha256 {
  param([string]$Path)
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [IO.File]::ReadAllBytes($Path)
    return (([BitConverter]::ToString($hasher.ComputeHash($bytes))) -replace '-', '').ToLowerInvariant()
  }
  finally {
    $hasher.Dispose()
  }
}

function Get-SourcePathList {
  param([string]$Value)
  $paths = @($Value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($paths.Count -eq 0) { throw 'At least one source path is required.' }
  return $paths
}

function Read-Json {
  param([string]$Path)
  return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Add-Unit {
  param(
    [System.Collections.Generic.List[object]]$Units,
    [ref]$Sequence,
    [string]$Kind,
    [int]$StartLine,
    [int]$EndLine,
    [string]$Text,
    [string[]]$HeadingPath
  )
  $normalized = ([regex]::Replace($Text.Trim(), '\s+', ' '))
  if ([string]::IsNullOrWhiteSpace($normalized)) { return }
  $Sequence.Value++
  $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $textHash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
  $numbers = @([regex]::Matches($normalized, '(?<![\p{L}\p{N}])\d+(?:[.,]\d+)*%?') | ForEach-Object { $_.Value })
  [void]$Units.Add([pscustomobject][ordered]@{
    id = ('U{0:D4}' -f $Sequence.Value)
    kind = $Kind
    heading_path = @($HeadingPath)
    line_start = $StartLine
    line_end = $EndLine
    text = $normalized
    text_sha256 = $textHash
    numbers = @($numbers)
  })
}

function Get-SourceUnits {
  param([string]$Path)
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  $startIndex = 0
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq '---') {
        $startIndex = $i + 1
        break
      }
    }
  }

  $units = New-Object 'System.Collections.Generic.List[object]'
  $sequence = 0
  $headingLevels = @{}
  $buffer = New-Object 'System.Collections.Generic.List[string]'
  $bufferStart = 0

  for ($i = $startIndex; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    $lineNumber = $i + 1
    $markdownHeading = [regex]::Match($line, '^(?<marks>#{1,6})\s+(?<title>.+?)\s*$')
    $boldHeading = [regex]::Match($line, '^\s*\*\*(?<title>\d+(?:\.\d+)*[^*]*)\*\*\s*$')
    $isMedia = $trimmed -match '^(?:!\[[^\]]*\]\([^)]+\)|<img\b[^>]*>)'
    $isList = $line -match '^\s*(?:[-+*]\s+|\d+[.)]\s+)'
    $isTable = $line -match '^\s*\|.*\|\s*$'
    $isTableSeparator = $isTable -and $trimmed -match '^\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?$'
    $isBoundary = $trimmed.Length -eq 0 -or $trimmed -match '^---+$' -or $markdownHeading.Success -or $boldHeading.Success -or $isMedia -or $isList -or $isTable

    if ($isBoundary -and $buffer.Count -gt 0) {
      $path = @($headingLevels.GetEnumerator() | Sort-Object Name | ForEach-Object { [string]$_.Value })
      Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'paragraph' -StartLine $bufferStart -EndLine ($lineNumber - 1) -Text ($buffer -join ' ') -HeadingPath $path
      $buffer.Clear()
      $bufferStart = 0
    }

    if ($trimmed.Length -eq 0 -or $trimmed -match '^---+$' -or $isTableSeparator) { continue }

    if ($markdownHeading.Success -or $boldHeading.Success) {
      $level = if ($markdownHeading.Success) {
        $markdownHeading.Groups['marks'].Value.Length
      } else {
        $titleValue = $boldHeading.Groups['title'].Value
        if ($titleValue -match '^\d+\.\d+') { 5 } else { 4 }
      }
      $title = if ($markdownHeading.Success) { $markdownHeading.Groups['title'].Value } else { $boldHeading.Groups['title'].Value }
      foreach ($key in @($headingLevels.Keys | Where-Object { [int]$_ -ge $level })) { $headingLevels.Remove($key) }
      $headingLevels[$level] = $title
      $path = @($headingLevels.GetEnumerator() | Sort-Object Name | ForEach-Object { [string]$_.Value })
      Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'heading' -StartLine $lineNumber -EndLine $lineNumber -Text $title -HeadingPath $path
      continue
    }

    $path = @($headingLevels.GetEnumerator() | Sort-Object Name | ForEach-Object { [string]$_.Value })
    if ($isMedia) {
      Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'media' -StartLine $lineNumber -EndLine $lineNumber -Text $trimmed -HeadingPath $path
      continue
    }
    if ($isList) {
      Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'list_item' -StartLine $lineNumber -EndLine $lineNumber -Text $trimmed -HeadingPath $path
      continue
    }
    if ($isTable) {
      Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'table_row' -StartLine $lineNumber -EndLine $lineNumber -Text $trimmed -HeadingPath $path
      continue
    }

    if ($buffer.Count -eq 0) { $bufferStart = $lineNumber }
    [void]$buffer.Add($trimmed)
  }

  if ($buffer.Count -gt 0) {
    $path = @($headingLevels.GetEnumerator() | Sort-Object Name | ForEach-Object { [string]$_.Value })
    Add-Unit -Units $units -Sequence ([ref]$sequence) -Kind 'paragraph' -StartLine $bufferStart -EndLine $lines.Count -Text ($buffer -join ' ') -HeadingPath $path
  }
  return @($units | ForEach-Object { $_ })
}

function Assert-Review {
  param([object]$Manifest, [object]$Review, [string]$RawFull)
  $anomalies = New-Object 'System.Collections.Generic.List[string]'
  $allowedCoverage = @('complete', 'partial', 'missing', 'distorted', 'uncertain', 'marker_only', 'not_applicable')
  $allowedPolicies = @(
    'required',
    'optional_supporting',
    'retain_media_marker',
    'omit_duplicate',
    'omit_nonsemantic_media',
    'omit_source_metadata',
    'omit_secondary_commentary'
  )
  $semanticPolicies = @('required', 'optional_supporting')
  $mediaMarkerPolicy = 'retain_media_marker'
  $omissionPolicies = @('omit_duplicate', 'omit_nonsemantic_media', 'omit_source_metadata', 'omit_secondary_commentary')
  $manifestIds = @($Manifest.units | ForEach-Object { [string]$_.id })
  $reviewIds = @($Review.units | ForEach-Object { [string]$_.source_id })

  if ($reviewIds.Count -ne @($reviewIds | Select-Object -Unique).Count) {
    [void]$anomalies.Add('review contains duplicate source_id values')
  }
  foreach ($id in $manifestIds) {
    if (@($reviewIds | Where-Object { $_ -eq $id }).Count -ne 1) { [void]$anomalies.Add("source unit is not reviewed exactly once: $id") }
  }
  foreach ($id in $reviewIds) {
    if ($manifestIds -notcontains $id) { [void]$anomalies.Add("review contains unknown source unit: $id") }
  }

  if (-not [bool]$Review.reviewer_contract.independent_pass) {
    [void]$anomalies.Add('reviewer_contract.independent_pass must be true')
  }
  if ([bool]$Review.reviewer_contract.writer_claims_used) {
    [void]$anomalies.Add('reviewer_contract.writer_claims_used must be false')
  }

  $rawLines = @(Get-Content -LiteralPath $RawFull -Encoding UTF8)
  foreach ($row in @($Review.units)) {
    $id = [string]$row.source_id
    $sourceUnit = @($Manifest.units | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1)
    if ($sourceUnit.Count -eq 0) { continue }
    $coverage = [string]$row.coverage_status
    $policy = [string]$row.retention_policy
    $coverageRationale = [string]$row.coverage_rationale
    $policyRationale = [string]$row.policy_rationale
    if ($allowedCoverage -notcontains $coverage) { [void]$anomalies.Add("$id has unsupported coverage_status: $coverage"); continue }
    if ($allowedPolicies -notcontains $policy) { [void]$anomalies.Add("$id has unsupported retention_policy: $policy"); continue }
    if ([string]::IsNullOrWhiteSpace($coverageRationale) -or $coverageRationale -eq 'TODO') {
      [void]$anomalies.Add("$id is missing a concrete coverage rationale")
    }
    if ([string]::IsNullOrWhiteSpace($policyRationale) -or $policyRationale -eq 'TODO') {
      [void]$anomalies.Add("$id is missing a concrete retention-policy rationale")
    }

    if ($semanticPolicies -contains $policy) {
      if ($coverage -eq 'not_applicable') {
        [void]$anomalies.Add("$id uses not_applicable coverage for semantic retention policy: $policy")
      }
      if ($coverage -in @('complete', 'partial')) {
        $start = [int]$row.raw_line_start
        $end = [int]$row.raw_line_end
        if ($start -lt 1 -or $end -lt $start -or $end -gt $rawLines.Count) {
          [void]$anomalies.Add("$id has an invalid raw line range: $start-$end")
        } elseif ([string]::IsNullOrWhiteSpace(($rawLines[($start - 1)..($end - 1)] -join ' '))) {
          [void]$anomalies.Add("$id maps to an empty raw range")
        }
      } elseif ($coverage -eq 'missing') {
        if ($null -ne $row.raw_line_start -or $null -ne $row.raw_line_end) {
          [void]$anomalies.Add("$id is missing but still declares a raw line range")
        }
      } elseif ($coverage -in @('distorted', 'uncertain')) {
        if ($null -ne $row.raw_line_start -or $null -ne $row.raw_line_end) {
          $start = [int]$row.raw_line_start
          $end = [int]$row.raw_line_end
          if ($start -lt 1 -or $end -lt $start -or $end -gt $rawLines.Count) {
            [void]$anomalies.Add("$id has an invalid raw line range: $start-$end")
          }
        }
      }
      if ($policy -eq 'optional_supporting' -and $coverage -in @('distorted', 'uncertain')) {
        [void]$anomalies.Add("$id optional content remains unresolved: $coverage")
      }
      if ($coverage -eq 'marker_only') {
        [void]$anomalies.Add("$id uses marker_only coverage without retain_media_marker policy")
      }
    } elseif ($policy -eq $mediaMarkerPolicy) {
      if ([string]$sourceUnit[0].kind -ne 'media') {
        [void]$anomalies.Add("$id uses retain_media_marker outside a media unit")
      }
      if ($coverage -eq 'marker_only') {
        $start = [int]$row.raw_line_start
        $end = [int]$row.raw_line_end
        if ($start -lt 1 -or $end -lt $start -or $end -gt $rawLines.Count) {
          [void]$anomalies.Add("$id has an invalid media-marker line range: $start-$end")
        } elseif (-not (($rawLines[($start - 1)..($end - 1)] -join ' ').Contains((U '\u539f\u6587\u542b\u4fe1\u606f\u56fe\u7247\uff0c\u672a\u8f6c\u5f55')))) {
          [void]$anomalies.Add("$id media-marker range does not contain the required marker")
        }
      } elseif ($coverage -eq 'missing') {
        if ($null -ne $row.raw_line_start -or $null -ne $row.raw_line_end) {
          [void]$anomalies.Add("$id is missing a media marker but still declares a raw line range")
        }
      } elseif ($coverage -eq 'uncertain') {
        if ($null -ne $row.raw_line_start -or $null -ne $row.raw_line_end) {
          $start = [int]$row.raw_line_start
          $end = [int]$row.raw_line_end
          if ($start -lt 1 -or $end -lt $start -or $end -gt $rawLines.Count) {
            [void]$anomalies.Add("$id has an invalid uncertain media-marker line range: $start-$end")
          }
        }
      } else {
        [void]$anomalies.Add("$id uses unsupported coverage for retain_media_marker: $coverage")
      }
    } elseif ($omissionPolicies -contains $policy) {
      if ($coverage -ne 'not_applicable') {
        [void]$anomalies.Add("$id uses omission policy $policy without not_applicable coverage")
      }
      if ($null -ne $row.raw_line_start -or $null -ne $row.raw_line_end) {
        [void]$anomalies.Add("$id uses omission policy $policy but still declares a raw line range")
      }
    }

    if ($policy -eq 'omit_nonsemantic_media') {
      if ([string]$sourceUnit[0].kind -ne 'media') {
        [void]$anomalies.Add("$id uses nonsemantic-media omission outside a media unit")
      }
    } elseif ($policy -eq 'omit_duplicate') {
      $mergedInto = [string]$row.merged_into
      if ([string]::IsNullOrWhiteSpace($mergedInto) -or $manifestIds -notcontains $mergedInto -or $mergedInto -eq $id) {
        [void]$anomalies.Add("$id has an invalid duplicate omission target")
      }
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$row.merged_into)) {
      [void]$anomalies.Add("$id declares merged_into without omit_duplicate policy")
    }
  }
  return @($anomalies | Select-Object -Unique)
}

try {
  if ($Action -eq 'manifest') {
    $manifestFull = Get-ProjectPath -Path $ManifestPath
    $sourceRecords = New-Object 'System.Collections.Generic.List[object]'
    $allUnits = New-Object 'System.Collections.Generic.List[object]'
    $sourceValues = @(Get-SourcePathList -Value $SourcePath)
    for ($sourceIndex = 0; $sourceIndex -lt $sourceValues.Count; $sourceIndex++) {
      $requestedSource = ([string]$sourceValues[$sourceIndex]).Replace('\', '/')
      if ($requestedSource.StartsWith('Clippings/', [StringComparison]::OrdinalIgnoreCase) -and -not (Test-CanonicalClippingPath -Path $requestedSource)) {
        throw "New source manifest clipping path must use Clippings/YYYYMMDD-*.md: $requestedSource"
      }
      $sourceFull = Get-ProjectPath -Path $sourceValues[$sourceIndex] -MustExist
      if ($requestedSource.StartsWith('Clippings/', [StringComparison]::OrdinalIgnoreCase)) {
        $sourceFile = Get-Item -LiteralPath $sourceFull
        if ($sourceFile.Length -eq 0) { throw "New source manifest clipping file is empty: $requestedSource" }
        $sourceHead = @(Get-Content -Encoding UTF8 -LiteralPath $sourceFull -TotalCount 20) -join "`n"
        if ($sourceHead -match '(?m)^capture_status:\s*missing\s*$') { throw "New source manifest clipping needs source recovery: $requestedSource" }
      }
      $sourceUnits = @(Get-SourceUnits -Path $sourceFull)
      $sourceKey = ('S{0:D2}' -f ($sourceIndex + 1))
      foreach ($unit in $sourceUnits) {
        $unit.id = "$sourceKey-$($unit.id)"
        $unit | Add-Member -NotePropertyName source_path -NotePropertyValue (Get-RelativePath -FullPath $sourceFull)
        [void]$allUnits.Add($unit)
      }
      [void]$sourceRecords.Add([pscustomobject][ordered]@{
        source_key = $sourceKey
        source_path = Get-RelativePath -FullPath $sourceFull
        source_sha256 = Get-Sha256 -Path $sourceFull
        unit_count = $sourceUnits.Count
      })
    }
    $units = @($allUnits | ForEach-Object { $_ })
    if ($units.Count -eq 0) { throw 'Source manifest contains no content units.' }
    $manifest = [pscustomobject][ordered]@{
      schema_version = 2
      parser_version = 'source-content-v3'
      sources = @($sourceRecords | ForEach-Object { $_ })
      unit_count = $units.Count
      units = @($units | ForEach-Object { $_ })
    }
    Write-Json -Path $manifestFull -Value $manifest
    Write-Output ($manifest | ConvertTo-Json -Depth 20)
    exit 0
  }

  if ($Action -eq 'template') {
    $manifestFull = Get-ProjectPath -Path $ManifestPath -MustExist
    $rawFull = Get-ProjectPath -Path $RawPath -MustExist
    $reviewFull = Get-ProjectPath -Path $ReviewPath
    $manifest = Read-Json -Path $manifestFull
    foreach ($source in @($manifest.sources)) {
      $sourceFull = Get-ProjectPath -Path ([string]$source.source_path) -MustExist
      if ((Get-Sha256 -Path $sourceFull) -ne [string]$source.source_sha256) { throw 'Source hash drifted after manifest generation.' }
    }
    $reviewUnits = @($manifest.units | ForEach-Object {
      [pscustomobject][ordered]@{
        source_id = [string]$_.id
        coverage_status = 'TODO'
        retention_policy = 'TODO'
        raw_line_start = $null
        raw_line_end = $null
        merged_into = $null
        coverage_rationale = 'TODO'
        policy_rationale = 'TODO'
      }
    })
    $review = [pscustomobject][ordered]@{
      schema_version = 4
      mode = $Mode
      reviewer_contract = [pscustomobject][ordered]@{
        independent_pass = $false
        writer_claims_used = $false
      }
      sources = @($manifest.sources)
      manifest_path = Get-RelativePath -FullPath $manifestFull
      manifest_sha256 = Get-Sha256 -Path $manifestFull
      raw_path = Get-RelativePath -FullPath $rawFull
      raw_sha256 = Get-Sha256 -Path $rawFull
      units = @($reviewUnits)
      conclusion = 'TODO'
    }
    Write-Json -Path $reviewFull -Value $review
    Write-Output ($review | ConvertTo-Json -Depth 20)
    exit 0
  }

  if ($Action -eq 'apply-decisions') {
    $reviewFull = Get-ProjectPath -Path $ReviewPath -MustExist
    $decisionFull = Get-ProjectPath -Path $DecisionPath -MustExist
    $review = Read-Json -Path $reviewFull
    $decisions = Read-Json -Path $decisionFull
    if ([int]$review.schema_version -ne 4) { throw 'Review must use schema_version 4.' }
    if ([int]$decisions.schema_version -ne 3) { throw 'Decisions must use schema_version 3.' }
    if ([string]$decisions.manifest_sha256 -ne [string]$review.manifest_sha256) { throw 'Decision manifest hash does not match review.' }
    if ([string]$decisions.raw_sha256 -ne [string]$review.raw_sha256) { throw 'Decision raw hash does not match review.' }
    $manifestFull = Get-ProjectPath -Path ([string]$review.manifest_path) -MustExist
    $manifest = Read-Json -Path $manifestFull
    foreach ($rule in @($decisions.rules)) {
      $ruleIds = @($rule.source_ids | ForEach-Object { [string]$_ })
      if ([string]$rule.retention_policy -ne 'required' -or [string]$rule.coverage_status -ne 'complete' -or $ruleIds.Count -le 24) { continue }
      $sectionHeadings = @($manifest.units | Where-Object {
        $ruleIds -contains [string]$_.id -and [string]$_.kind -eq 'heading'
      } | ForEach-Object { [string]$_.text } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
      if ($sectionHeadings.Count -ge 5) {
        throw "A required decision rule covers $($ruleIds.Count) source units across $($sectionHeadings.Count) headings. Split long-form coverage by semantic section and map each section to its exact raw range."
      }
    }
    $knownIds = @($review.units | ForEach-Object { [string]$_.source_id })
    $seenIds = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rule in @($decisions.rules)) {
      foreach ($sourceId in @($rule.source_ids)) {
        $id = [string]$sourceId
        if ($knownIds -notcontains $id) { throw "Decision contains unknown source unit: $id" }
        if ($seenIds -contains $id) { throw "Decision covers a source unit more than once: $id" }
        [void]$seenIds.Add($id)
        $row = @($review.units | Where-Object { [string]$_.source_id -eq $id })[0]
        $row.coverage_status = [string]$rule.coverage_status
        $row.retention_policy = [string]$rule.retention_policy
        $row.raw_line_start = if ($null -ne $rule.PSObject.Properties['raw_line_start'] -and $null -ne $rule.raw_line_start) { [int]$rule.raw_line_start } else { $null }
        $row.raw_line_end = if ($null -ne $rule.PSObject.Properties['raw_line_end'] -and $null -ne $rule.raw_line_end) { [int]$rule.raw_line_end } else { $null }
        $row.merged_into = if ($null -ne $rule.PSObject.Properties['merged_into'] -and $null -ne $rule.merged_into) { [string]$rule.merged_into } else { $null }
        $row.coverage_rationale = [string]$rule.coverage_rationale
        $row.policy_rationale = [string]$rule.policy_rationale
      }
    }
    foreach ($id in $knownIds) {
      if ($seenIds -notcontains $id) { throw "Decision does not cover source unit: $id" }
    }
    $review.reviewer_contract.independent_pass = [bool]$decisions.reviewer_contract.independent_pass
    $review.reviewer_contract.writer_claims_used = [bool]$decisions.reviewer_contract.writer_claims_used
    $review.conclusion = [string]$decisions.conclusion
    $review | Add-Member -Force -NotePropertyName decision_path -NotePropertyValue (Get-RelativePath -FullPath $decisionFull)
    $review | Add-Member -Force -NotePropertyName decision_sha256 -NotePropertyValue (Get-Sha256 -Path $decisionFull)
    Write-Json -Path $reviewFull -Value $review
    Write-Output ($review | ConvertTo-Json -Depth 20)
    exit 0
  }

  $reviewFull = Get-ProjectPath -Path $ReviewPath -MustExist
  $receiptFull = Get-ProjectPath -Path $ReceiptPath
  $review = Read-Json -Path $reviewFull
  if ([int]$review.schema_version -ne 4) { throw 'Review must use schema_version 4.' }
  if ([string]$review.mode -ne $Mode) { throw "Review mode does not match requested mode: $Mode" }
  $manifestFull = Get-ProjectPath -Path ([string]$review.manifest_path) -MustExist
  $manifest = Read-Json -Path $manifestFull
  $rawFull = Get-ProjectPath -Path ([string]$review.raw_path) -MustExist
  if (@($review.sources).Count -ne @($manifest.sources).Count) { throw 'Review source list does not match manifest.' }
  foreach ($source in @($manifest.sources)) {
    $sourceFull = Get-ProjectPath -Path ([string]$source.source_path) -MustExist
    $reviewSource = @($review.sources | Where-Object { [string]$_.source_key -eq [string]$source.source_key })
    if ($reviewSource.Count -ne 1 -or
        (Get-Sha256 -Path $sourceFull) -ne [string]$source.source_sha256 -or
        [string]$reviewSource[0].source_sha256 -ne [string]$source.source_sha256 -or
        [string]$reviewSource[0].source_path -ne [string]$source.source_path) {
      throw 'Source hash or source list does not match manifest and review.'
    }
  }
  if ((Get-Sha256 -Path $manifestFull) -ne [string]$review.manifest_sha256) { throw 'Manifest hash drifted after review creation.' }
  if ((Get-Sha256 -Path $rawFull) -ne [string]$review.raw_sha256) { throw 'Raw hash drifted after review creation.' }
  if ($null -ne $review.PSObject.Properties['decision_path'] -and -not [string]::IsNullOrWhiteSpace([string]$review.decision_path)) {
    $decisionFull = Get-ProjectPath -Path ([string]$review.decision_path) -MustExist
    if ((Get-Sha256 -Path $decisionFull) -ne [string]$review.decision_sha256) { throw 'Decision hash drifted after review application.' }
  }
  $anomalies = @(Assert-Review -Manifest $manifest -Review $review -RawFull $rawFull)
  $coverageCounts = [ordered]@{}
  foreach ($name in @('complete', 'partial', 'missing', 'distorted', 'uncertain', 'marker_only', 'not_applicable')) {
    $coverageCounts[$name] = @($review.units | Where-Object { [string]$_.coverage_status -eq $name }).Count
  }
  $policyCounts = [ordered]@{}
  foreach ($name in @('required', 'optional_supporting', 'retain_media_marker', 'omit_duplicate', 'omit_nonsemantic_media', 'omit_source_metadata', 'omit_secondary_commentary')) {
    $policyCounts[$name] = @($review.units | Where-Object { [string]$_.retention_policy -eq $name }).Count
  }
  $failedUnits = @($review.units | Where-Object {
    ([string]$_.retention_policy -eq 'required' -and [string]$_.coverage_status -ne 'complete') -or
    ([string]$_.retention_policy -eq 'retain_media_marker' -and [string]$_.coverage_status -ne 'marker_only') -or
    [string]$_.coverage_status -in @('distorted', 'uncertain')
  } | ForEach-Object {
    [pscustomobject][ordered]@{
      source_id = [string]$_.source_id
      coverage_status = [string]$_.coverage_status
      retention_policy = [string]$_.retention_policy
      coverage_rationale = [string]$_.coverage_rationale
      policy_rationale = [string]$_.policy_rationale
    }
  })
  if ($failedUnits.Count -eq 0 -and [string]$review.conclusion -ne 'pass') {
    $anomalies += 'review conclusion must be pass when no required content is unresolved'
  }
  if ($failedUnits.Count -gt 0 -and [string]$review.conclusion -ne 'fail') {
    $anomalies += 'review conclusion must be fail when required content is unresolved'
  }
  $status = if ($anomalies.Count -eq 0 -and $failedUnits.Count -eq 0 -and [string]$review.conclusion -eq 'pass') { 'passed' } else { 'failed' }
  $receipt = [pscustomobject][ordered]@{
    schema_version = 4
    mode = $Mode
    status = $status
    sources = @($manifest.sources)
    raw_path = [string]$review.raw_path
    raw_sha256 = [string]$review.raw_sha256
    manifest_path = Get-RelativePath -FullPath $manifestFull
    manifest_sha256 = Get-Sha256 -Path $manifestFull
    review_path = Get-RelativePath -FullPath $reviewFull
    review_sha256 = Get-Sha256 -Path $reviewFull
    decision_path = if ($null -ne $review.PSObject.Properties['decision_path']) { [string]$review.decision_path } else { $null }
    decision_sha256 = if ($null -ne $review.PSObject.Properties['decision_sha256']) { [string]$review.decision_sha256 } else { $null }
    unit_count = [int]$manifest.unit_count
    coverage_counts = $coverageCounts
    retention_policy_counts = $policyCounts
    failed_unit_count = $failedUnits.Count
    failed_units = @($failedUnits)
    anomaly_count = @($anomalies | Select-Object -Unique).Count
    anomalies = @($anomalies | Select-Object -Unique)
  }
  Write-Json -Path $receiptFull -Value $receipt
  if ($status -ne 'passed') {
    $detail = @($receipt.anomalies)
    if ($failedUnits.Count -gt 0) { $detail += "$($failedUnits.Count) required or unresolved source units failed" }
    throw ('Content audit failed: ' + ($detail -join ' | '))
  }
  Write-Output ($receipt | ConvertTo-Json -Depth 20)
} catch {
  [Console]::Error.WriteLine('SOURCE_CONTENT_AUDIT_FAILED: ' + $_.Exception.Message)
  exit 1
}
