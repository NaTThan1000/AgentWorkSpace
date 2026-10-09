[CmdletBinding()]
param([ValidateSet('Check', 'Sync')][string]$Mode = 'Check', [string]$Root = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$groupsRoot = Join-Path $rootPath 'groups'
$quickPath = Join-Path $rootPath 'system/registry/quick-reference.md'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-Scalar([string]$Body, [string]$Field) { $match = [regex]::Match($Body, '(?m)^' + [regex]::Escape($Field) + ':\s*(?<value>[^\r\n#]+?)\s*$'); if ($match.Success) { return $match.Groups['value'].Value.Trim().Trim('"', "'") }; return '' }
function Convert-UnicodeLiteral([string]$Value) { return [regex]::Replace($Value, '\\u([0-9a-fA-F]{4})', { param($match) [char][Convert]::ToInt32($match.Groups[1].Value, 16) }) }

try {
    $records = foreach ($file in @(Get-ChildItem -LiteralPath $groupsRoot -Filter '*.md' -File | Where-Object { $_.Name -notin @('README.md', 'group.template.md') })) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $frontmatter = [regex]::Match($text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
        if (-not $frontmatter.Success) { throw "Group frontmatter missing: $($file.Name)" }
        $body = $frontmatter.Groups['body'].Value
        $id = Get-Scalar $body 'id'; $name = Get-Scalar $body 'name'; $status = Get-Scalar $body 'status'; $approval = Get-Scalar $body 'approval_status'; $maturity = Get-Scalar $body 'maturity'
        if ($status -eq 'active' -and $approval -eq 'approved') { [pscustomobject]@{ id = $id; name = $name; maturity = $maturity } }
    }
    $suffix = Convert-UnicodeLiteral '\uff08'
    $suffix += '{maturity}'
    $suffix += Convert-UnicodeLiteral '\uff1b\u6210\u5458\u4e0e\u8fb9\u754c\u89c1 Group \u5b9a\u4e49\uff09'
    $lines = @($records | Sort-Object name | ForEach-Object { '- [' + $_.name + '](<../../groups/' + $_.id + '.md>)' + $suffix.Replace('{maturity}', $_.maturity) })
    $section = '## ' + (Convert-UnicodeLiteral '\u0057\u0069\u006b\u0069 \u0047\u0072\u006f\u0075\u0070 \u7d22\u5f15') + "`n`n<!-- generated:approved-active-wiki-groups; " + (Convert-UnicodeLiteral '\u4e0d\u6309 Wiki \u5173\u952e\u8bcd\u63a8\u65ad\u6210\u5458') + " -->`n" + ($lines -join "`n") + "`n"
    $quick = Get-Content -Raw -Encoding UTF8 -LiteralPath $quickPath
    $pattern = '(?ms)^##\s+[^\r\n]+\r?\n\r?\n<!-- generated:approved-active-wiki-groups;.*?\z'
    if (-not [regex]::IsMatch($quick, $pattern)) { throw 'Missing terminal generated Wiki Group index section.' }
    $expected = [regex]::Replace($quick, $pattern, $section)
    if ($Mode -eq 'Check') { if ($expected -ne $quick) { throw 'Wiki Group index is stale. Run sync-quick-reference-groups.ps1 -Mode Sync.' }; [pscustomobject]@{ status = 'passed'; active_groups = @($records).Count } | ConvertTo-Json; exit 0 }
    [IO.File]::WriteAllText($quickPath, $expected.Replace("`r`n", "`n"), $utf8NoBom)
    [pscustomobject]@{ status = 'synced'; active_groups = @($records).Count } | ConvertTo-Json
    exit 0
} catch { [Console]::Error.WriteLine("QUICK_REFERENCE_GROUP_SYNC_FAILED: $($_.Exception.Message)"); exit 2 }
