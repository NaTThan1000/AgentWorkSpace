[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ContentReceiptPath,
    [Parameter(Mandatory = $true)]
    [ValidateRange(10, 1000000)]
    [int]$Anchor,
    [string]$ReviewedAt = '',
    [string]$OutputPath = '',
    [ValidateRange(1, 50)]
    [int]$SampleSize = 6,
    [string]$RuleVersion = 'v2.6+unified-backtest-v4-30x6'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))

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

try {
    if (($Anchor % 30) -ne 0) { throw 'Anchor must be a multiple of 30.' }
    $receiptFull = Get-ProjectPath -Path $ContentReceiptPath -MustExist
    $receipt = Get-Content -Raw -Encoding UTF8 -LiteralPath $receiptFull | ConvertFrom-Json
    if ([string]$receipt.status -ne 'passed') { throw 'Content receipt must have status=passed.' }
    $scoring = @($receipt.scoring_results)
    if ($scoring.Count -ne $SampleSize) { throw "Content receipt must contain exactly $SampleSize scoring results; found $($scoring.Count)." }

    $corrected = U '\u5df2\u6821\u6b63'
    $kept = U '\u4fdd\u6301'
    $samples = foreach ($row in $scoring) {
        $disposition = if ([string]$row.disposition -eq $corrected -or [string]$row.disposition -eq (U '\u4e0b\u8c03') -or [string]$row.disposition -eq (U '\u4e0a\u8c03')) {
            'updated'
        } elseif ([string]$row.disposition -eq $kept) {
            'passed'
        } else {
            throw "Unsupported scoring disposition for $($row.raw_path): $($row.disposition)"
        }
        [pscustomobject][ordered]@{
            source = [string]$row.raw_path
            old_a = [double]$row.old_a
            a1 = [int]$row.a1
            a2 = [int]$row.a2
            a3 = [double]$row.a3
            new_a = [double]$row.new_a
            deviation = [double]$row.deviation
            disposition = $disposition
            evidence = [string]$row.evidence
        }
    }

    if ([string]::IsNullOrWhiteSpace($ReviewedAt)) { $ReviewedAt = (Get-Date).ToString('yyyy-MM-dd') }
    $output = [pscustomobject][ordered]@{
        schema_version = 4
        raw_standard = 'RAW_STANDARD_V2'
        anchor = $Anchor
        samples = @($samples)
        content_review = [pscustomobject][ordered]@{
            path = Get-RelativePath -FullPath $receiptFull
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $receiptFull).Hash.ToLowerInvariant()
            status = 'passed'
        }
        rule_version = $RuleVersion
        reviewed_at = $ReviewedAt
    }
    $json = @(($output | ConvertTo-Json -Depth 10) -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        Write-Output $json
    } else {
        $outputFull = Get-ProjectPath -Path $OutputPath
        [IO.File]::WriteAllText($outputFull, $json + "`n", $utf8NoBom)
        Write-Output ([pscustomobject][ordered]@{ status = 'written'; path = Get-RelativePath -FullPath $outputFull; sample_count = $samples.Count } | ConvertTo-Json)
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("BUILD_BACKTEST_ANCHOR_RECEIPT_FAILED: $($_.Exception.Message)")
    exit 2
}
