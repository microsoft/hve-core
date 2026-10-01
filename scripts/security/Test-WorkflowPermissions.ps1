#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PowerShell-Yaml'; RequiredVersion = '0.4.7' }

<#
.SYNOPSIS
    Validates that GitHub Actions workflow files declare permissions at the workflow and job level.

.DESCRIPTION
    Parses GitHub Actions workflow YAML files and classifies each workflow, then
    each of its jobs, against a four-state model:

      Workflow-level     Job-level   Effective scopes                      Verdict
      -----------------  ----------  ------------------------------------  ---------
      absent             absent      repository or organization default    violation
      permissions: {}    absent      none                                  pass
      populated          absent      inherits the workflow grant           violation
      any                present     job-declared                          pass

    Workflows without any permissions declaration rely on the repository's default
    token permissions, which can cause OpenSSF Scorecard Token-Permissions failures.
    A job that omits its own block under a populated workflow-level block silently
    inherits that grant, which is neither explicit nor auditable.

    A job beneath an empty workflow-level block that declares no block of its own
    inherits an empty set and therefore holds no scope, so that case passes. Note
    that an empty workflow-level block is a default, not a ceiling: a job that does
    declare its own block still receives what it declares, because job-level
    permissions replace the workflow-level set rather than being capped by it.

.PARAMETER Path
    Directory containing workflow YAML files. Defaults to '.github/workflows'.

.PARAMETER Format
    Output format: 'json', 'sarif', or 'console'. Defaults to 'json'.

.PARAMETER OutputPath
    Path for result output file. Defaults to 'logs/workflow-permissions-results.json'.

.PARAMETER FailOnViolation
    When set, exits with non-zero code if any workflow is missing permissions.

.PARAMETER ExcludePaths
    Comma-separated list of workflow filenames to exclude from scanning.
    Defaults to 'copilot-setup-steps.yml'.

.EXAMPLE
    ./scripts/security/Test-WorkflowPermissions.ps1

.EXAMPLE
    ./scripts/security/Test-WorkflowPermissions.ps1 -FailOnViolation -Format sarif

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
    [string]$OutputPath = 'logs/workflow-permissions-results.json',

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

function Get-WorkflowPermissionModel {
    <#
    .SYNOPSIS
        Parses a workflow file into its workflow-level permissions state and per-job facts.

    .DESCRIPTION
        Returns an object describing the workflow-level permissions state ('Absent',
        'Empty', or 'Populated') and every job with whether it declares its own
        permissions block plus a line reference for reporting. Parsing normalizes the
        shapes a text match mishandles: a null value, flow style, scalar 'read-all',
        and permissions keys nested inside steps.

        When YAML parsing fails the returned object reports ParseFailed so the caller
        can warn without counting the file as compliant.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $model = [pscustomobject]@{
        FilePath      = $FilePath
        FileName      = [System.IO.Path]::GetFileName($FilePath)
        ParseFailed   = $false
        ParseError    = ''
        WorkflowState = 'Absent'
        Jobs          = @()
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

    if ($document.Contains('permissions')) {
        $model.WorkflowState = Get-PermissionsNodeState -Node $document['permissions']
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
        $hasPermissions = ($jobNode -is [System.Collections.IDictionary]) -and $jobNode.Contains('permissions')

        $jobs += [pscustomobject]@{
            Name           = $jobName
            HasPermissions = $hasPermissions
            Line           = Get-JobDeclarationLine -RawLines $rawLines -JobName $jobName
        }
    }

    $model.Jobs = $jobs
    return $model
}

function Get-PermissionsNodeState {
    <#
    .SYNOPSIS
        Classifies a parsed permissions node as Absent, Empty, or Populated.

    .DESCRIPTION
        A null value or an empty mapping grants no scopes and is Empty. Any mapping
        with entries, or a scalar such as 'read-all' or 'write-all', is Populated.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Node
    )

    if ($null -eq $Node) {
        return 'Empty'
    }

    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.Count -eq 0) {
            return 'Empty'
        }
        return 'Populated'
    }

    if ($Node -is [string] -and [string]::IsNullOrWhiteSpace($Node)) {
        return 'Empty'
    }

    return 'Populated'
}

function Get-JobDeclarationLine {
    <#
    .SYNOPSIS
        Finds the 1-based line where a job key is declared, for reporting only.

    .DESCRIPTION
        Searches only the region after the top-level 'jobs:' key so a same-named key
        elsewhere in the file, such as one inside an 'outputs:' mapping, cannot be
        mistaken for the job declaration. Returns 0 when the key cannot be located.
        Job identity always comes from the parsed object graph; this lookup only
        attributes a line to a job that is already known.
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

    # No anchor means no constrained region; report no line rather than
    # falling back to a whole-file search that can match an unrelated key.
    if ($start -lt 0) {
        return 0
    }

    # Job keys sit at the first indent level inside 'jobs:'; deeper keys are not jobs.
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

function Test-WorkflowPermissions {
    <#
    .SYNOPSIS
        Tests a single workflow file for workflow-level and job-level permissions blocks.

    .DESCRIPTION
        Returns zero or more violations. A workflow with no permissions declaration at
        all produces a single file-level MissingPermissions violation; its jobs are not
        reported separately because the file-level remediation resolves them. A workflow
        with a populated block produces one MissingJobPermissions violation per job that
        omits its own block. A workflow with an empty block produces none.
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
        $Model = Get-WorkflowPermissionModel -FilePath $FilePath
    }

    if ($Model.ParseFailed) {
        return @()
    }

    $fileName = $Model.FileName
    $violations = @()

    if ($Model.WorkflowState -eq 'Absent') {
        $violation = [DependencyViolation]::new()
        $violation.File = $Model.FilePath
        $violation.Line = 0
        $violation.Type = 'workflow-permissions'
        $violation.Name = $fileName
        $violation.ViolationType = 'MissingPermissions'
        $violation.Severity = 'High'
        $violation.Description = "Workflow '$fileName' is missing a top-level permissions block"
        $violation.Remediation = "Add a top-level 'permissions:' block to restrict default token scope and satisfy OpenSSF Scorecard Token-Permissions"
        $violation.Metadata = @{ FullPath = $Model.FilePath }

        return @($violation)
    }

    if ($Model.WorkflowState -eq 'Empty') {
        return @()
    }

    foreach ($job in $Model.Jobs) {
        if ($job.HasPermissions) {
            continue
        }

        $violation = [DependencyViolation]::new()
        $violation.File = $Model.FilePath
        $violation.Line = $job.Line
        $violation.Type = 'workflow-job-permissions'
        $violation.Name = $job.Name
        $violation.ViolationType = 'MissingJobPermissions'
        $violation.Severity = 'Medium'
        $violation.Description = "Job '$($job.Name)' in workflow '$fileName' is missing its own permissions block and implicitly inherits the workflow-level grant"
        $violation.Remediation = "Add a job-level 'permissions:' block declaring the scopes the job actually needs, so the grant is explicit and auditable"
        $violation.Metadata = @{ FullPath = $Model.FilePath; Job = $job.Name }

        $violations += $violation
    }

    return $violations
}

function ConvertTo-PermissionsSarif {
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
        MissingPermissions    = 'missing-permissions'
        MissingJobPermissions = 'missing-job-permissions'
    }

    $rules = @(
        @{
            id                   = 'missing-permissions'
            name                 = 'MissingWorkflowPermissions'
            shortDescription     = @{ text = 'Workflow missing top-level permissions block' }
            fullDescription      = @{ text = 'GitHub Actions workflows should declare a top-level permissions block to restrict the default GITHUB_TOKEN scope.' }
            helpUri              = 'https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication#modifying-the-permissions-for-the-github_token'
            defaultConfiguration = @{ level = 'error' }
        }
        @{
            id                   = 'missing-job-permissions'
            name                 = 'MissingJobPermissions'
            shortDescription     = @{ text = 'Workflow job missing its own permissions block' }
            fullDescription      = @{ text = 'A job with no permissions block inherits the workflow-level grant implicitly. Declaring permissions on each job keeps the granted scope explicit and auditable.' }
            helpUri              = 'https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication#modifying-the-permissions-for-the-github_token'
            defaultConfiguration = @{ level = 'error' }
        }
    )

    $results = @()
    foreach ($v in $Violations) {
        $ruleId = $ruleIds[$v.ViolationType]
        if (-not $ruleId) {
            $ruleId = 'missing-permissions'
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
        version  = '2.1.0'
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        runs     = @(
            @{
                tool    = @{
                    driver = @{
                        name            = 'Test-WorkflowPermissions'
                        version         = '1.0.0'
                        informationUri  = 'https://github.com/microsoft/hve-core'
                        rules           = $rules
                    }
                }
                results = $results
            }
        )
    }

    return $sarif
}

function Invoke-WorkflowPermissionsCheck {
    <#
    .SYNOPSIS
        Orchestrates the workflow permissions validation scan.
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
        [string]$OutputPath = 'logs/workflow-permissions-results.json',

        [Parameter(Mandatory = $false)]
        [switch]$FailOnViolation,

        [Parameter(Mandatory = $false)]
        [string]$ExcludePaths = 'copilot-setup-steps.yml'
    )

    Write-SecurityLog "Starting workflow permissions validation" -Level Info -CIAnnotation
    Write-SecurityLog "Scanning: $Path" -Level Info

    # Resolve scan path
    $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
    Write-SecurityLog "Resolved path: $resolvedPath" -Level Info

    # Parse exclusions
    $exclusions = @()
    if ($ExcludePaths) {
        $exclusions = $ExcludePaths -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    if ($exclusions.Count -gt 0) {
        Write-SecurityLog "Excluding: $($exclusions -join ', ')" -Level Info
    }

    # Discover workflow files
    $workflowFiles = Get-ChildItem -Path $resolvedPath -File | Where-Object { $_.Extension -in '.yml', '.yaml' }
    $totalFiles = @($workflowFiles).Count
    Write-SecurityLog "Found $totalFiles workflow file(s)" -Level Info

    # Apply exclusions
    if ($exclusions.Count -gt 0) {
        $workflowFiles = $workflowFiles | Where-Object { $exclusions -notcontains $_.Name }
    }
    $scannedFiles = $workflowFiles.Count
    Write-SecurityLog "Scanning $scannedFiles file(s) after exclusions" -Level Info

    # Scan each workflow
    $report = [ComplianceReport]::new($Path)
    $report.TotalFiles = $totalFiles
    $report.ScannedFiles = $scannedFiles
    $report.Metadata['ItemType'] = 'permissions check'
    $report.Metadata['ItemLabel'] = 'workflow and job permissions checks that passed'

    $fileChecks = 0
    $filesWithPermissions = 0
    $fileViolationCount = 0
    $jobChecks = 0
    $jobsPassing = 0
    $jobsDeclaringOwnBlock = 0
    $jobViolationCount = 0
    $unparsedFiles = 0

    foreach ($file in $workflowFiles) {
        # SARIF artifactLocation.uri requires forward slashes regardless of host OS.
        $relativePath = (Join-Path $Path $file.Name) -replace '\\', '/'
        $model = Get-WorkflowPermissionModel -FilePath $file.FullName
        $fileChecks++

        if ($model.ParseFailed) {
            $unparsedFiles++
            $fileViolationCount++
            $parseMessage = "Workflow '$($file.Name)' could not be parsed as YAML and was not evaluated: $($model.ParseError)"

            $violation = [DependencyViolation]::new()
            $violation.File = $relativePath
            $violation.Line = 1
            $violation.Type = 'workflow-permissions'
            $violation.Name = $file.Name
            $violation.ViolationType = 'MissingPermissions'
            $violation.Severity = 'High'
            $violation.Description = $parseMessage
            $violation.Remediation = 'Fix the YAML syntax so the workflow permissions gate can evaluate this file'
            $violation.Metadata = @{ FullPath = $file.FullName; ParseError = $model.ParseError }
            $report.AddViolation($violation)

            Write-SecurityLog "  FAIL: $parseMessage" -Level Error -CIAnnotation
            Write-CIAnnotation -Message $parseMessage -Level 'Error' -File $relativePath -Line 1
            continue
        }

        $violations = @(Test-WorkflowPermissions -Model $model)
        $fileLevel = @($violations | Where-Object { $_.ViolationType -eq 'MissingPermissions' })
        $jobLevel = @($violations | Where-Object { $_.ViolationType -eq 'MissingJobPermissions' })

        if ($fileLevel.Count -eq 0) {
            $filesWithPermissions++
        }

        # A workflow with no permissions declaration at all is reported once at the file
        # level; its jobs are not checked separately because the file-level remediation
        # resolves them.
        if ($model.WorkflowState -ne 'Absent') {
            $modelJobCount = @($model.Jobs).Count
            $jobChecks += $modelJobCount
            $jobsPassing += ($modelJobCount - $jobLevel.Count)
            # Counted separately from passing jobs: under an empty workflow-level block a
            # job passes by inheriting nothing, which is not the same as declaring a block.
            $jobsDeclaringOwnBlock += @($model.Jobs | Where-Object { $_.HasPermissions }).Count
        }

        $fileViolationCount += $fileLevel.Count
        $jobViolationCount += $jobLevel.Count

        foreach ($violation in $violations) {
            # Normalize to workspace-relative path
            $violation.File = $relativePath
            $report.AddViolation($violation)
        }

        if ($violations.Count -eq 0) {
            Write-SecurityLog "  PASS: $($file.Name)" -Level Success
            continue
        }

        if ($fileLevel.Count -gt 0) {
            Write-SecurityLog "  FAIL: $($file.Name) - missing top-level permissions block" -Level Error -CIAnnotation
        }

        if ($jobLevel.Count -gt 0) {
            $jobNames = ($jobLevel | ForEach-Object { $_.Name }) -join ', '
            Write-SecurityLog "  FAIL: $($file.Name) - $($jobLevel.Count) job(s) missing their own permissions block: $jobNames" -Level Error -CIAnnotation
        }

        foreach ($violation in $violations) {
            Write-CIAnnotation -Message $violation.Description -Level 'Error' -File $violation.File -Line ([math]::Max(1, $violation.Line))
        }
    }

    $report.TotalDependencies = $fileChecks + $jobChecks
    $report.PinnedDependencies = $filesWithPermissions + $jobsPassing
    $report.CalculateScore()

    $report.Metadata['FileChecks'] = $fileChecks
    $report.Metadata['FilesWithPermissions'] = $filesWithPermissions
    $report.Metadata['FileLevelViolations'] = $fileViolationCount
    $report.Metadata['JobChecks'] = $jobChecks
    $report.Metadata['JobsPassing'] = $jobsPassing
    $report.Metadata['JobsDeclaringOwnBlock'] = $jobsDeclaringOwnBlock
    $report.Metadata['JobLevelViolations'] = $jobViolationCount
    $report.Metadata['UnparsedFiles'] = $unparsedFiles

    Write-SecurityLog "Workflow-level: $filesWithPermissions/$fileChecks declare permissions ($fileViolationCount violation(s))" -Level Info
    Write-SecurityLog "Job-level: $jobsPassing/$jobChecks pass the job-level check ($jobViolationCount violation(s))" -Level Info
    Write-SecurityLog "Job-level: $jobsDeclaringOwnBlock/$jobChecks declare their own permissions block; the remainder pass by inheriting an empty workflow-level block" -Level Info
    if ($unparsedFiles -gt 0) {
        Write-SecurityLog "Unparsed workflows: $unparsedFiles (not evaluated, not counted as compliant)" -Level Warning
    }
    Write-SecurityLog "Score: $($report.ComplianceScore)% ($($report.PinnedDependencies)/$($report.TotalDependencies) checks passed)" -Level Info

    # Format output
    $output = switch ($Format) {
        'console' {
            if ($report.Violations.Count -eq 0) {
                "All $fileChecks workflow(s) and $jobChecks job(s) passed the permissions check."
            }
            else {
                $lines = @("Workflow permissions violations found:`n")
                foreach ($v in $report.Violations) {
                    $lines += "  - $($v.File): $($v.Description)"
                }
                $lines += "`nRemediation: $($report.Violations[0].Remediation)"
                $lines -join "`n"
            }
        }
        'sarif' {
            (ConvertTo-PermissionsSarif -Violations $report.Violations) | ConvertTo-Json -Depth 10
        }
        'json' {
            $report.ToHashtable() | ConvertTo-Json -Depth 10
        }
    }

    # Write output file
    $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $output | Out-File -FilePath $OutputPath -Encoding utf8 -Force
    Write-SecurityLog "Results written to: $OutputPath" -Level Info

    # Generate step summary
    $summaryLines = @(
        "## Workflow Permissions Validation"
        ""
        "| Metric | Value |"
        "|--------|-------|"
        "| Total Workflows | $totalFiles |"
        "| Scanned | $scannedFiles |"
        "| Unparsed (not evaluated) | $unparsedFiles |"
        "| Workflows With Top-Level Permissions | $filesWithPermissions |"
        "| Workflows Missing Top-Level Permissions | $fileViolationCount |"
        "| Jobs Checked | $jobChecks |"
        "| Jobs Passing Job-Level Check | $jobsPassing |"
        "| Jobs Declaring Their Own Block | $jobsDeclaringOwnBlock |"
        "| Jobs Missing Own Permissions | $jobViolationCount |"
        "| Compliance Score | $($report.ComplianceScore)% |"
    )

    if ($report.Violations.Count -gt 0) {
        $summaryLines += @(
            ""
            "### Violations"
            ""
            "| Workflow | Scope | Issue |"
            "|----------|-------|-------|"
        )
        foreach ($v in $report.Violations) {
            $scope = if ($v.ViolationType -eq 'MissingJobPermissions') { "job ``$($v.Name)``" } else { 'workflow' }
            $summaryLines += "| ``$($v.File)`` | $scope | $($v.Description) |"
        }
    }

    $summary = $summaryLines -join "`n"
    Write-CIStepSummary -Content $summary

    # Display to console
    $output | Out-Host

    # Determine exit code
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
        Write-SecurityLog "All workflows and jobs passed the permissions check" -Level Success
    }

    return $exitCode
}

# endregion

# Dot-source guard
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-WorkflowPermissionsCheck @PSBoundParameters
        exit $exitCode
    }
    catch {
        Write-SecurityLog "Fatal error: $_" -Level Error -CIAnnotation
        Write-SecurityLog $_.ScriptStackTrace -Level Error
        exit 1
    }
}
