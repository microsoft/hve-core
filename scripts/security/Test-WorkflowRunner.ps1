#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PowerShell-Yaml'; RequiredVersion = '0.4.7' }

<#
.SYNOPSIS
    Validates that GitHub Actions workflow jobs run on GitHub-hosted Ubuntu runners.

.DESCRIPTION
    Parses GitHub Actions workflow YAML files and checks every job's `runs-on`
    value against the GitHub-hosted Ubuntu allow list documented in
    workflows.instructions.md § Runners: `ubuntu-latest`, dated Ubuntu labels
    such as `ubuntu-24.04` or `ubuntu-22.04`, their `-arm` variants, and the
    lightweight `ubuntu-slim` runner.

    A job whose `runs-on` is a non-Ubuntu label (for example `windows-latest`,
    `macos-latest`, or `self-hosted`), an array containing any non-Ubuntu
    entry, an unresolvable expression (for example `${{ matrix.os }}`), or is
    missing entirely, is reported as a violation. Unresolvable expressions are
    treated as violations rather than passes because the actual runner cannot
    be verified from the workflow file alone.

.PARAMETER Path
    Directory containing workflow YAML files. Defaults to '.github/workflows'.

.PARAMETER Format
    Output format: 'json', 'sarif', or 'console'. Defaults to 'json'.

.PARAMETER OutputPath
    Path for result output file. Defaults to 'logs/workflow-runner-results.json'.

.PARAMETER FailOnViolation
    When set, exits with non-zero code if any job runs on a non-Ubuntu runner.

.PARAMETER ExcludePaths
    Comma-separated list of workflow filenames to exclude from scanning.
    Defaults to 'copilot-setup-steps.yml'.

.EXAMPLE
    ./scripts/security/Test-WorkflowRunner.ps1

.EXAMPLE
    ./scripts/security/Test-WorkflowRunner.ps1 -FailOnViolation -Format sarif

.NOTES
    Part of the HVE Core security validation suite.

.LINK
    https://github.com/microsoft/hve-core
#>

using module ./Modules/SecurityClasses.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = '.github/workflows',

    [Parameter(Mandatory = $false)]
    [ValidateSet('json', 'sarif', 'console')]
    [string]$Format = 'json',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/workflow-runner-results.json',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnViolation,

    [Parameter(Mandatory = $false)]
    [string]$ExcludePaths = 'copilot-setup-steps.yml'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force
Import-Module powershell-yaml -ErrorAction Stop

# region Helper Functions

# GitHub-hosted Ubuntu labels: ubuntu-latest, dated releases (ubuntu-24.04,
# ubuntu-22.04, future ubuntu-26.04, ...), their -arm variants, and the
# lightweight ubuntu-slim runner. Anchored so partial matches (for example a
# custom label ending in "ubuntu-latest-custom") do not slip through.
$script:UbuntuRunnerPattern = '^ubuntu-(latest|\d{2}\.\d{2}(-arm)?|slim)$'

function Test-UbuntuRunnerLabel {
    <#
    .SYNOPSIS
        Returns whether a single runs-on label is an allowed GitHub-hosted Ubuntu label.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Label
    )

    return $Label -match $script:UbuntuRunnerPattern
}

function Get-JobDeclarationLine {
    <#
    .SYNOPSIS
        Finds the 1-based line where a job key is declared, for reporting only.

    .DESCRIPTION
        Searches only the region after the top-level 'jobs:' key so a same-named key
        elsewhere in the file cannot be mistaken for the job declaration. Returns 0
        when the key cannot be located. Job identity always comes from the parsed
        object graph; this lookup only attributes a line to a job that is already known.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$RawLines,

        [Parameter(Mandatory = $true)]
        [string]$JobName
    )

    $start = -1
    for ($i = 0; $i -lt $RawLines.Count; $i++) {
        if ($RawLines[$i] -match '^["'']?jobs["'']?\s*:\s*(#.*)?$') {
            $start = $i + 1
            break
        }
    }

    if ($start -lt 0) {
        return 0
    }

    $jobIndent = -1
    for ($i = $start; $i -lt $RawLines.Count; $i++) {
        if ($RawLines[$i] -match '^(\s+)\S') {
            $jobIndent = $Matches[1].Length
            break
        }
    }
    if ($jobIndent -lt 0) {
        return 0
    }

    $pattern = '^\s{' + $jobIndent + '}' + [regex]::Escape($JobName) + '\s*:\s*(#.*)?$'
    for ($i = $start; $i -lt $RawLines.Count; $i++) {
        if ($RawLines[$i] -match $pattern) {
            return $i + 1
        }
    }

    return 0
}

function Get-WorkflowRunnerModel {
    <#
    .SYNOPSIS
        Parses a workflow file into per-job runs-on facts.

    .DESCRIPTION
        Returns an object with one entry per job describing its raw `runs-on`
        value(s) and whether every one of them is an allowed GitHub-hosted
        Ubuntu label. Reusable workflows (`workflow_call` only, no `jobs.*.runs-on`
        applicable) are still scanned; a reusable workflow always declares its
        own jobs with their own `runs-on`, so no special-casing is needed.

        When YAML parsing fails the returned object reports ParseFailed so the
        caller can warn without counting the file as compliant.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $model = [pscustomobject]@{
        FilePath    = $FilePath
        FileName    = [System.IO.Path]::GetFileName($FilePath)
        ParseFailed = $false
        ParseError  = ''
        Jobs        = @()
    }

    $content = ''
    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    }
    catch {
        $model.ParseFailed = $true
        $model.ParseError = $_.Exception.Message
        return $model
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        $content = ''
    }
    $rawLines = @($content -split "\r?\n")

    $document = $null
    try {
        $document = $content | ConvertFrom-Yaml
    }
    catch {
        $model.ParseFailed = $true
        $model.ParseError = $_.Exception.Message
        return $model
    }

    if ($document -isnot [System.Collections.IDictionary]) {
        return $model
    }

    if (-not $document.Contains('jobs')) {
        return $model
    }

    $jobsNode = $document['jobs']
    if ($jobsNode -isnot [System.Collections.IDictionary]) {
        return $model
    }

    $jobs = @()
    foreach ($entry in $jobsNode.GetEnumerator()) {
        $jobName = [string]$entry.Key
        $jobNode = $entry.Value

        # A job that itself calls a reusable workflow (`uses:`) declares no
        # `runs-on` of its own; the reusable workflow's own jobs are the ones
        # that actually execute and are scanned when that file is scanned.
        if (($jobNode -is [System.Collections.IDictionary]) -and $jobNode.Contains('uses')) {
            continue
        }

        $runsOnNode = $null
        $hasRunsOn = ($jobNode -is [System.Collections.IDictionary]) -and $jobNode.Contains('runs-on')
        if ($hasRunsOn) {
            $runsOnNode = $jobNode['runs-on']
        }

        $labels = @()
        $isExpression = $false
        $isCompliant = $false

        if (-not $hasRunsOn) {
            $isCompliant = $false
        }
        elseif ($runsOnNode -is [string]) {
            $labels = @($runsOnNode)
            if ($runsOnNode -match '\$\{\{.*\}\}') {
                $isExpression = $true
                $isCompliant = $false
            }
            else {
                $isCompliant = Test-UbuntuRunnerLabel -Label $runsOnNode
            }
        }
        elseif ($runsOnNode -is [System.Collections.IEnumerable] -and $runsOnNode -isnot [string]) {
            $labels = @($runsOnNode | ForEach-Object { [string]$_ })
            if ($labels | Where-Object { $_ -match '\$\{\{.*\}\}' }) {
                $isExpression = $true
                $isCompliant = $false
            }
            else {
                $isCompliant = -not ($labels | Where-Object { -not (Test-UbuntuRunnerLabel -Label $_) })
            }
        }
        else {
            # Unrecognized shape (for example a mapping such as `group:`/`labels:`
            # for a custom runner group). Treat conservatively as non-compliant.
            $labels = @([string]$runsOnNode)
            $isCompliant = $false
        }

        $jobs += [pscustomobject]@{
            Name         = $jobName
            HasRunsOn    = $hasRunsOn
            Labels       = $labels
            IsExpression = $isExpression
            IsCompliant  = $isCompliant
            Line         = Get-JobDeclarationLine -RawLines $rawLines -JobName $jobName
        }
    }

    $model.Jobs = $jobs
    return $model
}

function Test-WorkflowRunner {
    <#
    .SYNOPSIS
        Tests a single workflow file for non-Ubuntu or unresolvable job runners.

    .DESCRIPTION
        Returns zero or more violations, one per job whose `runs-on` value is
        not a GitHub-hosted Ubuntu label, is an unresolvable expression, or is
        missing entirely.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([DependencyViolation[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]$FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Model')]
        [psobject]$Model
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $Model = Get-WorkflowRunnerModel -FilePath $FilePath
    }

    if ($Model.ParseFailed) {
        return @()
    }

    $fileName = $Model.FileName
    $violations = @()

    foreach ($job in $Model.Jobs) {
        if ($job.IsCompliant) {
            continue
        }

        $violation = [DependencyViolation]::new()
        $violation.File = $Model.FilePath
        $violation.Line = $job.Line
        $violation.Type = 'workflow-runner'
        $violation.Name = $job.Name

        if (-not $job.HasRunsOn) {
            $violation.ViolationType = 'MissingRunner'
            $violation.Severity = 'High'
            $violation.Description = "Job '$($job.Name)' in workflow '$fileName' has no 'runs-on' value"
            $violation.Remediation = "Add 'runs-on: ubuntu-latest' (or another GitHub-hosted Ubuntu label) to the job"
        }
        elseif ($job.IsExpression) {
            $violation.ViolationType = 'NonUbuntuRunner'
            $violation.Severity = 'High'
            $violation.Description = "Job '$($job.Name)' in workflow '$fileName' has a 'runs-on' value that cannot be resolved from the workflow file: $($job.Labels -join ', ')"
            $violation.Remediation = 'Use a literal GitHub-hosted Ubuntu label, such as ubuntu-latest, instead of an expression that may resolve to a non-Ubuntu runner'
        }
        else {
            $violation.ViolationType = 'NonUbuntuRunner'
            $violation.Severity = 'High'
            $violation.Description = "Job '$($job.Name)' in workflow '$fileName' runs on '$($job.Labels -join ', ')', which is not a GitHub-hosted Ubuntu runner"
            $violation.Remediation = 'Change runs-on to a GitHub-hosted Ubuntu label, such as ubuntu-latest, ubuntu-24.04, or ubuntu-slim'
        }

        $violation.Metadata = @{ FullPath = $Model.FilePath; Job = $job.Name; Labels = $job.Labels }
        $violations += $violation
    }

    return $violations
}

function ConvertTo-RunnerSarif {
    <#
    .SYNOPSIS
        Converts violations to SARIF 2.1.0 format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [DependencyViolation[]]$Violations
    )

    $ruleIds = @{
        NonUbuntuRunner = 'non-ubuntu-runner'
        MissingRunner   = 'missing-runner'
    }

    $rules = @(
        @{
            id                   = 'non-ubuntu-runner'
            name                 = 'NonUbuntuRunner'
            shortDescription     = @{ text = "Job runs on a non-Ubuntu or unresolvable runner" }
            fullDescription      = @{ text = 'hve-core workflows must run on GitHub-hosted Ubuntu runners (ubuntu-latest, dated Ubuntu labels, their -arm variants, or ubuntu-slim). Other runner types are not supported.' }
            helpUri              = 'https://github.com/microsoft/hve-core/blob/main/.github/instructions/workflows.instructions.md'
            defaultConfiguration = @{ level = 'error' }
        }
        @{
            id                   = 'missing-runner'
            name                 = 'MissingRunner'
            shortDescription     = @{ text = "Job has no 'runs-on' value" }
            fullDescription      = @{ text = 'Every job must declare a GitHub-hosted Ubuntu runs-on label.' }
            helpUri              = 'https://github.com/microsoft/hve-core/blob/main/.github/instructions/workflows.instructions.md'
            defaultConfiguration = @{ level = 'error' }
        }
    )

    $results = @()
    foreach ($v in $Violations) {
        $ruleId = $ruleIds[$v.ViolationType]
        if (-not $ruleId) {
            $ruleId = 'non-ubuntu-runner'
        }

        $results += @{
            ruleId    = $ruleId
            level     = 'error'
            message   = @{ text = $v.Description }
            locations = @(
                @{
                    physicalLocation = @{
                        artifactLocation = @{ uri = $v.File }
                        region           = @{ startLine = [math]::Max(1, $v.Line) }
                    }
                }
            )
        }
    }

    $sarif = @{
        version   = '2.1.0'
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        runs      = @(
            @{
                tool    = @{
                    driver = @{
                        name           = 'Test-WorkflowRunner'
                        version        = '1.0.0'
                        informationUri = 'https://github.com/microsoft/hve-core'
                        rules          = $rules
                    }
                }
                results = $results
            }
        )
    }

    return $sarif
}

function Invoke-WorkflowRunnerCheck {
    <#
    .SYNOPSIS
        Orchestrates the workflow runner policy validation scan.
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = '.github/workflows',

        [Parameter(Mandatory = $false)]
        [ValidateSet('json', 'sarif', 'console')]
        [string]$Format = 'json',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/workflow-runner-results.json',

        [Parameter(Mandatory = $false)]
        [switch]$FailOnViolation,

        [Parameter(Mandatory = $false)]
        [string]$ExcludePaths = 'copilot-setup-steps.yml'
    )

    Write-SecurityLog "Starting workflow runner policy validation" -Level Info -CIAnnotation
    Write-SecurityLog "Scanning: $Path" -Level Info

    $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
    Write-SecurityLog "Resolved path: $resolvedPath" -Level Info

    $exclusions = @()
    if ($ExcludePaths) {
        $exclusions = $ExcludePaths -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    if ($exclusions.Count -gt 0) {
        Write-SecurityLog "Excluding: $($exclusions -join ', ')" -Level Info
    }

    $workflowFiles = Get-ChildItem -Path $resolvedPath -File | Where-Object { $_.Extension -in '.yml', '.yaml' }
    $totalFiles = @($workflowFiles).Count
    Write-SecurityLog "Found $totalFiles workflow file(s)" -Level Info

    if ($exclusions.Count -gt 0) {
        $workflowFiles = $workflowFiles | Where-Object { $exclusions -notcontains $_.Name }
    }
    $scannedFiles = $workflowFiles.Count
    Write-SecurityLog "Scanning $scannedFiles file(s) after exclusions" -Level Info

    $report = [ComplianceReport]::new($Path)
    $report.TotalFiles = $totalFiles
    $report.ScannedFiles = $scannedFiles
    $report.Metadata['ItemType'] = 'runner policy check'
    $report.Metadata['ItemLabel'] = 'job runner checks that passed'

    $jobChecks = 0
    $jobsPassing = 0
    $jobViolationCount = 0
    $unparsedFiles = 0

    foreach ($file in $workflowFiles) {
        # SARIF artifactLocation.uri requires forward slashes regardless of host OS.
        $relativePath = (Join-Path $Path $file.Name) -replace '\\', '/'
        $model = Get-WorkflowRunnerModel -FilePath $file.FullName

        if ($model.ParseFailed) {
            $unparsedFiles++
            $jobViolationCount++
            $parseMessage = "Workflow '$($file.Name)' could not be parsed as YAML and was not evaluated: $($model.ParseError)"

            $violation = [DependencyViolation]::new()
            $violation.File = $relativePath
            $violation.Line = 1
            $violation.Type = 'workflow-runner'
            $violation.Name = $file.Name
            $violation.ViolationType = 'MissingRunner'
            $violation.Severity = 'High'
            $violation.Description = $parseMessage
            $violation.Remediation = 'Fix the YAML syntax so the workflow runner policy gate can evaluate this file'
            $violation.Metadata = @{ FullPath = $file.FullName; ParseError = $model.ParseError }
            $report.AddViolation($violation)

            Write-SecurityLog "  FAIL: $parseMessage" -Level Error -CIAnnotation
            Write-CIAnnotation -Message $parseMessage -Level 'Error' -File $relativePath -Line 1
            continue
        }

        $violations = @(Test-WorkflowRunner -Model $model)
        $modelJobCount = @($model.Jobs).Count
        $jobChecks += $modelJobCount
        $jobsPassing += ($modelJobCount - $violations.Count)
        $jobViolationCount += $violations.Count

        foreach ($violation in $violations) {
            $violation.File = $relativePath
            $report.AddViolation($violation)
        }

        if ($violations.Count -eq 0) {
            Write-SecurityLog "  PASS: $($file.Name)" -Level Success
            continue
        }

        $jobNames = ($violations | ForEach-Object { $_.Name }) -join ', '
        Write-SecurityLog "  FAIL: $($file.Name) - $($violations.Count) job(s) not on a GitHub-hosted Ubuntu runner: $jobNames" -Level Error -CIAnnotation

        foreach ($violation in $violations) {
            Write-CIAnnotation -Message $violation.Description -Level 'Error' -File $violation.File -Line ([math]::Max(1, $violation.Line))
        }
    }

    $report.TotalDependencies = $jobChecks
    $report.PinnedDependencies = $jobsPassing
    $report.CalculateScore()

    $report.Metadata['JobChecks'] = $jobChecks
    $report.Metadata['JobsPassing'] = $jobsPassing
    $report.Metadata['JobViolations'] = $jobViolationCount
    $report.Metadata['UnparsedFiles'] = $unparsedFiles

    Write-SecurityLog "Job-level: $jobsPassing/$jobChecks jobs run on a GitHub-hosted Ubuntu runner ($jobViolationCount violation(s))" -Level Info
    if ($unparsedFiles -gt 0) {
        Write-SecurityLog "Unparsed workflows: $unparsedFiles (not evaluated, not counted as compliant)" -Level Warning
    }
    Write-SecurityLog "Score: $($report.ComplianceScore)% ($($report.PinnedDependencies)/$($report.TotalDependencies) checks passed)" -Level Info

    $output = switch ($Format) {
        'console' {
            if ($report.Violations.Count -eq 0) {
                "All $jobChecks job(s) passed the runner policy check."
            }
            else {
                $lines = @("Workflow runner policy violations found:`n")
                foreach ($v in $report.Violations) {
                    $lines += "  - $($v.File): $($v.Description)"
                }
                $lines += "`nRemediation: $($report.Violations[0].Remediation)"
                $lines -join "`n"
            }
        }
        'sarif' {
            (ConvertTo-RunnerSarif -Violations $report.Violations) | ConvertTo-Json -Depth 10
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
        "## Workflow Runner Policy Validation"
        ""
        "| Metric | Value |"
        "|--------|-------|"
        "| Total Workflows | $totalFiles |"
        "| Scanned | $scannedFiles |"
        "| Unparsed (not evaluated) | $unparsedFiles |"
        "| Jobs Checked | $jobChecks |"
        "| Jobs Passing | $jobsPassing |"
        "| Jobs Failing | $jobViolationCount |"
        "| Compliance Score | $($report.ComplianceScore)% |"
    )

    if ($report.Violations.Count -gt 0) {
        $summaryLines += @(
            ""
            "### Violations"
            ""
            "| Workflow | Job | Issue |"
            "|----------|-----|-------|"
        )
        foreach ($v in $report.Violations) {
            $summaryLines += "| ``$($v.File)`` | ``$($v.Name)`` | $($v.Description) |"
        }
    }

    $summary = $summaryLines -join "`n"
    Write-CIStepSummary -Content $summary

    $output | Out-Host

    $exitCode = 0
    if ($report.Violations.Count -gt 0) {
        if ($FailOnViolation) {
            Write-SecurityLog "$($report.Violations.Count) violation(s) found - failing" -Level Error -CIAnnotation
            $exitCode = 1
        }
        else {
            Write-SecurityLog "$($report.Violations.Count) violation(s) found - soft fail mode" -Level Warning -CIAnnotation
        }
    }
    else {
        Write-SecurityLog "All jobs passed the runner policy check" -Level Success
    }

    return $exitCode
}

# endregion

# Dot-source guard
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-WorkflowRunnerCheck @PSBoundParameters
        exit $exitCode
    }
    catch {
        Write-SecurityLog "Fatal error: $_" -Level Error -CIAnnotation
        Write-SecurityLog $_.ScriptStackTrace -Level Error
        exit 1
    }
}
