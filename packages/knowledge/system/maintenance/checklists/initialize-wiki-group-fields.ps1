[CmdletBinding()]
param(
    [ValidateSet('Check', 'Sync')][string]$Mode = 'Check',
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path $PSScriptRoot '../../..' }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$wikiRoot = Join-Path $rootPath 'wiki'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Test-GroupsField([string]$Text) {
    $frontmatter = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { throw 'Wiki frontmatter missing.' }
    return $frontmatter.Groups['body'].Value -match '(?m)^groups:\s*(?:\[[^\]]*\]|\r?$)'
}

function Add-EmptyGroupsField([string]$Text) {
    if (Test-GroupsField $Text) { return $Text }
    $frontmatter = [regex]::Match($Text, '(?ms)\A---\s*\r?\n(?<body>.*?)\r?\n---')
    if (-not $frontmatter.Success) { throw 'Wiki frontmatter missing.' }
    $body = $frontmatter.Groups['body'].Value
    $updatedBody = [regex]::Replace($body, '(?m)^(domains:\s*\[[^\r\n]*\]\s*)$', '$1' + "`n" + 'groups: []', 1)
    if ($updatedBody -eq $body) { $updatedBody = 'groups: []' + "`n" + $body }
    return $Text.Substring(0, $frontmatter.Groups['body'].Index) + $updatedBody + $Text.Substring($frontmatter.Groups['body'].Index + $body.Length)
}

try {
    $files = @(Get-ChildItem -LiteralPath $wikiRoot -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' -and $_.Name -notlike '*.template.md' } | Sort-Object Name)
    $missing = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in $files) {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        if (Test-GroupsField $text) { continue }
        [void]$missing.Add('wiki/' + $file.Name)
        if ($Mode -eq 'Sync') { [IO.File]::WriteAllText($file.FullName, (Add-EmptyGroupsField $text).Replace("`r`n", "`n"), $utf8NoBom) }
    }
    [pscustomobject][ordered]@{ status = if ($missing.Count -eq 0) { 'passed' } elseif ($Mode -eq 'Sync') { 'synced' } else { 'needs_sync' }; wiki = $files.Count; missing_before = $missing.Count; changed = if ($Mode -eq 'Sync') { $missing.Count } else { 0 }; paths = @($missing.ToArray()) } | ConvertTo-Json -Depth 4
    if ($Mode -eq 'Check' -and $missing.Count -gt 0) { exit 1 }
    exit 0
} catch {
    [Console]::Error.WriteLine("WIKI_GROUP_FIELD_INITIALIZATION_FAILED: $($_.Exception.Message)")
    exit 2
}
