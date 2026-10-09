[CmdletBinding()]
param(
    [string]$PackagePath = '',
    [string]$AnswerFile = '',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
if ([string]::IsNullOrWhiteSpace($PackagePath)) { $PackagePath = Join-Path $PSScriptRoot '../..' }

function Read-JsonUtf8 {
    param([string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    return ([IO.File]::ReadAllText($resolved, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Get-ObjectProperty {
    param([object]$Object, [string]$Name, [bool]$Required = $true, [object]$DefaultValue = $null)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        if ($Required) { throw "Answer file is missing field: $Name" }
        return $DefaultValue
    }
    return $property.Value
}

function Get-Question {
    param([string]$Key)
    $property = $script:strings.questions.PSObject.Properties[$Key]
    if ($null -eq $property) { throw "Wizard text is missing question: $Key" }
    return $property.Value
}

function Get-Choices {
    param([string]$Key)
    $property = $script:strings.choices.PSObject.Properties[$Key]
    if ($null -eq $property) { throw "Wizard text is missing choices: $Key" }
    return @($property.Value)
}

function New-AnswerResult {
    param([string]$Action, [object]$Value = $null)
    return [pscustomobject]@{ Action = $Action; Value = $Value }
}

function Stop-Wizard {
    Write-Host ''
    Write-Host $script:strings.labels.cancelled
    exit 0
}

function Write-Question {
    param([object]$Question)
    Write-Host ''
    Write-Host $Question.title
    Write-Host ('  ' + $Question.why)
    Write-Host ('  ' + $script:strings.labels.example + ': ' + $Question.example)
}

function Read-TextAnswer {
    param(
        [string]$QuestionKey,
        [string]$DefaultValue = '',
        [bool]$AllowEmpty = $false
    )
    $question = Get-Question -Key $QuestionKey
    while ($true) {
        Write-Question -Question $question
        if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            Write-Host ('  ' + $script:strings.labels.recommended + ': ' + $DefaultValue)
        }
        Write-Host ('  ' + $script:strings.labels.controls)
        $inputValue = Read-Host $script:strings.labels.input
        $command = $inputValue.Trim().ToUpperInvariant()
        if ($command -eq 'Q') { Stop-Wizard }
        if ($command -eq 'B') { return New-AnswerResult -Action 'Back' }
        if ($command -eq '?') {
            Write-Host ('  ' + $script:strings.labels.help + ': ' + $question.help)
            continue
        }
        if ($command -eq 'S' -or [string]::IsNullOrWhiteSpace($inputValue)) {
            if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
                return New-AnswerResult -Action 'Value' -Value $DefaultValue
            }
            if ($AllowEmpty) { return New-AnswerResult -Action 'Value' -Value '' }
            Write-Host $script:strings.labels.required
            continue
        }
        return New-AnswerResult -Action 'Value' -Value $inputValue.Trim()
    }
}

function Read-ChoiceAnswer {
    param(
        [string]$QuestionKey,
        [string]$ChoiceKey,
        [string]$DefaultKey
    )
    $question = Get-Question -Key $QuestionKey
    $choices = Get-Choices -Key $ChoiceKey
    while ($true) {
        Write-Question -Question $question
        foreach ($choice in $choices) {
            $suffix = if ($choice.key -eq $DefaultKey) { ' ' + $script:strings.labels.recommended_mark } else { '' }
            Write-Host ("  $($choice.key). $($choice.label)$suffix")
        }
        Write-Host ('  ' + $script:strings.labels.controls)
        $inputValue = (Read-Host $script:strings.labels.input).Trim()
        $command = $inputValue.ToUpperInvariant()
        if ($command -eq 'Q') { Stop-Wizard }
        if ($command -eq 'B') { return New-AnswerResult -Action 'Back' }
        if ($command -eq '?') {
            Write-Host ('  ' + $script:strings.labels.help + ': ' + $question.help)
            continue
        }
        if ($command -eq 'S' -or [string]::IsNullOrWhiteSpace($inputValue)) { $inputValue = $DefaultKey }
        $selected = @($choices | Where-Object { $_.key -eq $inputValue })
        if ($selected.Count -ne 1) {
            Write-Host $script:strings.labels.invalid_choice
            continue
        }
        return New-AnswerResult -Action 'Value' -Value $selected[0].value
    }
}

function ConvertTo-StringList {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        $separatorPattern = '[,' + [char]0xFF0C + ']'
        return @([regex]::Split($Value, $separatorPattern) | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
    }
    return @($Value | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
}

function Read-CustomChoice {
    param([string]$ChoiceValue, [string]$CustomQuestionKey, [bool]$AsList = $false)
    if ($ChoiceValue -ne '__custom__') { return New-AnswerResult -Action 'Value' -Value $ChoiceValue }
    $result = Read-TextAnswer -QuestionKey $CustomQuestionKey
    if ($result.Action -eq 'Back') { return $result }
    if ($AsList) { $result.Value = ConvertTo-StringList -Value $result.Value }
    return $result
}

function Read-InteractiveAnswers {
    $answers = [ordered]@{
        DisplayName = ''
        DirectoryName = ''
        Purpose = ''
        Audience = @()
        Topics = @()
        ExcludedTopics = @()
        SourceQuality = $script:strings.defaults.source_quality
        DefaultLanguage = 'zh-CN'
        UseIma = 'no'
        ImaKnowledgeBaseId = ''
        ImaKnowledgeBaseName = ''
        ImaVerified = $false
        Advanced = $false
    }

    Write-Host $script:strings.labels.welcome
    Write-Host $script:strings.labels.welcome_detail
    $step = 0
    while ($step -lt 10) {
        $result = $null
        switch ($step) {
            0 {
                $result = Read-TextAnswer -QuestionKey 'display_name' -DefaultValue $script:strings.defaults.display_name
                if ($result.Action -eq 'Value') { $answers.DisplayName = $result.Value }
            }
            1 {
                $result = Read-TextAnswer -QuestionKey 'directory_name' -DefaultValue 'my-knowledge-base'
                if ($result.Action -eq 'Value') { $answers.DirectoryName = $result.Value }
            }
            2 {
                $result = Read-ChoiceAnswer -QuestionKey 'purpose' -ChoiceKey 'purpose' -DefaultKey '1'
                if ($result.Action -eq 'Value') { $result = Read-CustomChoice -ChoiceValue $result.Value -CustomQuestionKey 'purpose_custom' }
                if ($result.Action -eq 'Value') { $answers.Purpose = $result.Value }
            }
            3 {
                $result = Read-ChoiceAnswer -QuestionKey 'audience' -ChoiceKey 'audience' -DefaultKey '1'
                if ($result.Action -eq 'Value') { $result = Read-CustomChoice -ChoiceValue $result.Value -CustomQuestionKey 'audience_custom' -AsList $true }
                if ($result.Action -eq 'Value') { $answers.Audience = @(ConvertTo-StringList -Value $result.Value) }
            }
            4 {
                $result = Read-TextAnswer -QuestionKey 'topics'
                if ($result.Action -eq 'Value') {
                    $topics = @(ConvertTo-StringList -Value $result.Value)
                    if ($topics.Count -eq 0) { Write-Host $script:strings.labels.required; continue }
                    $answers.Topics = $topics
                }
            }
            5 {
                $result = Read-ChoiceAnswer -QuestionKey 'ima' -ChoiceKey 'ima' -DefaultKey '1'
                if ($result.Action -eq 'Value') {
                    $answers.UseIma = if ($result.Value -eq 'disabled') { 'no' } else { 'yes' }
                    $answers.ImaVerified = ($result.Value -eq 'verified')
                    $answers.ImaKnowledgeBaseId = ''
                    $answers.ImaKnowledgeBaseName = ''
                    if ($result.Value -in @('configured', 'verified')) {
                        $idResult = Read-TextAnswer -QuestionKey 'ima_id'
                        if ($idResult.Action -eq 'Back') { $result = $idResult; break }
                        $nameResult = Read-TextAnswer -QuestionKey 'ima_name'
                        if ($nameResult.Action -eq 'Back') { $result = $nameResult; break }
                        $answers.ImaKnowledgeBaseId = $idResult.Value
                        $answers.ImaKnowledgeBaseName = $nameResult.Value
                    }
                }
            }
            6 {
                $result = Read-ChoiceAnswer -QuestionKey 'advanced' -ChoiceKey 'yes_no' -DefaultKey '1'
                if ($result.Action -eq 'Value') {
                    $answers.Advanced = ($result.Value -eq 'yes')
                    if (-not $answers.Advanced) {
                        $answers.ExcludedTopics = @()
                        $answers.SourceQuality = $script:strings.defaults.source_quality
                        $answers.DefaultLanguage = 'zh-CN'
                        $step = 9
                    }
                }
            }
            7 {
                $result = Read-TextAnswer -QuestionKey 'excluded_topics' -AllowEmpty $true
                if ($result.Action -eq 'Value') { $answers.ExcludedTopics = @(ConvertTo-StringList -Value $result.Value) }
            }
            8 {
                $result = Read-ChoiceAnswer -QuestionKey 'source_quality' -ChoiceKey 'source_quality' -DefaultKey '2'
                if ($result.Action -eq 'Value') { $answers.SourceQuality = $result.Value }
            }
            9 {
                $result = Read-ChoiceAnswer -QuestionKey 'language' -ChoiceKey 'language' -DefaultKey '1'
                if ($result.Action -eq 'Value') { $result = Read-CustomChoice -ChoiceValue $result.Value -CustomQuestionKey 'language_custom' }
                if ($result.Action -eq 'Value') { $answers.DefaultLanguage = $result.Value }
            }
        }

        if ($result.Action -eq 'Back') {
            $step = [Math]::Max(0, $step - 1)
            continue
        }
        $step++
    }
    return $answers
}

function Read-AnswerFileValues {
    param([string]$Path)
    $config = Read-JsonUtf8 -Path $Path
    return [ordered]@{
        DisplayName = [string](Get-ObjectProperty -Object $config -Name 'DisplayName')
        DirectoryName = [string](Get-ObjectProperty -Object $config -Name 'DirectoryName')
        Purpose = [string](Get-ObjectProperty -Object $config -Name 'Purpose')
        Audience = @(ConvertTo-StringList -Value (Get-ObjectProperty -Object $config -Name 'Audience'))
        Topics = @(ConvertTo-StringList -Value (Get-ObjectProperty -Object $config -Name 'Topics'))
        ExcludedTopics = @(ConvertTo-StringList -Value (Get-ObjectProperty -Object $config -Name 'ExcludedTopics' -Required $false -DefaultValue @()))
        SourceQuality = [string](Get-ObjectProperty -Object $config -Name 'SourceQuality' -Required $false -DefaultValue $script:strings.defaults.source_quality)
        DefaultLanguage = [string](Get-ObjectProperty -Object $config -Name 'DefaultLanguage' -Required $false -DefaultValue 'zh-CN')
        UseIma = [string](Get-ObjectProperty -Object $config -Name 'UseIma')
        ImaKnowledgeBaseId = [string](Get-ObjectProperty -Object $config -Name 'ImaKnowledgeBaseId' -Required $false -DefaultValue '')
        ImaKnowledgeBaseName = [string](Get-ObjectProperty -Object $config -Name 'ImaKnowledgeBaseName' -Required $false -DefaultValue '')
        ImaVerified = [bool](Get-ObjectProperty -Object $config -Name 'ImaVerified' -Required $false -DefaultValue $false)
    }
}

function Write-AnswerSummary {
    param([System.Collections.IDictionary]$Answers)
    $audience = @($Answers.Audience)
    $topics = @($Answers.Topics)
    $excludedTopics = @($Answers.ExcludedTopics)
    Write-Host ''
    Write-Host $script:strings.labels.summary
    Write-Host ('  ' + $script:strings.labels.summary_name + ': ' + $Answers.DisplayName)
    Write-Host ('  ' + $script:strings.labels.summary_directory + ': ' + $Answers.DirectoryName)
    Write-Host ('  ' + $script:strings.labels.summary_purpose + ': ' + $Answers.Purpose)
    Write-Host ('  ' + $script:strings.labels.summary_audience + ': ' + ($audience -join ', '))
    Write-Host ('  ' + $script:strings.labels.summary_topics + ': ' + ($topics -join ', '))
    Write-Host ('  ' + $script:strings.labels.summary_excluded + ': ' + $(if ($excludedTopics.Count -eq 0) { $script:strings.labels.none } else { $excludedTopics -join ', ' }))
    Write-Host ('  ' + $script:strings.labels.summary_source + ': ' + $Answers.SourceQuality)
    Write-Host ('  ' + $script:strings.labels.summary_language + ': ' + $Answers.DefaultLanguage)
    Write-Host ('  ' + $script:strings.labels.summary_ima + ': ' + $Answers.UseIma)
}

function Invoke-Initializer {
    param([System.Collections.IDictionary]$Answers, [bool]$DoApply)
    $enginePath = Join-Path $PSScriptRoot 'initialize-knowledge.ps1'
    $parameters = @{
        PackagePath = $PackagePath
        DisplayName = $Answers.DisplayName
        DirectoryName = $Answers.DirectoryName
        Purpose = $Answers.Purpose
        Audience = [string[]]$Answers.Audience
        Topics = [string[]]$Answers.Topics
        ExcludedTopics = [string[]]$Answers.ExcludedTopics
        SourceQuality = $Answers.SourceQuality
        DefaultLanguage = $Answers.DefaultLanguage
        UseIma = $Answers.UseIma
        ImaKnowledgeBaseId = $Answers.ImaKnowledgeBaseId
        ImaKnowledgeBaseName = $Answers.ImaKnowledgeBaseName
        ImaVerified = [bool]$Answers.ImaVerified
    }
    if ($DoApply) { $parameters.Apply = $true }
    & $enginePath @parameters
}

$textPath = Join-Path $PSScriptRoot 'setup-wizard.zh-CN.json'
$script:strings = Read-JsonUtf8 -Path $textPath

if (-not [string]::IsNullOrWhiteSpace($AnswerFile)) {
    $answers = Read-AnswerFileValues -Path $AnswerFile
}
else {
    $answers = Read-InteractiveAnswers
}

Write-AnswerSummary -Answers $answers
Write-Host ''
Write-Host $strings.labels.dry_run_start
Invoke-Initializer -Answers $answers -DoApply $false

if (-not [string]::IsNullOrWhiteSpace($AnswerFile)) {
    if (-not $Apply) {
        Write-Host $strings.labels.answer_file_dry_run
        exit 0
    }
}
else {
    $confirmation = Read-ChoiceAnswer -QuestionKey 'confirm' -ChoiceKey 'confirm' -DefaultKey '2'
    if ($confirmation.Action -eq 'Back' -or $confirmation.Value -ne 'yes') {
        Write-Host $strings.labels.not_applied
        exit 0
    }
}

Write-Host ''
Write-Host $strings.labels.apply_start
Invoke-Initializer -Answers $answers -DoApply $true
Write-Host $strings.labels.complete
