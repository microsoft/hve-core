#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Detects template-injection and caller-controlled input interpolation in GitHub Actions workflows.

.DESCRIPTION
    Scans GitHub Actions workflow YAML files for two classes of finding:

    - dangerous-workflow/template-injection: direct interpolation of
      attacker-controllable GitHub event values into run or script execution
      contexts.
    - dangerous-workflow/direct-input-interpolation: direct interpolation of a
      caller-controlled workflow input into run or script execution contexts
      (control CQ-6). Only inputs declared with type 'boolean' are exempt,
      because GitHub constrains that type to the literals true and false. An
      input whose declared type cannot be resolved is treated as a violation.

    Broader dangerous-workflow coverage, including untrusted checkout, is
    provided by the Poutine scanner in CI.

.PARAMETER Path
    Directories containing workflow YAML or composite action metadata. Defaults to
    '.github/workflows' and '.github/actions'. A directory supplied explicitly must
    exist; a default directory that is absent is skipped.

.PARAMETER Format
    Output format: 'console', 'json', or 'sarif'. Defaults to 'console'.

.PARAMETER OutputPath
    Path for result output file. Defaults to 'logs/dangerous-workflow-results.json'
    or 'logs/dangerous-workflow-results.sarif' for SARIF output.

.PARAMETER FailOnViolation
    When set, exits with non-zero code if any in-scope findings remain.

.EXAMPLE
    ./scripts/security/Test-DangerousWorkflow.ps1

.EXAMPLE
    ./scripts/security/Test-DangerousWorkflow.ps1 -FailOnViolation -Format sarif

.NOTES
    Part of the HVE Core security validation suite.
#>

using module ./Modules/SecurityClasses.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Path = @('.github/workflows', '.github/actions'),

    [Parameter(Mandatory = $false)]
    [ValidateSet('json', 'sarif', 'console')]
    [string]$Format = 'console',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = '',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnViolation
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force

#region Functions

function Get-WorkflowFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ScanPath,

        [Parameter(Mandatory = $false)]
        [switch]$SkipMissing
    )

    $files = @()
    foreach ($root in $ScanPath) {
        if ($SkipMissing -and -not (Test-Path -LiteralPath $root)) {
            continue
        }

        $resolvedPath = Resolve-Path -Path $root -ErrorAction Stop
        $files += @(Get-ChildItem -Path $resolvedPath -File -Recurse | Where-Object { $_.Extension -in '.yml', '.yaml' })
    }

    return @($files | Sort-Object -Property FullName -Unique)
}

function Get-ExpressionMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    # Singleline lets the capture cross newlines. GitHub accepts an expression whose body
    # is split across lines, and without this option such an expression is never matched.
    $expressionMatchList = [System.Text.RegularExpressions.Regex]::Matches($Text, '\$\{\{\s*(.*?)\s*\}\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return @($expressionMatchList | ForEach-Object { $_.Groups[1].Value.Trim() })
}

function Test-IsUntrustedInjectionExpression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $expression = $Expression.Trim()
    if ([string]::IsNullOrWhiteSpace($expression)) {
        return $false
    }

    # Attacker-controllable free-text and ref contexts that a user without write
    # access can influence. Interpolating these directly into a run or script
    # body enables template injection. Indirect derivations through
    # steps/needs/env outputs are intentionally out of scope for this iteration
    # to keep detection low-noise on the classic pattern; extending to tainted
    # outputs is tracked as follow-on work.
    $untrustedPatterns = @(
        '(^|\W)github\.head_ref(\W|$)'
        '(^|\W)github\.event\.pull_request\.(title|body)(\W|$)'
        '(^|\W)github\.event\.pull_request\.head\.(ref|label)(\W|$)'
        '(^|\W)github\.event\.issue\.(title|body)(\W|$)'
        '(^|\W)github\.event\.(comment|review|review_comment)\.body(\W|$)'
        '(^|\W)github\.event\.discussion\.(title|body)(\W|$)'
        '(^|\W)github\.event\.pages\.[^\s]*\.page_name(\W|$)'
        '(^|\W)github\.event\.head_commit\.(message|author\.(email|name))(\W|$)'
        '(^|\W)github\.event\.commits\.[^\s]*\.(message|author\.(email|name))(\W|$)'
        '(^|\W)github\.event\.workflow_run\.(head_branch|display_title)(\W|$)'
    )

    foreach ($pattern in $untrustedPatterns) {
        if ($expression -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-WorkflowInputType {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Workflow
    )

    # Keys are compared case-insensitively, matching how the inputs context resolves names.
    $declaredTypes = @{}

    if ($null -eq $Workflow) {
        return $declaredTypes
    }

    # Action metadata declares inputs at the document root and its schema has no type
    # field, so every composite action input is reported as untyped.
    if ($Workflow -is [System.Collections.IDictionary] -and $Workflow['runs']) {
        $actionInputs = $Workflow['inputs']
        if ($actionInputs -is [System.Collections.IDictionary]) {
            foreach ($actionInput in $actionInputs.GetEnumerator()) {
                $declaredTypes[[string]$actionInput.Key] = 'untyped'
            }
        }
    }

    # A bare 'on:' key parses as the boolean true, so probe both spellings.
    $triggerNode = $null
    if ($Workflow -is [System.Collections.IDictionary]) {
        foreach ($key in @($Workflow.Keys)) {
            if ("$key" -eq 'on' -or "$key" -eq 'True') {
                $triggerNode = $Workflow[$key]
                break
            }
        }
    }
    elseif ($Workflow.PSObject.Properties.Name -contains 'on') {
        $triggerNode = $Workflow.on
    }

    if ($triggerNode -isnot [System.Collections.IDictionary]) {
        return $declaredTypes
    }

    foreach ($trigger in @('workflow_call', 'workflow_dispatch')) {
        if (-not $triggerNode.Contains($trigger)) {
            continue
        }

        $triggerBody = $triggerNode[$trigger]
        if ($triggerBody -isnot [System.Collections.IDictionary]) {
            continue
        }

        $inputsNode = $triggerBody['inputs']
        if ($inputsNode -isnot [System.Collections.IDictionary]) {
            continue
        }

        foreach ($inputEntry in $inputsNode.GetEnumerator()) {
            $inputName = [string]$inputEntry.Key
            $declaredType = 'unspecified'
            $inputSpec = $inputEntry.Value
            if ($inputSpec -is [System.Collections.IDictionary] -and $inputSpec['type']) {
                $declaredType = ([string]$inputSpec['type']).Trim().ToLowerInvariant()
            }

            # One name declared on two triggers keeps its non-boolean type so the gate fails closed.
            if ($declaredTypes.ContainsKey($inputName) -and $declaredTypes[$inputName] -ne 'boolean') {
                continue
            }

            $declaredTypes[$inputName] = $declaredType
        }
    }

    return $declaredTypes
}

function Get-InputReference {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Expression
    )

    if ([string]::IsNullOrWhiteSpace($Expression)) {
        return @()
    }

    # The inputs context and the github.event.inputs payload carry the same
    # caller-supplied value, so both spellings resolve to the same input name.
    $referencePatterns = @(
        '(?<![A-Za-z0-9_.-])inputs\.([A-Za-z0-9_-]+)'
        'github\.event\.inputs\.([A-Za-z0-9_-]+)'
    )

    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $referencePatterns) {
        foreach ($referenceMatch in [System.Text.RegularExpressions.Regex]::Matches($Expression, $pattern)) {
            $name = $referenceMatch.Groups[1].Value
            if (-not $names.Contains($name)) {
                $names.Add($name)
            }
        }
    }

    return @($names)
}

function Find-NextMatchingLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $false)]
        [int]$StartIndex = 0
    )

    for ($i = $StartIndex; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) {
            return $i + 1
        }
    }

    return 0
}

function ConvertTo-DangerousWorkflowSarif {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [DependencyViolation[]]$Violations
    )

    $rules = @(
        @{
            id                   = 'dangerous-workflow/template-injection'
            name                 = 'DangerousWorkflowTemplateInjection'
            shortDescription     = @{ text = 'Untrusted expressions are interpolated into code execution contexts' }
            fullDescription      = @{ text = 'Untrusted GitHub event or workflow output expressions should not be interpolated directly into run or script blocks.' }
            defaultConfiguration = @{ level = 'error' }
        }
        @{
            id                   = 'dangerous-workflow/direct-input-interpolation'
            name                 = 'DangerousWorkflowDirectInputInterpolation'
            shortDescription     = @{ text = 'Caller-controlled workflow inputs are interpolated into code execution contexts' }
            fullDescription      = @{ text = 'Caller-controlled workflow_call or workflow_dispatch inputs should reach run or script blocks through a step-level env mapping rather than through expression interpolation. Only inputs declared with type boolean are exempt.' }
            defaultConfiguration = @{ level = 'error' }
        }
    )

    $results = @()
    foreach ($violation in $Violations) {
        $ruleId = $violation.Metadata.RuleId
        $ruleLevel = 'error'
        $results += @{
            ruleId  = $ruleId
            level   = $ruleLevel
            message = @{ text = $violation.Description }
            locations = @(
                @{
                    physicalLocation = @{
                        artifactLocation = @{ uri = $violation.File }
                        region = @{ startLine = [int]$violation.Line }
                    }
                }
            )
        }
    }

    return @{
        version  = '2.1.0'
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        runs     = @(
            @{
                tool = @{
                    driver = @{
                        name           = 'Test-DangerousWorkflow'
                        version        = '1.0.0'
                        informationUri = 'https://github.com/microsoft/hve-core'
                        rules          = $rules
                    }
                }
                results = $results
            }
        )
    }
}

function New-DangerousWorkflowViolation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$File,

        [Parameter(Mandatory = $true)]
        [int]$Line,

        [Parameter(Mandatory = $true)]
        [string]$RuleId,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Remediation,

        [Parameter(Mandatory = $false)]
        [string]$JobName = 'unknown',

        [Parameter(Mandatory = $false)]
        [string]$StepName = 'unknown'
    )

    $violation = [DependencyViolation]::new()
    $violation.File = $File
    $violation.Line = $Line
    $violation.Type = 'dangerous-workflow'
    $violation.Name = [System.IO.Path]::GetFileName($File)
    $violation.Severity = 'High'
    $violation.ViolationType = ''
    $violation.Description = $Description
    $violation.Remediation = $Remediation
    $violation.Metadata = @{
        RuleId = $RuleId
        Job = $JobName
        Step = $StepName
    }

    return $violation
}

function Invoke-DangerousWorkflowCheck {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Path = @('.github/workflows', '.github/actions'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('json', 'sarif', 'console')]
        [string]$Format = 'console',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = '',

        [Parameter(Mandatory = $false)]
        [switch]$FailOnViolation
    )

    Write-SecurityLog 'Starting dangerous workflow validation' -Level Info -CIAnnotation
    Write-SecurityLog "Scanning: $($Path -join ', ')" -Level Info

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        if ($Format -eq 'sarif') {
            $OutputPath = 'logs/dangerous-workflow-results.sarif'
        }
        else {
            $OutputPath = 'logs/dangerous-workflow-results.json'
        }
    }

    # An explicitly supplied root must exist. A default root that is absent is skipped so
    # the scan still runs in a repository with no composite actions.
    $skipMissing = -not $PSBoundParameters.ContainsKey('Path')
    $workflowFiles = Get-WorkflowFiles -ScanPath $Path -SkipMissing:$skipMissing
    $totalFiles = @($workflowFiles).Count
    Write-SecurityLog "Found $totalFiles workflow file(s)" -Level Info

    $report = [ComplianceReport]::new($Path -join ', ')
    $report.TotalFiles = $totalFiles
    $report.ScannedFiles = $totalFiles
    $report.TotalDependencies = $totalFiles
    $report.Metadata['ItemType'] = 'workflow'
    $report.Metadata['ItemLabel'] = 'workflows with dangerous patterns'

    $violations = @()
    foreach ($workflowFile in $workflowFiles) {
        $filePath = $workflowFile.FullName
        $relativePath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $filePath)
        $workflowContent = ''
        try {
            $workflowContent = Get-Content -Path $filePath -Raw
        }
        catch {
            $workflowContent = ''
        }
        $rawLines = @($workflowContent -split "\r?\n")
        try {
            $yaml = $workflowContent | ConvertFrom-Yaml
        }
        catch {
            $parseErrorMessage = "Skipping workflow file '$relativePath' because YAML parsing failed: $($_.Exception.Message)"
            Write-SecurityLog $parseErrorMessage -Level Warning -CIAnnotation
            Write-CIAnnotation -Message $parseErrorMessage -Level 'Warning' -File $relativePath -Line 1
            continue
        }

        if ($null -eq $yaml) {
            continue
        }

        $jobsNode = $null
        if ($yaml -is [System.Collections.IDictionary]) {
            if ($yaml.Contains('jobs')) {
                $jobsNode = $yaml['jobs']
            }
            elseif ($yaml['runs'] -is [System.Collections.IDictionary] -and "$($yaml['runs']['using'])" -eq 'composite') {
                # Composite action metadata carries its steps under runs.steps. Present them
                # as a single pseudo-job so both rules apply to the same step loop.
                $jobsNode = [ordered]@{ runs = $yaml['runs'] }
            }
        }
        elseif ($yaml.PSObject.Properties.Name -contains 'jobs') {
            $jobsNode = $yaml.jobs
        }

        if ($null -eq $jobsNode) {
            continue
        }

        $declaredInputTypes = Get-WorkflowInputType -Workflow $yaml

        $injectionSearchIndex = 0
        $inputSearchIndex = 0
        foreach ($jobEntry in $jobsNode.GetEnumerator()) {
            $jobName = [string]$jobEntry.Key
            $jobObject = $jobEntry.Value
            $steps = $null
            if ($jobObject -is [System.Collections.IDictionary]) {
                $steps = $jobObject['steps']
            }
            else {
                $steps = $jobObject.steps
            }

            if ($null -eq $steps) {
                continue
            }

            $stepIndex = 0
            foreach ($step in @($steps)) {
                $stepName = 'step'
                $stepId = $null
                if ($step -is [System.Collections.IDictionary]) {
                    $stepId = $step['id']
                    $stepName = $step['name']
                }
                elseif ($step.PSObject.Properties.Name -contains 'id') {
                    $stepId = $step.id
                }
                elseif ($step.PSObject.Properties.Name -contains 'name') {
                    $stepName = $step.name
                }

                if ($null -eq $stepId -and $null -eq $stepName) {
                    $stepName = "step-$stepIndex"
                }
                elseif ($null -eq $stepId) {
                    $stepName = [string]$stepName
                }
                else {
                    $stepName = [string]$stepId
                }

                $runValue = $null
                $scriptValue = $null
                if ($step -is [System.Collections.IDictionary]) {
                    $runValue = $step['run']
                    $usesValue = $step['uses']
                    $withValue = $step['with']
                    $scriptBlockValue = $null
                    if ($withValue -and $withValue -is [System.Collections.IDictionary]) {
                        $scriptBlockValue = $withValue['script']
                    }
                    elseif ($withValue -and $withValue.PSObject.Properties.Name -contains 'script') {
                        $scriptBlockValue = $withValue.script
                    }
                    if ($usesValue -and "$usesValue" -match '^actions/github-script(?:@|$)') {
                        $scriptValue = $scriptBlockValue
                    }
                }

                # Each step carries exactly one code source (run or github-script). Track the
                # source kind so line resolution can anchor on the correct block, and only treat
                # with.script as executable code for actions/github-script.
                $codeCandidates = @()
                if ($null -ne $runValue) {
                    $codeCandidates += @{ Kind = 'run'; Text = [string]$runValue }
                }
                if ($null -ne $scriptValue) {
                    $codeCandidates += @{ Kind = 'script'; Text = [string]$scriptValue }
                }

                foreach ($candidate in $codeCandidates) {
                    foreach ($expression in Get-ExpressionMatches -Text $candidate.Text) {
                        if (Test-IsUntrustedInjectionExpression -Expression $expression) {
                            # Anchor on the actual interpolation so the reported line is the exact
                            # line containing the untrusted expression, independent of job/step
                            # iteration order (the parser returns an unordered hashtable).
                            $exprPattern = '\$\{\{\s*' + [regex]::Escape($expression) + '\s*\}\}'
                            $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $exprPattern -StartIndex $injectionSearchIndex
                            if ($lineNumber -eq 0) {
                                $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $exprPattern -StartIndex 0
                            }
                            if ($lineNumber -eq 0) {
                                $headerPattern = if ($candidate.Kind -eq 'script') { '^\s*script:\s*' } else { '^\s*run:\s*' }
                                $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $headerPattern -StartIndex 0
                            }
                            if ($lineNumber -eq 0) {
                                $lineNumber = 1
                            }
                            else {
                                $injectionSearchIndex = $lineNumber
                            }

                            $reportedExpression = $expression -replace '\s+', ' '
                            $violation = New-DangerousWorkflowViolation -File $relativePath -Line $lineNumber -RuleId 'dangerous-workflow/template-injection' -Description "Untrusted expression '$reportedExpression' is interpolated into a code execution context in job '$jobName' step '$stepName'." -Remediation 'Avoid directly interpolating untrusted GitHub event or workflow-output values into shell or script blocks.' -JobName $jobName -StepName $stepName
                            $violations += $violation
                            break
                        }
                    }
                }

                foreach ($candidate in $codeCandidates) {
                    $inputViolationRaised = $false
                    foreach ($expression in Get-ExpressionMatches -Text $candidate.Text) {
                        foreach ($inputName in Get-InputReference -Expression $expression) {
                            $declaredType = 'undeclared'
                            if ($declaredInputTypes.ContainsKey($inputName)) {
                                $declaredType = [string]$declaredInputTypes[$inputName]
                            }

                            # A boolean input resolves to the literal true or false, so it carries
                            # no shell metacharacters. Every other type, including an unresolvable
                            # one, is treated as command-bearing.
                            if ($declaredType -eq 'boolean') {
                                continue
                            }

                            $exprPattern = '\$\{\{\s*' + [regex]::Escape($expression) + '\s*\}\}'
                            $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $exprPattern -StartIndex $inputSearchIndex
                            if ($lineNumber -eq 0) {
                                $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $exprPattern -StartIndex 0
                            }
                            if ($lineNumber -eq 0) {
                                $headerPattern = if ($candidate.Kind -eq 'script') { '^\s*script:\s*' } else { '^\s*run:\s*' }
                                $lineNumber = Find-NextMatchingLine -Lines $rawLines -Pattern $headerPattern -StartIndex 0
                            }
                            if ($lineNumber -eq 0) {
                                $lineNumber = 1
                            }
                            else {
                                $inputSearchIndex = $lineNumber
                            }

                            $violation = New-DangerousWorkflowViolation -File $relativePath -Line $lineNumber -RuleId 'dangerous-workflow/direct-input-interpolation' -Description "Caller-controlled input 'inputs.$inputName' (type $declaredType) is interpolated into a code execution context in job '$jobName' step '$stepName'." -Remediation "Map the input to a step-level env: variable (INPUT_$(($inputName -replace '[^A-Za-z0-9]', '_').ToUpperInvariant())) and read the native shell variable inside the run block." -JobName $jobName -StepName $stepName
                            $violations += $violation
                            $inputViolationRaised = $true
                            break
                        }

                        if ($inputViolationRaised) {
                            break
                        }
                    }
                }

                $stepIndex++
            }
        }

    }

    $report.Violations = @($violations)
    $report.UnpinnedDependencies = $violations.Count
    $report.CalculateScore()

    $output = switch ($Format) {
        'console' {
            if ($violations.Count -eq 0) {
                "No dangerous workflow findings were detected."
            }
            else {
                $lines = @('Dangerous workflow findings found:')
                foreach ($violation in $violations) {
                    $lines += "  - $($violation.File):$($violation.Line) [$($violation.Metadata.RuleId)] $($violation.Description)"
                }
                $lines -join "`n"
            }
        }
        'sarif' {
            (ConvertTo-DangerousWorkflowSarif -Violations $violations) | ConvertTo-Json -Depth 10
        }
        'json' {
            $report.ToHashtable() | ConvertTo-Json -Depth 10
        }
    }

    $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $output | Out-File -FilePath $OutputPath -Encoding utf8 -Force
    Write-SecurityLog "Results written to: $OutputPath" -Level Info

    $summaryLines = @(
        '## Dangerous Workflow Validation',
        '',
        '| Metric | Value |',
        '|--------|-------|',
        "| Total Workflows | $totalFiles |",
        "| Findings | $($violations.Count) |"
    )

    if ($violations.Count -gt 0) {
        $summaryLines += @('', '### Findings', '')
        foreach ($violation in $violations) {
            $summaryLines += "| $($violation.File) | $($violation.Metadata.RuleId) |"
        }
    }

    Write-CIStepSummary -Content ($summaryLines -join "`n")
    $output | Out-Host

    $exitCode = 0
    if ($violations.Count -gt 0 -and $FailOnViolation) {
        Write-SecurityLog "$($violations.Count) violation(s) found - failing" -Level Error -CIAnnotation
        $exitCode = 1
    }
    elseif ($violations.Count -gt 0) {
        Write-SecurityLog "$($violations.Count) violation(s) found - soft fail mode" -Level Warning -CIAnnotation
    }
    else {
        Write-SecurityLog 'No dangerous workflow findings found' -Level Success
    }

    return $exitCode
}

#endregion Functions

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-DangerousWorkflowCheck @PSBoundParameters
        exit $exitCode
    }
    catch {
        Write-SecurityLog "Fatal error: $_" -Level Error -CIAnnotation
        Write-SecurityLog $_.ScriptStackTrace -Level Error
        exit 1
    }
}
