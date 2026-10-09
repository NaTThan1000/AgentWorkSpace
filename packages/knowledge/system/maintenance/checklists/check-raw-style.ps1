[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string[]]$Path,
  [ValidateSet('v1','v2')][string]$Standard = 'v2',
  [int]$MaxPlainSections = 0,
  [int]$MaxCompactParagraphChars = 140,
  [int]$MaxCompactSectionChars = 280
)
$ErrorActionPreference = 'Stop'
if ($Standard -eq 'v1') {
  & (Join-Path $PSScriptRoot 'check-raw-style-v1.ps1') -Path $Path -MaxPlainSections $MaxPlainSections -MaxCompactParagraphChars $MaxCompactParagraphChars -MaxCompactSectionChars $MaxCompactSectionChars
  exit $LASTEXITCODE
}
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$failed = $false
foreach ($item in @($Path | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  & node (Join-Path $PSScriptRoot 'raw-quality.mjs') style --root $root --raw $item
  if ($LASTEXITCODE -ne 0) { $failed = $true }
}
if ($failed) { exit 1 }
exit 0
