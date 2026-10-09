[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('plan', 'screen', 'validate')]
    [string]$Action,
    [string]$RunId = '',
    [string]$OutputPath = '',
    [string]$ReportPath = '',
    [string]$ReceiptPath = '',
    [int]$SampleSize = 6,
    [int]$MinimumIngestAgeDays = 7,
    [string]$Dimensions = 'sources|modules|definitions|boundaries|implementation|enumeration',
    [string]$ExcludeRaw = '',
    [string]$IncludeRaw = '',
    [ValidateSet('v1','v2')][string]$Standard = 'v2',
    [string]$ProducerContextId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$safeProject = $projectRoot.Replace('\', '/')
$sourceAuditTool = Join-Path $PSScriptRoot 'source-content-audit.ps1'
$hostExecutable = (Get-Process -Id $PID).Path

function U {
    param([string]$Value)
    return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', {
        param($match)
        return [char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function Get-ProjectPath {
    param([string]$Path, [switch]$MustExist)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A required path argument is empty.' }
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $projectRoot $Path)) }
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay inside Knowledge: $full" }
    if ($MustExist -and -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "File does not exist: $full" }
    return $full
}

function Get-RelativePath {
    param([string]$FullPath)
    $prefix = $projectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return $FullPath.Substring($prefix.Length).Replace('\', '/')
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-Utf8File {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Invoke-SourceAudit {
    param([string[]]$Arguments, [switch]$ExpectFailure)
    if (-not (Test-Path -LiteralPath $sourceAuditTool -PathType Leaf)) { throw 'Source-content audit tool is missing.' }
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $hostExecutable -NoProfile -ExecutionPolicy Bypass -File $sourceAuditTool @Arguments 2>&1) -join "`n"
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($ExpectFailure -and $code -eq 0) { throw 'Expected source-content audit failure but validation passed.' }
    if (-not $ExpectFailure -and $code -ne 0) { throw "Source-content audit failed: $output" }
    return $output
}

function Get-Body {
    param([string]$Text)
    $body = [regex]::Replace($Text, '\A---\s*\r?\n.*?\r?\n---\s*\r?\n', '', 'Singleline')
    $body = [regex]::Replace($body, '(?m)^\s*!\[[^\]]*\]\([^\)]*\)\s*$', '')
    return $body
}

function Get-OldAScore {
    param([string]$Text)
    $match = [regex]::Match($Text, '(?m)^\s*intrinsic_total:\s*(?<score>\d+(?:\.\d+)?)\s*$')
    if (-not $match.Success) { return $null }
    return [double]::Parse($match.Groups['score'].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-InvariantDouble {
    param([string]$Value, [string]$Label)
    $number = 0.0
    if (-not [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        throw "Content backtest scoring value is invalid ($Label): $Value"
    }
    return $number
}

function Get-SourcePaths {
    param([string]$RawText)
    $frontmatter = [regex]::Match($RawText, '\A---\s*\r?\n(?<body>.*?)\r?\n---', 'Singleline')
    if (-not $frontmatter.Success) { return @() }
    $block = [regex]::Match($frontmatter.Groups['body'].Value, '(?ms)^source_clipping:\s*(?<value>.*?)(?=^\S[^:\r\n]*:\s*|\z)')
    if (-not $block.Success) { return @() }
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($block.Groups['value'].Value, '\[\[(?<path>[^\]]+)\]\]')) {
        $value = $match.Groups['path'].Value.Replace('\', '/')
        if (-not $value.StartsWith('Clippings/')) { $value = 'Clippings/' + $value }
        if (-not $value.EndsWith('.md')) { $value += '.md' }
        [void]$paths.Add($value)
    }
    return @($paths.ToArray())
}

function Count-Matches {
    param([string]$Text, [string]$Pattern)
    return [regex]::Matches($Text, $Pattern, 'IgnoreCase').Count
}

function Get-StableKey {
    param([string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Get-HistoricalSourceText {
    param([string]$RelativePath)
    $revision = @(& git -c "safe.directory=$safeProject" -C $projectRoot log --all --diff-filter=AM -n 1 --format=%H -- $RelativePath 2>$null) | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$revision)) { return $null }
    $text = @(& git -c "safe.directory=$safeProject" -C $projectRoot show "$revision`:$RelativePath" 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($text)) { return $null }
    return [pscustomobject][ordered]@{ text=$text; revision=([string]$revision).Trim().ToLowerInvariant() }
}

function Get-RiskRecord {
    param([IO.FileInfo]$RawFile, [string[]]$Enabled)
    $rawText = Get-Content -Raw -Encoding UTF8 -LiteralPath $RawFile.FullName
    $oldA = Get-OldAScore -Text $rawText
    if ($null -eq $oldA) { return $null }
    $rawBody = Get-Body $rawText
    $sourceRelatives = @(Get-SourcePaths $rawText)
    $sourceParts = New-Object System.Collections.Generic.List[string]
    $sourceOrigins = New-Object System.Collections.Generic.List[string]
    $sourceMaterials = New-Object System.Collections.Generic.List[object]
    $unavailableSources = New-Object System.Collections.Generic.List[string]
    foreach ($relativeSource in $sourceRelatives) {
        $sourceFull = Get-ProjectPath $relativeSource
        if (Test-Path -LiteralPath $sourceFull -PathType Leaf) {
            $sourceText = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourceFull
            [void]$sourceParts.Add($sourceText)
            [void]$sourceOrigins.Add("$relativeSource@working-tree")
            [void]$sourceMaterials.Add([pscustomobject][ordered]@{ path=$relativeSource; origin='working-tree'; text=$sourceText })
            continue
        }
        $historical = Get-HistoricalSourceText -RelativePath $relativeSource
        if ($null -ne $historical) {
            [void]$sourceParts.Add([string]$historical.text)
            [void]$sourceOrigins.Add("$relativeSource@git:$($historical.revision)")
            [void]$sourceMaterials.Add([pscustomobject][ordered]@{ path=$relativeSource; origin=("git:" + [string]$historical.revision); text=[string]$historical.text })
        } else {
            [void]$unavailableSources.Add($relativeSource)
        }
    }
    $sourceExists = $sourceRelatives.Count -gt 0 -and $unavailableSources.Count -eq 0
    $sourceText = if ($sourceExists) { @($sourceParts.ToArray()) -join "`n" } else { '' }
    $sourceBody = Get-Body $sourceText
    $rawLength = [Math]::Max(1, $rawBody.Length)
    $sourceLength = $sourceBody.Length
    $ratio = if ($sourceLength -gt 0) { [Math]::Round($rawLength / $sourceLength, 3) } else { 0 }
    $rawHeadings = Count-Matches $rawBody '(?m)^#{2,6}\s+'
    $sourceHeadings = Count-Matches $sourceBody '(?m)^#{2,6}\s+'
    $signals = New-Object System.Collections.Generic.List[string]
    $score = 0

    if (-not $sourceExists) {
        $score += 100
        [void]$signals.Add('source-unavailable')
    } elseif (@($sourceOrigins | Where-Object { $_ -match '@git:' }).Count -gt 0) {
        $score += 2
        [void]$signals.Add(('source-history:{0}' -f @($sourceOrigins | Where-Object { $_ -match '@git:' }).Count))
    }
    if ($Enabled -contains 'modules' -and $sourceLength -gt 3500 -and $ratio -lt 0.30 -and ($sourceHeadings - $rawHeadings) -ge 3) {
        $score += 8
        [void]$signals.Add(('module-gap:{0}/{1}:{2:p0}' -f $sourceHeadings, $rawHeadings, $ratio))
    }
    $patterns = [ordered]@{
        sources = (U '(?:\u300a[^\u300b]{2,80}\u300b|\bGDC\b|\bCEDEC\b|\bSIGGRAPH\b|\bIEEE\b|\bACM\b|\bISBN\b)')
        definitions = (U '(?:\u5b9a\u4e49|\u6307\u7684\u662f|\u79f0\u4e3a|\u610f\u5473\u7740)')
        boundaries = (U '(?:\u524d\u63d0|\u8fb9\u754c|\u9650\u5236|\u4ee3\u4ef7|\u53d6\u820d|\u4e0d\u7b49\u4e8e|\u5e76\u975e|\u4e0d\u80fd\u63a8\u5e7f)')
        implementation = (U '(?:\u6d41\u7a0b|\u6b65\u9aa4|\u8282\u70b9|\u72b6\u6001\u673a|\u751f\u547d\u5468\u671f|\u89e6\u53d1|\u6570\u636e\u7ed3\u6784|\u6267\u884c\u987a\u5e8f|\u5de5\u5177\u94fe)')
        enumeration = (U '(?:[0-9\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341]+(?:\u79cd|\u7c7b|\u9879|\u6b65|\u5c42|\u4e2a))')
    }
    foreach ($dimension in @('sources', 'definitions', 'boundaries', 'implementation', 'enumeration')) {
        if ($Enabled -notcontains $dimension -or -not $sourceExists) { continue }
        $sourceCount = Count-Matches $sourceBody $patterns[$dimension]
        $rawCount = Count-Matches $rawBody $patterns[$dimension]
        $gap = [Math]::Max(0, $sourceCount - $rawCount)
        if ($gap -gt 0) {
            $increment = [Math]::Min(6, $gap)
            $score += $increment
            [void]$signals.Add(("{0}:{1}/{2}" -f $dimension, $sourceCount, $rawCount))
        }
    }
    $relative = Get-RelativePath $RawFile.FullName
    return [pscustomobject][ordered]@{
        raw = $relative
        old_a = $oldA
        source = @($sourceRelatives)
        source_origins = @($sourceOrigins.ToArray())
        source_available = $sourceExists
        raw_chars = $rawLength
        source_chars = $sourceLength
        compression_ratio = $ratio
        source_headings = $sourceHeadings
        raw_headings = $rawHeadings
        risk_score = $score
        signals = @($signals.ToArray())
        tie_break = Get-StableKey "$RunId|$relative"
        source_materials = @($sourceMaterials.ToArray())
    }
}

function Get-Candidates {
    param([string[]]$Enabled, [string[]]$Excluded, [string[]]$Included)
    $rawRoot = Join-Path $projectRoot 'raw-sources'
    $records = foreach ($file in @(Get-ChildItem -LiteralPath $rawRoot -File -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' })) {
        $relative = Get-RelativePath $file.FullName
        if ($Excluded -contains $relative -or $Excluded -contains $file.Name) { continue }
        if ($Included.Count -gt 0 -and $Included -notcontains $relative -and $Included -notcontains $file.Name) { continue }
        Get-RiskRecord -RawFile $file -Enabled $Enabled
    }
    return @($records | Sort-Object @{Expression='risk_score';Descending=$true}, @{Expression='tie_break';Descending=$false})
}

function Get-HistoricalBacktestRawPaths {
    $runsRoot = Join-Path $projectRoot 'system/maintenance/ingest-runs'
    if (-not (Test-Path -LiteralPath $runsRoot -PathType Container)) { return @() }
    $paths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @(Get-ChildItem -LiteralPath $runsRoot -Recurse -File -Filter '*.json' | Where-Object {
        $_.Name -match 'backtest' -or $_.Directory.Name -match '^content-backtest-'
    })) {
        try {
            $record = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName | ConvertFrom-Json
        } catch {
            continue
        }
        if ($record.PSObject.Properties.Name -contains 'samples') {
            foreach ($sample in @($record.samples)) {
                $path = [string]$sample.source
                if ($path.StartsWith('raw-sources/', [StringComparison]::OrdinalIgnoreCase)) { [void]$paths.Add($path.Replace('\', '/')) }
            }
        }
        if ($record.PSObject.Properties.Name -contains 'scoring_results') {
            foreach ($result in @($record.scoring_results)) {
                $path = [string]$result.raw_path
                if ($path.StartsWith('raw-sources/', [StringComparison]::OrdinalIgnoreCase)) { [void]$paths.Add($path.Replace('\', '/')) }
            }
        }
        if ($record.PSObject.Properties.Name -contains 'source_content_audits') {
            foreach ($audit in @($record.source_content_audits)) {
                $path = [string]$audit.raw_path
                if ($path.StartsWith('raw-sources/', [StringComparison]::OrdinalIgnoreCase)) { [void]$paths.Add($path.Replace('\', '/')) }
            }
        }
    }
    return @($paths | Sort-Object)
}

function Get-RecentOrUntrackedRawPaths {
    param([int]$MinimumAgeDays)
    if ($MinimumAgeDays -le 0) { return @() }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.git'))) { return @() }
    $inside = @(& git -c "safe.directory=$safeProject" -C $projectRoot rev-parse --is-inside-work-tree 2>$null) -join ''
    if ($LASTEXITCODE -ne 0 -or $inside.Trim() -ne 'true') { return @() }

    $paths = New-Object System.Collections.Generic.List[string]
    $cutoff = [DateTimeOffset]::Now.AddDays(-1 * $MinimumAgeDays).ToString('o')
    $recent = @(& git -c "safe.directory=$safeProject" -c core.quotepath=false -C $projectRoot log "--since=$cutoff" --diff-filter=A --name-only --format= -- raw-sources)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve recently ingested raw paths from Git history.' }
    foreach ($path in $recent) {
        $normalized = [string]$path.Trim().Replace('\', '/')
        if ($normalized.StartsWith('raw-sources/') -and $normalized.EndsWith('.md') -and $normalized -ne 'raw-sources/README.md') { [void]$paths.Add($normalized) }
    }

    $untracked = @(& git -c "safe.directory=$safeProject" -c core.quotepath=false -C $projectRoot ls-files --others --exclude-standard -- 'raw-sources/*.md')
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve untracked raw paths for backtest admission.' }
    foreach ($path in $untracked) {
        $normalized = [string]$path.Trim().Replace('\', '/')
        if ($normalized -ne '') { [void]$paths.Add($normalized) }
    }
    return @($paths | Sort-Object -Unique)
}

function Find-ReusableBacktestReceipt {
    param([string]$RawPath, [string]$RawSha256)
    $runsRoot = Join-Path $projectRoot 'system/maintenance/ingest-runs'
    if (-not (Test-Path -LiteralPath $runsRoot -PathType Container)) { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $runsRoot -Recurse -Filter 'receipt.json' -File |
        Where-Object { $_.FullName.Replace('\', '/').Contains('/backtest-source-audits/') } |
        Sort-Object LastWriteTimeUtc -Descending)
    foreach ($candidate in $candidates) {
        try {
            $receipt = Get-Content -Raw -Encoding UTF8 -LiteralPath $candidate.FullName | ConvertFrom-Json
        } catch {
            continue
        }
        $requiredReceiptFields = @('schema_version','standard','ruleset','mode','status','raw_path','raw_sha256','sources','manifest_path','unit_count')
        if (@($requiredReceiptFields | Where-Object { $receipt.PSObject.Properties.Name -notcontains $_ }).Count -gt 0) {
            continue
        }
        if ([int]$receipt.schema_version -ne 6 -or
            [string]$receipt.standard -ne 'RAW_STANDARD_V2' -or
            [string]$receipt.ruleset -ne 'core-semantic-20260910' -or
            [string]$receipt.mode -ne 'backtest' -or
            [string]$receipt.status -ne 'passed' -or
            [string]$receipt.raw_path -ne $RawPath -or
            [string]$receipt.raw_sha256 -ne $RawSha256) {
            continue
        }
        $sourcesMatch = $true
        foreach ($source in @($receipt.sources)) {
            if ([string]::IsNullOrWhiteSpace([string]$source.source_path) -or [string]::IsNullOrWhiteSpace([string]$source.source_sha256)) {
                $sourcesMatch = $false
                break
            }
            try {
                $sourceFull = Get-ProjectPath -Path ([string]$source.source_path) -MustExist
                if ((Get-Sha256 -Path $sourceFull) -ne [string]$source.source_sha256) {
                    $sourcesMatch = $false
                    break
                }
            } catch {
                $sourcesMatch = $false
                break
            }
        }
        if (-not $sourcesMatch) { continue }
        return [pscustomobject][ordered]@{
            receipt_path = Get-RelativePath $candidate.FullName
            manifest_path = [string]$receipt.manifest_path
            unit_count = [int]$receipt.unit_count
        }
    }
    return $null
}

function Write-Plan {
    param([object[]]$Records, [string]$Path, [bool]$IsScreen)
    $full = Get-ProjectPath $Path
    if ([IO.Path]::GetExtension($full) -ne '.md') {
        throw 'Content backtest plan and screen outputs must use the .md extension.'
    }
    $reportDirectory = Split-Path -Parent $full
    $auditRecords = New-Object System.Collections.Generic.List[object]
    if (-not $IsScreen) {
        for ($recordIndex = 0; $recordIndex -lt $Records.Count; $recordIndex++) {
            $record = $Records[$recordIndex]
            $auditDirectory = Join-Path (Join-Path $reportDirectory 'backtest-source-audits') ('{0:D2}' -f ($recordIndex + 1))
            $rawFull = Get-ProjectPath -Path ([string]$record.raw) -MustExist
            $reusedReceipt = if ($Standard -eq 'v2') { Find-ReusableBacktestReceipt -RawPath ([string]$record.raw) -RawSha256 (Get-Sha256 -Path $rawFull) } else { $null }
            if ($null -ne $reusedReceipt) {
                [void]$auditRecords.Add([pscustomobject][ordered]@{
                    raw = [string]$record.raw
                    manifest = [string]$reusedReceipt.manifest_path
                    review = 'reused: same raw, source, and ruleset hashes'
                    receipt = [string]$reusedReceipt.receipt_path
                    unit_count = [int]$reusedReceipt.unit_count
                    reused = $true
                })
                continue
            }
            $materialPaths = New-Object System.Collections.Generic.List[string]
            $materialIndex = 0
            foreach ($material in @($record.source_materials)) {
                $materialIndex++
                if ([string]$material.origin -eq 'working-tree') {
                    [void]$materialPaths.Add([string]$material.path)
                } else {
                    $snapshotFull = Join-Path $auditDirectory ('source-{0:D2}.md' -f $materialIndex)
                    Write-Utf8File -Path $snapshotFull -Text ([string]$material.text)
                    [void]$materialPaths.Add((Get-RelativePath $snapshotFull))
                }
            }
            if ($materialPaths.Count -eq 0) { throw "Selected raw has no available source material: $($record.raw)" }
            $manifestFull = Join-Path $auditDirectory 'manifest.json'
            $reviewFull = Join-Path $auditDirectory 'review.json'
            $receiptFull = Join-Path $auditDirectory 'receipt.json'
            $manifestRelative = Get-RelativePath $manifestFull
            $reviewRelative = Get-RelativePath $reviewFull
            Invoke-SourceAudit @('-Action','manifest','-SourcePath',($materialPaths -join ';'),'-ManifestPath',$manifestRelative) | Out-Null
            if ($Standard -eq 'v1') {
                Invoke-SourceAudit @('-Action','template','-Mode','backtest','-ManifestPath',$manifestRelative,'-RawPath',[string]$record.raw,'-ReviewPath',$reviewRelative) | Out-Null
            } else {
                if ([string]::IsNullOrWhiteSpace($ProducerContextId)) { throw 'V2 planning requires the actual ProducerContextId.' }
                $requestRelative = Get-RelativePath (Join-Path $auditDirectory 'request.json')
                & node (Join-Path $PSScriptRoot 'backtest-quality.mjs') prepare --root $projectRoot --raw ([string]$record.raw) --manifest $manifestRelative --request $requestRelative --producer $ProducerContextId --config backtest-context-policy-v1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'V2 backtest preparation failed.' }
            }
            $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestFull | ConvertFrom-Json
            [void]$auditRecords.Add([pscustomobject][ordered]@{
                raw = [string]$record.raw
                manifest = $manifestRelative
                review = $reviewRelative
                receipt = Get-RelativePath $receiptFull
                unit_count = [int]$manifest.unit_count
                reused = $false
            })
        }
    }
    $title = if ($IsScreen) { U '# \u5185\u5bb9\u56de\u6d4b\u00b7\u5168\u5e93\u7b5b\u9009\u5019\u9009' } else { U '# \u5185\u5bb9\u56de\u6d4b\u00b7\u6279\u91cf\u62bd\u67e5' }
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add($title)
    [void]$lines.Add('')
    [void]$lines.Add('CONTENT_BACKTEST_V1')
    [void]$lines.Add('')
    [void]$lines.Add("run_id: $RunId")
    [void]$lines.Add("dimensions: $Dimensions")
    [void]$lines.Add("raw_standard: $Standard")
    if ($Standard -eq 'v2') {
        [void]$lines.Add('Core-semantic rules: retain core knowledge and indispensable reasoning/examples/data/limits; justify contextual omissions against core_claims. No embedded images in Raw. Disclose nonessential visual omissions; essential media gaps block. Use the current ruleset, never relabel old receipts.')
        [void]$lines.Add('V2: review each frozen request.json using raw-writing-v2.md. Use fresh_full_review by default; sample_blind_reuse is allowed only when the reviewer is independent from the writer/producer, blind to the old score and has no prior exposure to this sample. After repair, cross_targeted_recheck must use a different reviewer from the baseline. Preserve report.json and host-observed invocation evidence. Compile receipt.json with backtest-quality.mjs validate --mode backtest. An unchanged raw, source, and ruleset may cite a prior passed receipt; the validator re-verifies that receipt. The review column is a legacy display slot; v2 truth is the bound report/request/host in receipt.json.')
    }
    [void]$lines.Add('')
    [void]$lines.Add((U '## \u9759\u6001\u5019\u9009\u8bc1\u636e'))
    [void]$lines.Add('')
    [void]$lines.Add((U '| raw | source | \u98ce\u9669\u5206 | \u538b\u7f29\u6bd4 | \u6807\u9898\u6570 source/raw | \u4ee3\u7406\u4fe1\u53f7 |'))
    [void]$lines.Add('|---|---|---:|---:|---:|---|')
    foreach ($record in $Records) {
        $source = if (@($record.source).Count -eq 0) { 'missing' } else { @($record.source) -join '<br>' }
        [void]$lines.Add(("| `{0}` | `{1}` | {2} | {3:p0} | {4}/{5} | {6} |" -f $record.raw, $source, $record.risk_score, $record.compression_ratio, $record.source_headings, $record.raw_headings, (@($record.signals) -join '; ')))
    }
    if ($IsScreen) {
        [void]$lines.Add('')
        [void]$lines.Add((U '> \u5019\u9009\u4ec5\u7528\u4e8e\u7f29\u5c0f\u56de\u8bfb\u8303\u56f4\uff1b\u98ce\u9669\u5206\u4e0d\u80fd\u76f4\u63a5\u5224\u5b9a\u5185\u5bb9\u5f02\u5e38\uff0c\u4e5f\u4e0d\u6388\u6743\u81ea\u52a8\u4fee\u6539\u3002'))
        [void]$lines.Add('')
        [void]$lines.Add('CONTENT_BACKTEST_SCREEN_V1')
        Write-Utf8File -Path $full -Text (($lines -join "`n") + "`n")
        return $full
    }
    [void]$lines.Add('')
    [void]$lines.Add((U '## \u6279\u91cf\u62bd\u67e5'))
    [void]$lines.Add('')
    [void]$lines.Add((U '### \u5168\u6587\u6620\u5c04\u5ba1\u6838'))
    [void]$lines.Add('')
    [void]$lines.Add((U '| raw | manifest | review | receipt | source units | \u7ed3\u8bba |'))
    [void]$lines.Add('|---|---|---|---|---:|---|')
    foreach ($audit in @($auditRecords.ToArray())) {
        [void]$lines.Add(("| `{0}` | `{1}` | `{2}` | `{3}` | {4} | TODO |" -f $audit.raw, $audit.manifest, $audit.review, $audit.receipt, $audit.unit_count))
    }
    [void]$lines.Add('')
    [void]$lines.Add('SOURCE_CONTENT_AUDIT_V4')
    [void]$lines.Add('')
    [void]$lines.Add((U '### A \u7c7b\u4ece\u96f6\u8bc4\u5206'))
    [void]$lines.Add('')
    [void]$lines.Add((U '| raw | \u65e7 A | A1 | A2 | A3 | \u65b0 A | \u504f\u5dee | \u5904\u7f6e | \u4f9d\u636e |'))
    [void]$lines.Add('|---|---:|---:|---:|---:|---:|---:|---|---|')
    foreach ($record in $Records) {
        [void]$lines.Add(("| `{0}` | {1:0.0#} | TODO | TODO | TODO | TODO | TODO | TODO | TODO |" -f $record.raw, $record.old_a))
    }
    [void]$lines.Add('')
    [void]$lines.Add('A_CLASS_RESCORING_V1')
    [void]$lines.Add('')
    [void]$lines.Add((U '### \u6837\u4f8b\u56de\u8bfb'))
    [void]$lines.Add('')
    [void]$lines.Add((U '| raw | \u5df2\u8bfb\u7ed3\u6784/\u6587\u98ce\u6837\u677f | \u5bf9\u7167\u9879\uff08\u547d\u9898/\u63a8\u5bfc/\u8f7d\u4f53/\u539f\u6587\u8fb9\u754c\uff09 | \u7ed3\u8bba |'))
    [void]$lines.Add('|---|---|---|---|')
    $structureSamples = @(
        (U 'raw-sources/\u4ece0\u52301\u521b\u9020\u5f00\u653e\u4e16\u754c\u8bbe\u8ba1\u6d41\u7a0b-\u5929\u7f8e\u6c5f\u5cb8\u6816-20260705.md'),
        (U 'raw-sources/Game Master-\u5a01\u5c14\u83b1\u7279\u6e38\u620f\u5927\u5e08-indienova-\u843d\u65e5\u95f4-20061106.md'),
        (U 'raw-sources/\u6e38\u620f\u5206\u6790(\u56db\u4e94)-\u6697\u9ed1\u7cfb\u5217\u4e3a\u4ec0\u4e48\u597d\u73a9-\u6e38\u620f\u8bbe\u8ba1\u7406\u8bba-20230701.md')
    )
    if ($Standard -eq 'v2') { $structureSamples = @($structureSamples[0]) }
    if ($Standard -eq 'v2' -and -not (Test-Path -LiteralPath (Join-Path $script:projectRoot $structureSamples[0]))) { $structureSamples = @('system/maintenance/checklists/raw-writing-v2.md') }
    $sampleCell = $structureSamples -join '<br>'
    foreach ($record in @($Records | Select-Object -First ([Math]::Min(2, $Records.Count)))) {
        [void]$lines.Add(("| `{0}` | {1} | TODO | TODO |" -f $record.raw, $sampleCell))
    }
    [void]$lines.Add('')
    [void]$lines.Add('SAMPLE_STYLE_REREAD_V1')
    [void]$lines.Add('')
    if ($Standard -eq 'v2') {
        [void]$lines.Add('### Explicit findings ledger')
        [void]$lines.Add('')
        [void]$lines.Add('| raw | issue_class | severity | detected_stage | status | evidence |')
        [void]$lines.Add('|---|---|---|---|---|---|')
        foreach ($record in $Records) {
            [void]$lines.Add(("| `{0}` | TODO | TODO | TODO | TODO | TODO |" -f $record.raw))
        }
        [void]$lines.Add('')
        [void]$lines.Add('CONTENT_BACKTEST_FINDINGS_V1')
        [void]$lines.Add('')
    }
    [void]$lines.Add((U '### raw \u4fee\u590d\u4e0e Wiki \u5f71\u54cd\u590d\u6838'))
    [void]$lines.Add('')
    [void]$lines.Add((U '> Wiki \u590d\u6838\u7ed3\u8bba\u5fc5\u987b\u5305\u542b\uff1a\u65e0\u9700\u8865\u5145 / \u9700\u8865\u5145 / \u5df2\u8865\u5145\u3002'))
    [void]$lines.Add('')
    [void]$lines.Add((U '| raw | \u8ba1\u5212 raw SHA-256 | raw \u5904\u7f6e | raw \u53d8\u66f4\u8bc1\u636e | \u5173\u8054\u65e2\u6709 Wiki | Wiki \u590d\u6838\u7ed3\u8bba | Wiki \u5904\u7f6e | \u62c6\u5206\u6388\u6743 |'))
    [void]$lines.Add('|---|---|---|---|---|---|---|---|')
    foreach ($record in $Records) {
        $rawHash = Get-Sha256 (Get-ProjectPath ([string]$record.raw) -MustExist)
        [void]$lines.Add((U ("| `{0}` | `{1}` | \u672a\u4fee\u6539 | \u2014 \u65e0\u53d8\u66f4 | \u2014 raw \u672a\u4fee\u6539 | \u65e0\u9700\u89e6\u53d1\uff08raw \u672a\u4fee\u6539\uff09 | \u672a\u4fee\u6539 | \u672a\u62c6\u5206\uff08\u9ed8\u8ba4\uff09 |" -f $record.raw, $rawHash)))
    }
    foreach ($heading in @(
        (U '## \u5168\u5e93\u7b5b\u9009'),
        (U '## \u56de\u8bfb\u68c0\u67e5'),
        (U '## \u5f02\u5e38\u5904\u7406'),
        (U '## \u603b\u7ed3\u62a5\u544a')
    )) {
        [void]$lines.Add('')
        [void]$lines.Add($heading)
        [void]$lines.Add('')
        [void]$lines.Add('TODO')
    }
    [void]$lines.Add('')
    [void]$lines.Add('CONTENT_BACKTEST_OPEN_V1')
    Write-Utf8File -Path $full -Text (($lines -join "`n") + "`n")
    return $full
}

function Get-ContentAuditRows {
    param([string]$Text)
    $heading = U '### \u5168\u6587\u6620\u5c04\u5ba1\u6838'
    $section = [regex]::Match($Text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^##\s|^###\s|\z)')
    if (-not $section.Success -or -not $section.Groups['body'].Value.Contains('SOURCE_CONTENT_AUDIT_V4')) { throw 'Content backtest is missing full-source audit evidence.' }
    $table = @($section.Groups['body'].Value -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') })
    if ($table.Count -lt 3) { throw 'Content backtest full-source audit table has no data rows.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($table | Select-Object -Skip 2)) {
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 6) { throw 'Content backtest full-source audit row must have six columns.' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq 'TODO') { throw 'Content backtest full-source audit row is incomplete.' }
        }
        [void]$rows.Add([pscustomobject][ordered]@{
            raw=$cells[0].Trim('`')
            manifest=$cells[1].Trim('`')
            review=$cells[2].Trim('`')
            receipt=$cells[3].Trim('`')
            unit_count=[int]$cells[4]
            conclusion=$cells[5]
        })
    }
    return @($rows.ToArray())
}

function Get-SampleStyleRows {
    param([string]$Text)
    $heading = U '### \u6837\u4f8b\u56de\u8bfb'
    $section = [regex]::Match($Text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^##\s|^###\s|\z)')
    if (-not $section.Success) { throw 'Content backtest is missing sample-style reread evidence.' }
    foreach ($sample in @(
        (U 'raw-sources/\u4ece0\u52301\u521b\u9020\u5f00\u653e\u4e16\u754c\u8bbe\u8ba1\u6d41\u7a0b-\u5929\u7f8e\u6c5f\u5cb8\u6816-20260705.md'),
        (U 'raw-sources/Game Master-\u5a01\u5c14\u83b1\u7279\u6e38\u620f\u5927\u5e08-indienova-\u843d\u65e5\u95f4-20061106.md'),
        (U 'raw-sources/\u6e38\u620f\u5206\u6790(\u56db\u4e94)-\u6697\u9ed1\u7cfb\u5217\u4e3a\u4ec0\u4e48\u597d\u73a9-\u6e38\u620f\u8bbe\u8ba1\u7406\u8bba-20230701.md')
    )) {
        if ($Standard -eq 'v1' -or $sample -notmatch 'Game Master|20230701') {
            if ($Standard -eq 'v2' -and -not (Test-Path -LiteralPath (Join-Path $script:projectRoot $sample))) { $sample = 'system/maintenance/checklists/raw-writing-v2.md' }
            if (-not $section.Groups['body'].Value.Contains($sample)) { throw "Content backtest sample-style evidence is missing structure/style sample: $sample" }
        }
    }
    if (-not $section.Groups['body'].Value.Contains('SAMPLE_STYLE_REREAD_V1')) { throw 'Content backtest sample-style evidence marker is missing.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($section.Groups['body'].Value -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') } | Select-Object -Skip 2)) {
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 4) { throw 'Content backtest sample-style row must have four columns.' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq 'TODO') { throw 'Content backtest sample-style row is incomplete.' }
        }
        [void]$rows.Add([pscustomobject][ordered]@{ raw=$cells[0].Trim('`'); conclusion=$cells[3] })
    }
    if ($rows.Count -eq 0) { throw 'Content backtest sample-style reread has no data rows.' }
    return @($rows.ToArray())
}

function Get-ScoringRows {
    param([string]$Text)
    $heading = U '### A \u7c7b\u4ece\u96f6\u8bc4\u5206'
    $section = [regex]::Match($Text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^##\s|^###\s|\z)')
    if (-not $section.Success -or -not $section.Groups['body'].Value.Contains('A_CLASS_RESCORING_V1')) {
        throw 'Content backtest is missing A-class rescoring evidence.'
    }
    $table = @($section.Groups['body'].Value -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') })
    if ($table.Count -lt 3) { throw 'Content backtest A-class rescoring table has no data rows.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($table | Select-Object -Skip 2)) {
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 9) { throw 'Content backtest A-class rescoring row must have nine columns.' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq 'TODO') { throw 'Content backtest A-class rescoring row is incomplete.' }
        }
        $raw = $cells[0].Trim('`')
        $oldA = ConvertTo-InvariantDouble -Value $cells[1] -Label "$raw old_a"
        $a1 = ConvertTo-InvariantDouble -Value $cells[2] -Label "$raw A1"
        $a2 = ConvertTo-InvariantDouble -Value $cells[3] -Label "$raw A2"
        $a3 = ConvertTo-InvariantDouble -Value $cells[4] -Label "$raw A3"
        $newA = ConvertTo-InvariantDouble -Value $cells[5] -Label "$raw new_a"
        $deviation = ConvertTo-InvariantDouble -Value $cells[6] -Label "$raw deviation"
        if ($a1 -lt 0 -or $a1 -gt 5 -or $a1 -ne [Math]::Truncate($a1) -or
            $a2 -lt 0 -or $a2 -gt 5 -or $a2 -ne [Math]::Truncate($a2)) {
            throw "Content backtest A1/A2 must be integers from 0 to 5: $raw"
        }
        if (@(0.85, 0.95, 1.0) -notcontains $a3) { throw "Content backtest A3 must be 0.85, 0.95, or 1.00: $raw" }
        $expectedNew = [decimal]::Round(([decimal]$a1 + [decimal]$a2) * [decimal]$a3, 1, [MidpointRounding]::AwayFromZero)
        $expectedDeviation = [decimal]::Round([Math]::Abs($expectedNew - [decimal]$oldA), 1, [MidpointRounding]::AwayFromZero)
        if ([Math]::Abs($newA - $expectedNew) -gt 0.001) { throw "Content backtest new A calculation mismatch: $raw" }
        if ([Math]::Abs($deviation - $expectedDeviation) -gt 0.001) { throw "Content backtest deviation calculation mismatch: $raw" }
        [void]$rows.Add([pscustomobject][ordered]@{
            raw_path = $raw
            old_a = $oldA
            a1 = [int]$a1
            a2 = [int]$a2
            a3 = $a3
            new_a = $newA
            deviation = $deviation
            disposition = $cells[7]
            evidence = $cells[8]
        })
    }
    return @($rows.ToArray())
}

function Get-RawWikiImpactRows {
    param([string]$Text)
    $heading = U '### raw \u4fee\u590d\u4e0e Wiki \u5f71\u54cd\u590d\u6838'
    $section = [regex]::Match($Text, '(?ms)^' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^##\s|^###\s|\z)')
    if (-not $section.Success) { throw 'Content backtest is missing raw-repair and Wiki-impact evidence.' }
    $table = @($section.Groups['body'].Value -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') })
    if ($table.Count -lt 3) { throw 'Content backtest raw-repair and Wiki-impact table has no data rows.' }
    $rows = New-Object System.Collections.Generic.List[object]
    $unchanged = U '\u672a\u4fee\u6539'
    $modifiedPattern = U '^(?:\u5df2\u4fee\u590d|\u5df2\u4fee\u6539|\u5df2\u8865\u5199|\u5df2\u6821\u6b63)'
    $noChangeEvidence = U '^\u2014\s*\u65e0\u53d8\u66f4$'
    $defaultNoSplit = U '\u672a\u62c6\u5206\uff08\u9ed8\u8ba4\uff09'
    $explicitSplit = U '^\u5df2\u660e\u786e\u6388\u6743[:\uff1a]\s*\S+'
    $wikiReviewPattern = U '(?:\u65e0\u9700\u8865\u5145|\u9700\u8865\u5145|\u5df2\u8865\u5145)'
    foreach ($line in @($table | Select-Object -Skip 2)) {
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 8) { throw 'Content backtest raw-repair and Wiki-impact row must have eight columns.' }
        foreach ($cell in $cells) {
            if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq 'TODO') { throw 'Content backtest raw-repair and Wiki-impact row is incomplete.' }
        }
        $raw = $cells[0].Trim('`')
        $plannedHash = $cells[1].Trim('`').ToLowerInvariant()
        if ($plannedHash -notmatch '^[0-9a-f]{64}$') { throw "Content backtest raw baseline hash is invalid: $raw" }
        $rawFull = Get-ProjectPath $raw -MustExist
        $currentHash = Get-Sha256 $rawFull
        $changed = $currentHash -ne $plannedHash
        if ($changed) {
            if ($cells[2] -notmatch $modifiedPattern) { throw "Content backtest changed raw is not recorded as repaired: $raw" }
            if ($cells[3] -match $noChangeEvidence) { throw "Content backtest changed raw is missing change evidence: $raw" }
            if ($cells[5] -notmatch $wikiReviewPattern) { throw "Content backtest changed raw is missing a concrete Wiki review conclusion: $raw" }
        } elseif ($cells[2] -ne $unchanged) {
            throw "Content backtest unchanged raw has an inconsistent disposition: $raw"
        }
        if ($cells[7] -ne $defaultNoSplit -and $cells[7] -notmatch $explicitSplit) {
            throw "Content backtest Wiki split status lacks explicit authorization: $raw"
        }
        [void]$rows.Add([pscustomobject][ordered]@{
            raw = $raw
            planned_sha256 = $plannedHash
            current_sha256 = $currentHash
            raw_changed = $changed
            raw_disposition = $cells[2]
            raw_evidence = $cells[3]
            related_wiki = $cells[4]
            wiki_review = $cells[5]
            wiki_disposition = $cells[6]
            split_authorization = $cells[7]
        })
    }
    return @($rows.ToArray())
}

function Get-FindingRows {
    param([string]$Text)
    $section = [regex]::Match($Text, '(?ms)^### Explicit findings ledger\s*\r?\n(?<body>.*?)(?=^##\s|^###\s|\z)')
    if (-not $section.Success -or -not $section.Groups['body'].Value.Contains('CONTENT_BACKTEST_FINDINGS_V1')) { throw 'V2 content backtest is missing the explicit findings ledger.' }
    $table = @($section.Groups['body'].Value -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') })
    if ($table.Count -lt 3) { throw 'V2 content backtest findings ledger has no data rows.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($table | Select-Object -Skip 2)) {
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 6) { throw 'V2 content backtest finding row must have six columns.' }
        foreach ($cell in $cells) { if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq 'TODO') { throw 'V2 content backtest finding row is incomplete.' } }
        $raw = $cells[0].Trim('`')
        if ($cells[1] -notin @('none','semantic','style','scoring','mechanical')) { throw "Invalid issue_class for $raw" }
        if ($cells[2] -notin @('none','minor','major','critical')) { throw "Invalid severity for $raw" }
        if ($cells[3] -notin @('first_review','repair_validation','repair_introduced','independent_sample')) { throw "Invalid detected_stage for $raw" }
        if ($cells[4] -notin @('none','open','repaired','accepted')) { throw "Invalid finding status for $raw" }
        if ($cells[1] -eq 'none' -and ($cells[2] -ne 'none' -or $cells[4] -ne 'none')) { throw "A no-finding row must use none severity and status: $raw" }
        if ($cells[1] -ne 'none' -and ($cells[2] -eq 'none' -or $cells[4] -eq 'none')) { throw "A finding row must declare severity and status: $raw" }
        [void]$rows.Add([pscustomobject][ordered]@{ raw=$raw; issue_class=$cells[1]; severity=$cells[2]; detected_stage=$cells[3]; status=$cells[4]; evidence=$cells[5] })
    }
    return @($rows.ToArray())
}

try {
    if ([string]::IsNullOrWhiteSpace($RunId)) { throw 'RunId is required.' }
    if ($SampleSize -lt 1 -or $SampleSize -gt 50) { throw 'SampleSize must be between 1 and 50.' }
    $enabled = @($Dimensions -split '\|' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })
    $allowed = @('sources', 'modules', 'definitions', 'boundaries', 'implementation', 'enumeration')
    foreach ($dimension in $enabled) { if ($allowed -notcontains $dimension) { throw "Unsupported dimension: $dimension" } }
    $excluded = @($ExcludeRaw -split '\|' | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ -ne '' })
    $included = @($IncludeRaw -split '\|' | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ -ne '' })
    $historicalExcluded = @()
    $minimumAgeExcluded = @()
    if ($included.Count -eq 0) {
        $historicalExcluded = @(Get-HistoricalBacktestRawPaths)
        $minimumAgeExcluded = @(Get-RecentOrUntrackedRawPaths -MinimumAgeDays $MinimumIngestAgeDays)
        $excluded = @($excluded + $historicalExcluded + $minimumAgeExcluded | Sort-Object -Unique)
    }

    if ($Action -in @('plan', 'screen')) {
        $records = @(Get-Candidates -Enabled $enabled -Excluded $excluded -Included $included | Select-Object -First $SampleSize)
        if ($records.Count -eq 0) { throw 'No content-backtest candidates were selected.' }
        $full = Write-Plan -Records $records -Path $OutputPath -IsScreen ($Action -eq 'screen')
        $publicRecords = @($records | Select-Object raw, old_a, source, source_origins, source_available, raw_chars, source_chars, compression_ratio, source_headings, raw_headings, risk_score, signals, tie_break)
        Write-Output ([pscustomobject][ordered]@{
            status = 'planned'
            action = $Action
            run_id = $RunId
            sample_count = $records.Count
            historical_exclusion_count = $historicalExcluded.Count
            minimum_age_exclusion_count = $minimumAgeExcluded.Count
            output_path = Get-RelativePath $full
            candidates = @($publicRecords)
            reused_receipt_count = $(if ($Action -eq 'plan' -and $Standard -eq 'v2') {
                $reportText = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
                [regex]::Matches($reportText, 'reused: same raw, source, and ruleset hashes').Count
            } else { 0 })
        } | ConvertTo-Json -Depth 20)
        exit 0
    }

    $reportFull = Get-ProjectPath $ReportPath -MustExist
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $reportFull
    foreach ($marker in @('CONTENT_BACKTEST_V1', 'CONTENT_BACKTEST_CLOSED_V1')) {
        if (-not $text.Contains($marker)) { throw "Content backtest is missing marker: $marker" }
    }
    if ($text.Contains('TODO') -or $text.Contains('CONTENT_BACKTEST_OPEN_V1')) { throw 'Content backtest still contains open placeholders.' }
    foreach ($heading in @(
        (U '## \u5168\u5e93\u7b5b\u9009'),
        (U '## \u56de\u8bfb\u68c0\u67e5'),
        (U '## \u5f02\u5e38\u5904\u7406'),
        (U '## \u603b\u7ed3\u62a5\u544a')
    )) {
        if (-not $text.Contains($heading)) { throw "Content backtest is missing section: $heading" }
    }
    $auditRows = @(Get-ContentAuditRows -Text $text)
    $scoringRows = @(Get-ScoringRows -Text $text)
    $impactRows = @(Get-RawWikiImpactRows -Text $text)
    if ($scoringRows.Count -ne $auditRows.Count) { throw "Content backtest A-class rescoring coverage is incomplete: $($scoringRows.Count) rows for $($auditRows.Count) reviewed raw files." }
    if ($impactRows.Count -ne $auditRows.Count) { throw "Content backtest raw/Wiki impact coverage is incomplete: $($impactRows.Count) rows for $($auditRows.Count) reviewed raw files." }
    foreach ($row in $auditRows) {
        if (@($scoringRows | Where-Object { [string]$_.raw_path -eq [string]$row.raw }).Count -ne 1) { throw "Content backtest A-class rescoring table has no unique matching row: $($row.raw)" }
        if (@($impactRows | Where-Object { [string]$_.raw -eq [string]$row.raw }).Count -ne 1) { throw "Content backtest raw/Wiki impact table has no matching review row: $($row.raw)" }
    }
    $auditReceipts = New-Object System.Collections.Generic.List[object]
    $reusedReceiptCount = 0
    $currentAuditRoot = Get-RelativePath (Join-Path (Split-Path -Parent $reportFull) 'backtest-source-audits')
    foreach ($auditRow in $auditRows) {
        if ($Standard -eq 'v2') {
            $auditOutput = @(& node (Join-Path $PSScriptRoot 'backtest-quality.mjs') verify --root $projectRoot --receipt ([string]$auditRow.receipt)) -join "`n"
            if ($LASTEXITCODE -ne 0) { throw "Unified Raw v2 backtest verification failed: $auditOutput" }
        } else {
            $auditOutput = Invoke-SourceAudit @('-Action','validate','-Mode','backtest','-ReviewPath',[string]$auditRow.review,'-ReceiptPath',[string]$auditRow.receipt)
        }
        $auditReceipt = $auditOutput | ConvertFrom-Json
        if ($Standard -eq 'v2' -and ([int]$auditReceipt.schema_version -ne 6 -or $auditReceipt.standard -ne 'RAW_STANDARD_V2' -or $auditReceipt.ruleset -ne 'core-semantic-20260910' -or $auditReceipt.mode -ne 'backtest' -or $auditReceipt.evidence_class -notin @('host_observed','reviewer_attested'))) { throw 'V2 backtest requires real independent current-ruleset schema6 evidence in backtest mode.' }
        if ([int]$auditReceipt.schema_version -lt 4 -or
            $auditReceipt.PSObject.Properties.Name -notcontains 'coverage_counts' -or
            $auditReceipt.PSObject.Properties.Name -notcontains 'retention_policy_counts' -or
            [string]$auditReceipt.status -ne 'passed' -or
            [int]$auditReceipt.failed_unit_count -ne 0 -or
            [int]$auditReceipt.unit_count -ne [int]$auditRow.unit_count) {
            throw "Content backtest full-source audit did not pass: $($auditRow.raw)"
        }
        if ([string]$auditReceipt.raw_path -ne [string]$auditRow.raw) { throw "Content backtest full-source audit raw mismatch: $($auditRow.raw)" }
        $receiptFull = Get-ProjectPath ([string]$auditRow.receipt) -MustExist
        $evidenceMode = if ((Get-RelativePath $receiptFull).StartsWith($currentAuditRoot + '/', [StringComparison]::OrdinalIgnoreCase)) { 'fresh' } else { 'reused_same_hash' }
        if ($evidenceMode -eq 'reused_same_hash') { $reusedReceiptCount++ }
        [void]$auditReceipts.Add([pscustomobject][ordered]@{
            raw_path = [string]$auditRow.raw
            path = Get-RelativePath $receiptFull
            sha256 = Get-Sha256 $receiptFull
            unit_count = [int]$auditReceipt.unit_count
            evidence_mode = $evidenceMode
        })
    }
    $sampleRows = @(Get-SampleStyleRows -Text $text)
    $minimumSampleRows = [Math]::Min(2, $auditRows.Count)
    if ($sampleRows.Count -lt $minimumSampleRows) { throw "Content backtest sample-style evidence is incomplete: $($sampleRows.Count) rows, expected at least $minimumSampleRows." }
    $findingRows = @(if ($Standard -eq 'v2') { Get-FindingRows -Text $text })
    if ($Standard -eq 'v2') {
        foreach ($row in $auditRows) {
            if (@($findingRows | Where-Object { [string]$_.raw -eq [string]$row.raw }).Count -lt 1) { throw "V2 findings ledger has no row for reviewed raw: $($row.raw)" }
        }
        foreach ($finding in $findingRows) {
            if (@($auditRows | Where-Object { [string]$_.raw -eq [string]$finding.raw }).Count -ne 1) { throw "V2 findings ledger references an unreviewed raw: $($finding.raw)" }
        }
    }
    $anomalies = @(if ($Standard -eq 'v2') { $findingRows | Where-Object { [string]$_.issue_class -ne 'none' } })
    foreach ($anomaly in $anomalies) {
        if (@($sampleRows | Where-Object { [string]$_.raw -eq [string]$anomaly.raw }).Count -ne 1) {
            throw "Content backtest style/source-boundary spot-check is missing an anomalous raw: $($anomaly.raw)"
        }
    }
    $receipt = [pscustomobject][ordered]@{
        schema_version = $(if ($Standard -eq 'v2') { 5 } else { 4 })
        raw_standard = $(if ($Standard -eq 'v2') { 'RAW_STANDARD_V2' } else { 'SOURCE_CONTENT_AUDIT_STANDARD_V1' })
        status = 'passed'
        run_id = $RunId
        report_path = Get-RelativePath $reportFull
        report_sha256 = Get-Sha256 $reportFull
        sample_count = $auditRows.Count
        source_content_audit_count = $auditReceipts.Count
        reused_receipt_count = $reusedReceiptCount
        source_content_audits = @($auditReceipts.ToArray())
        scoring_result_count = $scoringRows.Count
        scoring_results = @($scoringRows)
        anomaly_count = $anomalies.Count
        anomaly_raws = @($anomalies | ForEach-Object { $_.raw })
        findings = @($findingRows)
        first_review_finding_count = @($findingRows | Where-Object { $_.issue_class -ne 'none' -and $_.detected_stage -eq 'first_review' }).Count
        repair_residual_count = @($findingRows | Where-Object { $_.issue_class -ne 'none' -and $_.detected_stage -eq 'repair_validation' }).Count
        repair_introduced_count = @($findingRows | Where-Object { $_.issue_class -ne 'none' -and $_.detected_stage -eq 'repair_introduced' }).Count
        raw_repair_count = @($impactRows | Where-Object { $_.raw_changed }).Count
        wiki_review_count = $impactRows.Count
        wiki_update_count = @($impactRows | Where-Object { [string]$_.wiki_disposition -match (U '^(?:\u5df2\u8865\u5145|\u5df2\u4fee\u6539|\u5df2\u66f4\u65b0)') }).Count
        raw_wiki_impacts = @($impactRows)
        validated_at = [DateTime]::UtcNow.ToString('o')
    }
    $receiptFull = Get-ProjectPath $ReceiptPath
    $parent = Split-Path -Parent $receiptFull
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $json = @(($receipt | ConvertTo-Json -Depth 20) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
    [IO.File]::WriteAllText($receiptFull, ($json + "`n"), $utf8NoBom)
    Write-Output ($receipt | ConvertTo-Json -Depth 20)
} catch {
    [Console]::Error.WriteLine("CONTENT_BACKTEST_FAILED: $($_.Exception.Message)")
    exit 2
}
