[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$HtmlPath,
  [Parameter(Mandatory = $true)][string]$InlineAssetsPath
)
$ErrorActionPreference = 'Stop'
$resolvedHtml = (Resolve-Path -LiteralPath $HtmlPath).Path
$resolvedAssets = (Resolve-Path -LiteralPath $InlineAssetsPath).Path
$html = [IO.File]::ReadAllText($resolvedHtml)
$assetIndex = @{}
foreach ($asset in ((Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedAssets | ConvertFrom-Json).assets)) {
  $id = [string]$asset.asset_id
  if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9_:.-]*$' -or $id.Contains('__')) { throw "Invalid asset id: $id" }
  if ($assetIndex.ContainsKey($id)) { throw "Duplicate asset id: $id" }
  $uri = [string]$asset.data_uri
  if ($uri -notmatch '^data:[A-Za-z0-9.+/-]+;base64,([A-Za-z0-9+/]*={0,2})$') { throw "Invalid base64 data URI: $id" }
  [void][Convert]::FromBase64String($Matches[1])
  $assetIndex[$id] = $uri
}
$markers = [regex]::Matches($html, '__ASSET_(.+?)__')
foreach ($marker in $markers) {
  $assetId = $marker.Groups[1].Value
  if (-not $assetIndex.ContainsKey($assetId)) { throw "Asset missing from inline index: $assetId" }
  $html = $html.Replace($marker.Value, $assetIndex[$assetId])
}
if ($html.Contains('__ASSET_')) { throw 'Unresolved asset marker' }
[IO.File]::WriteAllText($resolvedHtml, $html, (New-Object Text.UTF8Encoding($false)))
Write-Output "Inlined $($markers.Count) references: $resolvedHtml"
