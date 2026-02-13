#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates GitHub Actions version comment consistency across workflows.

.DESCRIPTION
    Scans workflow files for SHA-pinned actions and validates:
    - Same SHA has consistent version comments across all workflows
    - SHA-pinned actions include version comments for traceability

    Version comments follow the Renovate convention: action@sha # vX.Y.Z

.PARAMETER Path
    Path to scan for workflow files. Defaults to .github/workflows.

.PARAMETER Format
    Output format: Table, Json, Sarif. Defaults to Table.

.PARAMETER OutputPath
    Path to write output file when using Json or Sarif format.

.PARAMETER FailOnMismatch
    Exit with error code 1 if version mismatches are found.

.PARAMETER FailOnMissingComment
    Exit with error code 1 if missing version comments are found.

.EXAMPLE
    ./Test-ActionVersionConsistency.ps1
    Scan workflows and display results in table format.

.EXAMPLE
    ./Test-ActionVersionConsistency.ps1 -Format Sarif -OutputPath results.sarif
    Export results in SARIF format for CI integration.

.EXAMPLE
    ./Test-ActionVersionConsistency.ps1 -FailOnMismatch -FailOnMissingComment
    Fail the script if any consistency issues are found.

.NOTES
    Requires:
    - PowerShell 7.0 or later for cross-platform compatibility

.LINK
    https://docs.renovatebot.com/modules/manager/github-actions/
#>

using module ./Modules/SecurityClasses.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = '.github/workflows',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Table', 'Json', 'Sarif')]
    [string]$Format = 'Table',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMismatch,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMissingComment
)

$ErrorActionPreference = 'Stop'

# Import CIHelpers for workflow command escaping
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

function Write-ConsistencyLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-ActionVersionViolations {
    <#
    .SYNOPSIS
        Scans workflow files for version consistency violations.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowPath
    )

    # Enhanced regex to capture action, SHA, and optional version comment
    $actionPattern = 'uses:\s*(?<action>[^@\s]+)@(?<ref>[a-fA-F0-9]{40})(?:\s*#\s*(?<version>.+))?'

    $shaVersionMap = @{}
    $violations = [System.Collections.ArrayList]::new()
    $totalActions = 0

    # Resolve to absolute path
    $resolvedPath = Resolve-Path -Path $WorkflowPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-ConsistencyLog "Workflow path not found: $WorkflowPath" -Level Warning
        return @{
            Violations      = @()
            ShaVersionMap   = @{}
            TotalActions    = 0
        }
    }

    $workflowFiles = @(Get-ChildItem -Path $resolvedPath -Filter '*.yml' -Recurse -ErrorAction SilentlyContinue)
    $workflowFiles += @(Get-ChildItem -Path $resolvedPath -Filter '*.yaml' -Recurse -ErrorAction SilentlyContinue)

    foreach ($file in $workflowFiles) {
        $lines = Get-Content -Path $file.FullName
        $lineNumber = 0

        foreach ($line in $lines) {
            $lineNumber++

            if ($line -match $actionPattern) {
                $totalActions++
                $action = $Matches['action']
                $sha = $Matches['ref']
                $version = if ($Matches['version']) { $Matches['version'].Trim() } else { $null }
                $relativePath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $file.FullName)

                # Initialize SHA entry if not present
                if (-not $shaVersionMap.ContainsKey($sha)) {
                    $shaVersionMap[$sha] = @{
                        Action   = $action
                        Versions = [System.Collections.ArrayList]::new()
                        Sources  = [System.Collections.ArrayList]::new()
                    }
                }

                # Track version and source
                if ($version -and $version -notin $shaVersionMap[$sha].Versions) {
                    [void]$shaVersionMap[$sha].Versions.Add($version)
                }
                [void]$shaVersionMap[$sha].Sources.Add(@{
                    File       = $relativePath
                    FullPath   = $file.FullName
                    Line       = $lineNumber
                    Version    = $version
                    LineContent = $line.Trim()
                })

                # Detect missing version comment
                if (-not $version) {
                    $violation = [DependencyViolation]::new()
                    $violation.File = $relativePath
                    $violation.Line = $lineNumber
                    $violation.Type = 'github-actions'
                    $violation.Name = $action
                    $violation.Version = $sha.Substring(0, 7)
                    $violation.Severity = 'Medium'
                    $violation.ViolationType = 'MissingVersionComment'
                    $violation.Description = 'SHA-pinned action missing version comment'
                    $violation.Remediation = "Add version comment: $action@$sha # vX.Y.Z"
                    $violation.Metadata = @{
                        FullSha     = $sha
                        LineContent = $line.Trim()
                    }
                    [void]$violations.Add($violation)
                }
            }
        }
    }

    # Detect version mismatches (same SHA, different version comments)
    foreach ($sha in $shaVersionMap.Keys) {
        $entry = $shaVersionMap[$sha]

        if ($entry.Versions.Count -gt 1) {
            # Report one violation per SHA with all affected locations in Metadata
            $primarySource = $entry.Sources[0]
            $allLocations = $entry.Sources | ForEach-Object { "$($_.File):$($_.Line)" }

            $violation = [DependencyViolation]::new()
            $violation.File = $primarySource.File
            $violation.Line = $primarySource.Line
            $violation.Type = 'github-actions'
            $violation.Name = $entry.Action
            $violation.Version = $sha.Substring(0, 7)
            $violation.Severity = 'High'
            $violation.ViolationType = 'VersionMismatch'
            $violation.Description = "Same SHA has conflicting version comments across $($entry.Sources.Count) files: $($entry.Versions -join ' vs ')"
            $violation.Remediation = 'Standardize version comment across all workflows'
            $violation.Metadata = @{
                FullSha             = $sha
                ConflictingVersions = $entry.Versions -join ', '
                AffectedLocations   = $allLocations
                LineContent         = $primarySource.LineContent
            }
            [void]$violations.Add($violation)
        }
    }

    return @{
        Violations    = $violations
        ShaVersionMap = $shaVersionMap
        TotalActions  = $totalActions
    }
}

function Export-ConsistencyReport {
    <#
    .SYNOPSIS
        Exports consistency report in the specified format.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Violations,

        [Parameter(Mandatory)]
        [string]$Format,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [int]$TotalActions
    )

    $reportData = @{
        Timestamp       = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        TotalActions    = $TotalActions
        MismatchCount   = @($Violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' }).Count
        MissingComments = @($Violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' }).Count
        Violations      = $Violations
    }

    switch ($Format) {
        'Table' {
            if ($Violations.Count -eq 0) {
                Write-ConsistencyLog 'No version consistency violations found.' -Level Success
            }
            else {
                $Violations | Format-Table -Property @(
                    @{ Label = 'File'; Expression = { $_.File } }
                    @{ Label = 'Line'; Expression = { $_.Line } }
                    @{ Label = 'Type'; Expression = { $_.ViolationType } }
                    @{ Label = 'Action'; Expression = { $_.Name } }
                    @{ Label = 'Severity'; Expression = { $_.Severity } }
                    @{ Label = 'Description'; Expression = { $_.Description } }
                ) -AutoSize -Wrap
            }

            if ($OutputPath) {
                $Violations | Format-Table -Property File, Line, ViolationType, Name, Severity, Description -AutoSize |
                    Out-File -FilePath $OutputPath -Encoding UTF8 -Width 200
            }
        }

        'Json' {
            $json = $reportData | ConvertTo-Json -Depth 10

            if ($OutputPath) {
                $json | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-ConsistencyLog "Report exported to: $OutputPath" -Level Success
            }
            else {
                Write-Output $json
            }
        }

        'Sarif' {
            $sarif = @{
                version    = '2.1.0'
                '$schema'  = 'https://json.schemastore.org/sarif-2.1.0.json'
                runs       = @(@{
                    tool    = @{
                        driver = @{
                            name           = 'action-version-consistency'
                            version        = '1.0.0'
                            informationUri = 'https://github.com/microsoft/hve-core'
                            rules          = @(
                                @{
                                    id               = 'version-mismatch'
                                    name             = 'VersionMismatch'
                                    shortDescription = @{ text = 'Same SHA has conflicting version comments' }
                                    defaultConfiguration = @{ level = 'error' }
                                }
                                @{
                                    id               = 'missing-version-comment'
                                    name             = 'MissingVersionComment'
                                    shortDescription = @{ text = 'SHA-pinned action missing version comment' }
                                    defaultConfiguration = @{ level = 'warning' }
                                }
                            )
                        }
                    }
                    results = @($Violations | ForEach-Object {
                        $ruleId = switch ($_.ViolationType) {
                            'VersionMismatch' { 'version-mismatch' }
                            'MissingVersionComment' { 'missing-version-comment' }
                            default { 'unknown' }
                        }
                        $level = switch ($_.Severity) {
                            'High' { 'error' }
                            'Medium' { 'warning' }
                            default { 'note' }
                        }
                        @{
                            ruleId    = $ruleId
                            level     = $level
                            message   = @{ text = $_.Description }
                            locations = @(@{
                                physicalLocation = @{
                                    artifactLocation = @{ uri = $_.File }
                                    region           = @{ startLine = $_.Line }
                                }
                            })
                            properties = @{
                                actionName  = $_.Name
                                sha         = $_.Version
                                remediation = $_.Remediation
                            }
                        }
                    })
                })
            }

            $json = $sarif | ConvertTo-Json -Depth 15

            if ($OutputPath) {
                $json | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-ConsistencyLog "SARIF report exported to: $OutputPath" -Level Success
            }
            else {
                Write-Output $json
            }
        }
    }
}

function Invoke-ActionVersionConsistency {
    <#
    .SYNOPSIS
        Orchestrates the version consistency analysis.
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = '.github/workflows',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Table', 'Json', 'Sarif')]
        [string]$Format = 'Table',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$FailOnMismatch,

        [Parameter(Mandatory = $false)]
        [switch]$FailOnMissingComment
    )

    Write-ConsistencyLog 'Starting GitHub Actions version consistency analysis...' -Level Info
    Write-ConsistencyLog "Scanning path: $Path" -Level Info

    # Scan for violations
    $result = Get-ActionVersionViolations -WorkflowPath $Path

    $violations = $result.Violations
    $mismatchCount = @($violations | Where-Object { $_.ViolationType -eq 'VersionMismatch' }).Count
    $missingCount = @($violations | Where-Object { $_.ViolationType -eq 'MissingVersionComment' }).Count

    Write-ConsistencyLog "Scanned $($result.TotalActions) SHA-pinned actions" -Level Info
    Write-ConsistencyLog "Found $mismatchCount version mismatches" -Level $(if ($mismatchCount -gt 0) { 'Warning' } else { 'Info' })
    Write-ConsistencyLog "Found $missingCount missing version comments" -Level $(if ($missingCount -gt 0) { 'Warning' } else { 'Info' })

    # Export report (pipe to Out-Host to prevent pipeline pollution of return value)
    Export-ConsistencyReport -Violations $violations -Format $Format -OutputPath $OutputPath -TotalActions $result.TotalActions | Out-Host

    # Determine exit code
    $exitCode = 0

    if ($FailOnMismatch -and $mismatchCount -gt 0) {
        Write-ConsistencyLog "Failing due to $mismatchCount version mismatch(es) (-FailOnMismatch enabled)" -Level Error
        $exitCode = 1
    }

    if ($FailOnMissingComment -and $missingCount -gt 0) {
        Write-ConsistencyLog "Failing due to $missingCount missing version comment(s) (-FailOnMissingComment enabled)" -Level Error
        $exitCode = 1
    }

    if ($exitCode -eq 0 -and $violations.Count -eq 0) {
        Write-ConsistencyLog 'All SHA-pinned actions have consistent version comments!' -Level Success
    }

    return $exitCode
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-ActionVersionConsistency @PSBoundParameters
        exit $exitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ActionVersionConsistency failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
