[CmdletBinding()]
param(
    [string]$PackagePath = '',
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DisplayName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DirectoryName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Purpose,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$Audience,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$Topics,
    [string[]]$ExcludedTopics = @(),
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SourceQuality,
    [string]$DefaultLanguage = 'zh-CN',
    [Parameter(Mandatory = $true)][ValidateSet('yes', 'no')][string]$UseIma,
    [string]$ImaKnowledgeBaseId = '',
    [string]$ImaKnowledgeBaseName = '',
    [switch]$ImaVerified,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if ([string]::IsNullOrWhiteSpace($PackagePath)) { $PackagePath = Join-Path $PSScriptRoot '../..' }

function Write-Utf8Lf {
    param([string]$Path, [string]$Content)
    $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
    [IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Assert-SingleLine {
    param([string]$Name, [string]$Value)
    if ($Value -match "[`r`n]") {
        throw "$Name must be a single-line value."
    }
}

function ConvertTo-YamlScalar {
    param([string]$Value)
    Assert-SingleLine -Name 'YAML value' -Value $Value
    return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-YamlList {
    param([string[]]$Values)
    if ($null -eq $Values -or $Values.Count -eq 0) { return '[]' }
    $items = foreach ($value in $Values) {
        Assert-SingleLine -Name 'List value' -Value $value
        ConvertTo-YamlScalar -Value $value
    }
    return '[' + ($items -join ', ') + ']'
}

function Set-YamlLine {
    param([string]$Text, [string]$Key, [string]$FormattedValue)
    $regex = New-Object System.Text.RegularExpressions.Regex(('(?m)^' + [regex]::Escape($Key) + ':\s*.*$'))
    if (-not $regex.IsMatch($Text)) { throw "KNOWLEDGE_SCOPE.md is missing field: $Key" }
    return $regex.Replace($Text, ($Key + ': ' + $FormattedValue), 1)
}

function Assert-DirectoryName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -ne $Name.Trim()) {
        throw 'DirectoryName cannot be empty or have leading/trailing spaces.'
    }
    if ($Name -eq '.' -or $Name -eq '..' -or $Name.EndsWith('.') -or $Name.EndsWith(' ')) {
        throw 'DirectoryName cannot be a relative path or end with a dot/space.'
    }
    $portableInvalidNameChars = [char[]]'<>:"/\|?*'
    $containsControlCharacter = @($Name.ToCharArray() | Where-Object { [int]$_ -lt 32 }).Count -gt 0
    if ($Name -ne [IO.Path]::GetFileName($Name) -or $Name.IndexOfAny($portableInvalidNameChars) -ge 0 -or $containsControlCharacter) {
        throw 'DirectoryName must be one portable Windows/macOS folder name without reserved characters or path separators.'
    }
    $reserved = @('CON', 'PRN', 'AUX', 'NUL')
    $reserved += 1..9 | ForEach-Object { 'COM' + $_ }
    $reserved += 1..9 | ForEach-Object { 'LPT' + $_ }
    $baseName = $Name.Split('.')[0].ToUpperInvariant()
    if ($reserved -contains $baseName) { throw "DirectoryName is not portable because Windows reserves this name: $Name" }
}

Assert-SingleLine -Name 'DisplayName' -Value $DisplayName
Assert-SingleLine -Name 'Purpose' -Value $Purpose
Assert-SingleLine -Name 'SourceQuality' -Value $SourceQuality
Assert-SingleLine -Name 'DefaultLanguage' -Value $DefaultLanguage
Assert-SingleLine -Name 'ImaKnowledgeBaseId' -Value $ImaKnowledgeBaseId
Assert-SingleLine -Name 'ImaKnowledgeBaseName' -Value $ImaKnowledgeBaseName
Assert-DirectoryName -Name $DirectoryName

if ($Topics.Count -eq 0) { throw 'Initialization requires at least one topic.' }
if ($ImaVerified -and $UseIma -ne 'yes') { throw 'ImaVerified requires UseIma=yes.' }
if ($ImaVerified -and ([string]::IsNullOrWhiteSpace($ImaKnowledgeBaseId) -or [string]::IsNullOrWhiteSpace($ImaKnowledgeBaseName))) {
    throw 'ImaVerified requires both the knowledge base ID and name.'
}

$root = (Resolve-Path -LiteralPath $PackagePath).Path
$originalRoot = $root
$parent = Split-Path -Parent $root
$currentDirectoryName = Split-Path -Leaf $root
$scopeRelativePath = 'system/registry/KNOWLEDGE_SCOPE.md'
$scopePath = Join-Path $root $scopeRelativePath
$scriptPath = Join-Path $root 'system/maintenance/initialize-knowledge.ps1'

if (-not (Test-Path -LiteralPath $scopePath) -or -not (Test-Path -LiteralPath $scriptPath)) {
    throw 'PackagePath is not a valid knowledge base package.'
}

$targetPath = Join-Path $parent $DirectoryName
$sameTargetIgnoringCase = [string]::Equals($targetPath, $root, [StringComparison]::OrdinalIgnoreCase)
if ((Test-Path -LiteralPath $targetPath) -and -not $sameTargetIgnoringCase) {
    throw "Target directory already exists: $targetPath"
}

$changes = New-Object System.Collections.Generic.List[object]
$scopeText = [IO.File]::ReadAllText($scopePath, [Text.Encoding]::UTF8)
$updatedScope = $scopeText
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'configured' -FormattedValue 'true'
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'name' -FormattedValue (ConvertTo-YamlScalar $DisplayName)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'directory_name' -FormattedValue (ConvertTo-YamlScalar $DirectoryName)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'purpose' -FormattedValue (ConvertTo-YamlScalar $Purpose)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'audience' -FormattedValue (ConvertTo-YamlList $Audience)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'topics' -FormattedValue (ConvertTo-YamlList $Topics)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'excluded_topics' -FormattedValue (ConvertTo-YamlList $ExcludedTopics)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'source_quality' -FormattedValue (ConvertTo-YamlScalar $SourceQuality)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'default_language' -FormattedValue (ConvertTo-YamlScalar $DefaultLanguage)
$updatedScope = Set-YamlLine -Text $updatedScope -Key 'ima_enabled' -FormattedValue (($UseIma -eq 'yes').ToString().ToLowerInvariant())

if (-not [string]::Equals($updatedScope, $scopeText, [StringComparison]::Ordinal)) {
    $changes.Add([pscustomobject]@{ RelativePath = $scopeRelativePath; Original = $scopeText; Updated = $updatedScope })
}

$currentNameMatch = [regex]::Match($scopeText, "(?m)^name:\s*'(?<value>(?:''|[^'])*)'\s*$")
if (-not $currentNameMatch.Success) { throw 'KNOWLEDGE_SCOPE.md has an invalid name field.' }
$currentDisplayName = $currentNameMatch.Groups['value'].Value.Replace("''", "'")
$headingFiles = @('README.md', 'AGENTS.md', 'NOW.md')
$headingRegex = New-Object System.Text.RegularExpressions.Regex('(?m)(<!-- knowledge-identity:display-name -->\r?\n)(?<heading># [^\r\n]+)')

foreach ($relativePath in $headingFiles) {
    $path = Join-Path $root $relativePath
    $original = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if (-not $headingRegex.IsMatch($original)) { throw "$relativePath is missing its identity marker." }
    $updated = $headingRegex.Replace($original, {
        param($match)
        $heading = $match.Groups['heading'].Value
        if (-not $heading.Contains($currentDisplayName)) { throw "$relativePath does not contain the current display name." }
        $match.Groups[1].Value + $heading.Replace($currentDisplayName, $DisplayName)
    }, 1)
    if (-not [string]::Equals($updated, $original, [StringComparison]::Ordinal)) {
        $changes.Add([pscustomobject]@{ RelativePath = $relativePath; Original = $original; Updated = $updated })
    }
}

$setupRelativePath = 'system/maintenance/SETUP.md'
$setupPath = Join-Path $root $setupRelativePath
$setupOriginal = [IO.File]::ReadAllText($setupPath, [Text.Encoding]::UTF8)
$setupUpdated = $setupOriginal.Replace($currentDirectoryName, $DirectoryName)
if (-not [string]::Equals($setupUpdated, $setupOriginal, [StringComparison]::Ordinal)) {
    $changes.Add([pscustomobject]@{ RelativePath = $setupRelativePath; Original = $setupOriginal; Updated = $setupUpdated })
}

$imaStatus = 'disabled'
$verifiedAt = $null
if ($UseIma -eq 'yes') {
    if ($ImaVerified) {
        $imaStatus = 'verified'
        $verifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    elseif (-not [string]::IsNullOrWhiteSpace($ImaKnowledgeBaseId) -and -not [string]::IsNullOrWhiteSpace($ImaKnowledgeBaseName)) {
        $imaStatus = 'configured_unverified'
    }
    else {
        $imaStatus = 'pending_auth'
    }
}

$imaConfig = [ordered]@{
    enabled = ($UseIma -eq 'yes')
    status = $imaStatus
    knowledge_base_id = $ImaKnowledgeBaseId
    knowledge_base_name = $ImaKnowledgeBaseName
    last_verified_at = $verifiedAt
}
$imaConfigText = ($imaConfig | ConvertTo-Json -Depth 3) + "`n"
$imaRelativePath = 'system/integrations/ima-config.local.json'
$imaPath = Join-Path $root $imaRelativePath
$imaExisted = Test-Path -LiteralPath $imaPath
$imaOriginal = if ($imaExisted) { [IO.File]::ReadAllText($imaPath, [Text.Encoding]::UTF8) } else { $null }

$parentReferences = @()
Get-ChildItem -LiteralPath $parent -File -Filter '*.md' | ForEach-Object {
    $hits = Select-String -LiteralPath $_.FullName -SimpleMatch $currentDirectoryName
    if ($hits) { $parentReferences += $_.FullName }
}

Write-Output '=== Knowledge initialization plan ==='
Write-Output "Mode: $(if ($Apply) { 'APPLY' } else { 'DRY-RUN' })"
Write-Output "Display name: $DisplayName"
Write-Output "Directory: $currentDirectoryName -> $DirectoryName"
Write-Output "Identity files: $($changes.Count)"
$changes | ForEach-Object { Write-Output ('  - ' + $_.RelativePath) }
Write-Output "IMA: enabled=$($imaConfig.enabled); status=$imaStatus"
Write-Output "Local IMA config: $imaRelativePath"
Write-Output 'Parent references (report only):'
if ($parentReferences.Count -eq 0) { Write-Output '  - none' } else { $parentReferences | ForEach-Object { Write-Output ('  - ' + $_) } }

if (-not $Apply) {
    Write-Output 'No files changed. Re-run with -Apply after review.'
    return
}

$activeRoot = $root
try {
    foreach ($change in $changes) {
        Write-Utf8Lf -Path (Join-Path $activeRoot $change.RelativePath) -Content $change.Updated
    }
    Write-Utf8Lf -Path (Join-Path $activeRoot $imaRelativePath) -Content $imaConfigText

    if (-not [string]::Equals($currentDirectoryName, $DirectoryName, [StringComparison]::Ordinal)) {
        $currentLocation = (Get-Location).ProviderPath
        $separatorChars = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $activeRootPrefix = $activeRoot.TrimEnd($separatorChars) + [IO.Path]::DirectorySeparatorChar
        $isInsideActiveRoot = [string]::Equals($currentLocation, $activeRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $currentLocation.StartsWith($activeRootPrefix, [StringComparison]::OrdinalIgnoreCase)
        if ($isInsideActiveRoot) {
            Set-Location -LiteralPath $parent
        }

        if ($sameTargetIgnoringCase) {
            $tempName = $DirectoryName + '.__rename__.' + ([guid]::NewGuid().ToString('N'))
            Rename-Item -LiteralPath $activeRoot -NewName $tempName
            $activeRoot = Join-Path $parent $tempName
            Rename-Item -LiteralPath $activeRoot -NewName $DirectoryName
            $activeRoot = $targetPath
        }
        else {
            Rename-Item -LiteralPath $activeRoot -NewName $DirectoryName
            $activeRoot = $targetPath
        }
    }

    $allowedResidualFiles = @('system/maintenance/CHANGELOG.md')
    $residuals = New-Object System.Collections.Generic.List[string]
    $displayScanEnabled = -not [string]::Equals($currentDisplayName, $DisplayName, [StringComparison]::Ordinal) -and -not $DisplayName.Contains($currentDisplayName)
    $directoryScanEnabled = -not [string]::Equals($currentDirectoryName, $DirectoryName, [StringComparison]::Ordinal) -and -not $DirectoryName.Contains($currentDirectoryName)
    $directoryPattern = '(^|[^A-Za-z0-9_.-])' + [regex]::Escape($currentDirectoryName) + '([^A-Za-z0-9_.-]|$)'
    Get-ChildItem -LiteralPath $activeRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.md', '.ps1', '.json') -or $_.Name -eq '.gitignore'
    } | ForEach-Object {
        $relative = $_.FullName.Substring($activeRoot.Length).TrimStart('\', '/').Replace('\', '/')
        if ($allowedResidualFiles -contains $relative) { return }
        $text = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
        if ($displayScanEnabled -and $text.Contains($currentDisplayName)) {
            $residuals.Add("${relative}: display name")
        }
        if ($directoryScanEnabled -and [regex]::IsMatch($text, $directoryPattern)) {
            $residuals.Add("${relative}: directory name")
        }
    }
    if ($residuals.Count -gt 0) {
        throw ('Old identity remains outside the whitelist: ' + (($residuals | Sort-Object -Unique) -join ', '))
    }
}
catch {
    if (-not [string]::Equals($activeRoot, $originalRoot, [StringComparison]::Ordinal) -and (Test-Path -LiteralPath $activeRoot)) {
        Set-Location -LiteralPath $parent
        if ([string]::Equals($activeRoot, $originalRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $rollbackTempName = $currentDirectoryName + '.__rollback__.' + ([guid]::NewGuid().ToString('N'))
            Rename-Item -LiteralPath $activeRoot -NewName $rollbackTempName
            $activeRoot = Join-Path $parent $rollbackTempName
        }
        Rename-Item -LiteralPath $activeRoot -NewName $currentDirectoryName
        $activeRoot = $originalRoot
    }
    foreach ($change in $changes) {
        Write-Utf8Lf -Path (Join-Path $activeRoot $change.RelativePath) -Content $change.Original
    }
    $rollbackImaPath = Join-Path $activeRoot $imaRelativePath
    if ($imaExisted) {
        Write-Utf8Lf -Path $rollbackImaPath -Content $imaOriginal
    }
    elseif (Test-Path -LiteralPath $rollbackImaPath) {
        Remove-Item -LiteralPath $rollbackImaPath -Force
    }
    throw
}

Write-Output "Applied successfully. New knowledge base path: $activeRoot"
Write-Output 'Old identity residual scan: PASS'
Write-Output 'Re-enter the new path and run system/maintenance/checklists/initialization-check.md plus system/maintenance/checklists/run-release-contract.ps1.'
