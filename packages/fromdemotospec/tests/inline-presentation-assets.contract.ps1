[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/inline-presentation-assets.ps1'
$Temp = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('fromdemotospec-inline-' + [guid]::NewGuid().ToString('N'))))
$Utf8 = New-Object Text.UTF8Encoding($false)
function Run-Inline {
    $old = $ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $result = & powershell -NoProfile -ExecutionPolicy Bypass -File $Tool -HtmlPath (Join-Path $Temp 'game.html') -InlineAssetsPath (Join-Path $Temp 'inline.json') 2>&1; $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$old }
    return [pscustomobject]@{code=$code; output=($result -join "`n")}
}
try {
    New-Item -ItemType Directory -Path $Temp | Out-Null
    $html=Join-Path $Temp 'game.html'
    $index=Join-Path $Temp 'inline.json'
    [IO.File]::WriteAllText($index,'{"assets":[{"asset_id":"kenney:ui-pack:ui_button.id-1","data_uri":"data:image/png;base64,YQ=="}]}',$Utf8)
    [IO.File]::WriteAllText($html,'<img src="__ASSET_kenney:ui-pack:ui_button.id-1__">',$Utf8)
    $ok=Run-Inline
    if($ok.code -ne 0 -or [IO.File]::ReadAllText($html) -ne '<img src="data:image/png;base64,YQ==">') { throw "Inline failed: $($ok.output)" }
    foreach($bad in @('__ASSET_missing__','__ASSET_incomplete')) {
        [IO.File]::WriteAllText($html,$bad,$Utf8)
        $negative=Run-Inline
        if($negative.code -eq 0 -or [IO.File]::ReadAllText($html) -ne $bad) { throw 'Missing markers must fail without modifying HTML' }
    }
    [IO.File]::WriteAllText($index,'{"assets":[{"asset_id":"a","data_uri":"data:image/png;base64,YQ=="},{"asset_id":"a","data_uri":"data:image/png;base64,Yg=="}]}',$Utf8)
    if((Run-Inline).code -eq 0) { throw 'Duplicate asset id accepted' }
    Write-Output 'PASS inline-presentation-assets.contract'
} finally {
    $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not $Temp.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temp cleanup' }
    if(Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Recurse -Force }
}
