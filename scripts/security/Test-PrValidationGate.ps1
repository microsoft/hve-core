#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4
#Requires -Modules @{ ModuleName='PowerShell-Yaml'; RequiredVersion='0.4.7' }

<#
.SYNOPSIS
    Validates that the PR-validation aggregator gate job depends on every other job.

.DESCRIPTION
    Parses a GitHub Actions workflow (default '.github/workflows/pr-validation.yml')
    with ConvertFrom-Yaml, enumerates its top-level job IDs, and asserts that the
    aggregator gate job (default 'pr-validation-success') lists every non-gate job
    in its 'needs:' array. The check guards against two forms of drift:

      * Missing jobs - a job exists in the workflow but is absent from the gate's
        'needs:' list, so its failure would not block the gate.
      * Stale needs  - the gate's 'needs:' references a job ID that no longer
        exists in the workflow.

    Results are emitted as a JSON object under logs/ and a human-readable summary
    is written to the console. With -FailOnViolation, the script exits 1 and names
    the offending jobs when any violation (or an absent gate job) is detected;
    otherwise it exits 0.

    This validator deliberately parses YAML structurally and does not depend on the
    regex-based security helper modules used by sibling validators.

.PARAMETER WorkflowPath
    Path to the workflow YAML file to validate. Defaults to
    '.github/workflows/pr-validation.yml'.

.PARAMETER GateJobId
    Job ID of the aggregator gate that must depend on all other jobs. Defaults to
    'pr-validation-success'.

.PARAMETER OutputPath
    Path for the JSON results file. Defaults to
    'logs/pr-validation-gate-results.json'.

.PARAMETER FailOnViolation
    When set, exits with a non-zero code if any job is missing from the gate's
    'needs:' list, any 'needs:' entry is stale, or the gate job is absent.

.EXAMPLE
    ./scripts/security/Test-PrValidationGate.ps1

.EXAMPLE
    ./scripts/security/Test-PrValidationGate.ps1 -FailOnViolation

.NOTES
    Part of the HVE Core security validation suite.

.LINK
    https://github.com/microsoft/hve-core
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath = '.github/workflows/pr-validation.yml',

    [Parameter(Mandatory = $false)]
    [string]$GateJobId = 'pr-validation-success',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/pr-validation-gate-results.json',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnViolation
)

$ErrorActionPreference = 'Stop'

Import-Module powershell-yaml -ErrorAction Stop

#region Functions

function Get-PrValidationGateResult {
    <#
    .SYNOPSIS
        Computes gate-completeness results for a workflow.

    .DESCRIPTION
        Parses the workflow YAML, enumerates job IDs, and returns an object
        describing which jobs are missing from the gate's 'needs:' list and which
        'needs:' entries are stale. The gate job's presence is reported via the
        GateJobPresent property so callers can surface a clear error.

    .PARAMETER WorkflowPath
        Path to the workflow YAML file to parse.

    .PARAMETER GateJobId
        Job ID of the aggregator gate.

    .OUTPUTS
        [pscustomobject] with WorkflowPath, GateJobId, GateJobPresent, AllJobs,
        GateNeeds, Missing, and Stale properties.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkflowPath,

        [Parameter(Mandatory = $true)]
        [string]$GateJobId
    )

    if (-not (Test-Path -Path $WorkflowPath)) {
        throw "Workflow file not found: $WorkflowPath"
    }

    $wf = Get-Content -Raw -Path $WorkflowPath | ConvertFrom-Yaml

    if ($null -eq $wf -or $null -eq $wf.jobs) {
        throw "Workflow '$WorkflowPath' does not define a 'jobs:' map."
    }

    $allJobs = @($wf.jobs.Keys)
    $gateJob = $wf.jobs[$GateJobId]
    $gatePresent = $null -ne $gateJob

    # Normalize both flow (needs: [a, b]) and block sequence forms to an array, then
    # drop null/empty elements so a stray YAML null or "" entry cannot inject a phantom stale.
    $gateNeeds = if ($gatePresent) {
        @($gateJob.needs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    else { @() }

    $expected = @($allJobs | Where-Object { $_ -ne $GateJobId })
    $missing = @($expected | Where-Object { $_ -notin $gateNeeds })
    $stale = @($gateNeeds | Where-Object { $_ -notin $allJobs })

    return [pscustomobject]@{
        WorkflowPath   = $WorkflowPath
        GateJobId      = $GateJobId
        GateJobPresent = $gatePresent
        AllJobs        = $allJobs
        GateNeeds      = $gateNeeds
        Missing        = $missing
        Stale          = $stale
    }
}

function Invoke-PrValidationGateCheck {
    <#
    .SYNOPSIS
        Orchestrates the PR-validation gate completeness check.

    .DESCRIPTION
        Computes gate-completeness results, writes a JSON results object to the
        output path, prints a human-readable summary, and returns an exit code.

    .PARAMETER WorkflowPath
        Path to the workflow YAML file to validate.

    .PARAMETER GateJobId
        Job ID of the aggregator gate.

    .PARAMETER OutputPath
        Path for the JSON results file.

    .PARAMETER FailOnViolation
        When set, returns 1 if any violation or an absent gate job is detected.

    .OUTPUTS
        [int] Exit code: 0 when clean (or soft-fail mode), 1 on violations.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$WorkflowPath = '.github/workflows/pr-validation.yml',

        [Parameter(Mandatory = $false)]
        [string]$GateJobId = 'pr-validation-success',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/pr-validation-gate-results.json',

        [Parameter(Mandatory = $false)]
        [switch]$FailOnViolation
    )

    Write-Host "🔍 Validating PR-validation gate completeness" -ForegroundColor Cyan
    Write-Host "   Workflow: $WorkflowPath" -ForegroundColor Gray
    Write-Host "   Gate job: $GateJobId" -ForegroundColor Gray

    $result = Get-PrValidationGateResult -WorkflowPath $WorkflowPath -GateJobId $GateJobId

    $violationCount = $result.Missing.Count + $result.Stale.Count
    if (-not $result.GateJobPresent) {
        $violationCount++
    }

    $resultObject = [ordered]@{
        workflowPath   = $result.WorkflowPath
        gateJobId      = $result.GateJobId
        gateJobPresent = $result.GateJobPresent
        totalJobs      = $result.AllJobs.Count
        gateNeedsCount = $result.GateNeeds.Count
        missing        = $result.Missing
        stale          = $result.Stale
        violationCount = $violationCount
        timestamp      = (Get-Date).ToUniversalTime().ToString('o')
    }

    # Write JSON results to logs/.
    $outputDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ($outputDir -and -not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $resultObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding utf8 -Force
    Write-Host "   Results written to: $OutputPath" -ForegroundColor Gray

    if (-not $result.GateJobPresent) {
        Write-Host "❌ Gate job '$GateJobId' was not found in $WorkflowPath" -ForegroundColor Red
        Write-Host "   Add a '$GateJobId' job that depends on every other job." -ForegroundColor Red
        return 1
    }

    if ($violationCount -eq 0) {
        Write-Host "✅ Gate '$GateJobId' depends on all $($result.Missing.Count + $result.GateNeeds.Count) non-gate jobs." -ForegroundColor Green
        return 0
    }

    if ($result.Missing.Count -gt 0) {
        Write-Host "❌ Jobs missing from '$GateJobId' needs ($($result.Missing.Count)):" -ForegroundColor Red
        foreach ($job in $result.Missing) {
            Write-Host "   - $job" -ForegroundColor Red
        }
    }

    if ($result.Stale.Count -gt 0) {
        Write-Host "❌ Stale '$GateJobId' needs entries referencing missing jobs ($($result.Stale.Count)):" -ForegroundColor Red
        foreach ($job in $result.Stale) {
            Write-Host "   - $job" -ForegroundColor Red
        }
    }

    if ($FailOnViolation) {
        Write-Host "❌ $violationCount gate-completeness violation(s) found - failing." -ForegroundColor Red
        return 1
    }

    Write-Host "⚠️  $violationCount gate-completeness violation(s) found - soft fail mode." -ForegroundColor Yellow
    return 0
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-PrValidationGateCheck `
            -WorkflowPath $WorkflowPath `
            -GateJobId $GateJobId `
            -OutputPath $OutputPath `
            -FailOnViolation:$FailOnViolation
        exit $exitCode
    }
    catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
}

#endregion Main Execution
