[CmdletBinding()]
param(
    [ValidateSet('capture', 'framing', 'divergence', 'synthesis', 'convergence')]
    [string]$Category,
    [ValidateSet('ready', 'placeholder', 'rejected')]
    [string]$Status = 'ready',
    [string]$MethodId,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'method-common.ps1')

try {
    $root = Get-MethodProjectRoot -ProjectRoot $ProjectRoot -ScriptPath $MyInvocation.MyCommand.Path
    $validator = Join-Path $scriptRoot 'validate-method.ps1'
    $validationArgs = @('-ProjectRoot', $root)
    if (-not [string]::IsNullOrWhiteSpace($MethodId)) { $validationArgs += @('-MethodId', $MethodId) }
    $null = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $validator @validationArgs)
    Assert-MethodContract -Condition ($LASTEXITCODE -eq 0) -Message 'Method validation failed before listing.'

    $catalog = Read-MethodJson -Path (Join-Path $root 'methods\catalog.json')
    $methods = @($catalog.methods | Where-Object {
        ([string]$_.status -ceq $Status) -and
        ([string]::IsNullOrWhiteSpace($Category) -or [string]$_.category -ceq $Category) -and
        ([string]::IsNullOrWhiteSpace($MethodId) -or [string]$_.method_id -ceq $MethodId)
    } | Sort-Object category, method_id)

    [pscustomobject][ordered]@{
        schema_version = 1
        count = $methods.Count
        selection_note = 'Metadata filter only; semantic method selection remains required.'
        methods = @($methods | ForEach-Object {
            [pscustomobject][ordered]@{
                method_id = [string]$_.method_id
                display_name = [string]$_.display_name
                category = [string]$_.category
                status = [string]$_.status
                path = [string]$_.path
            }
        })
    } | ConvertTo-Json -Depth 8
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
