# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# SecurityClasses.psm1
#
# Purpose: Shared class definitions for security scanning scripts.
# Author: HVE Core Team

<#
.SYNOPSIS
    Shared class definitions for dependency pinning and compliance reporting.

.DESCRIPTION
    This module contains class definitions used by security scanning scripts:
    - DependencyViolation: Represents a single dependency pinning violation
    - ComplianceReport: Aggregates violations and generates compliance reports

.NOTES
    Classes must be imported using 'using module' syntax at the top of scripts:
    using module ./Modules/SecurityClasses.psm1
#>

class DependencyViolation {
    <#
    .SYNOPSIS
        Represents a single dependency pinning violation.

    .DESCRIPTION
        Contains information about a dependency that is not properly SHA-pinned,
        including file location, dependency details, and remediation guidance.

        ViolationType values:
        - Unpinned: Dependency uses tag or branch instead of SHA
        - Stale: SHA is pinned but newer version available
        - VersionMismatch: Version comment does not match resolved SHA
        - MissingVersionComment: SHA pinned but no version comment present
        - Empty string: Default or unclassified violation
    #>

    [string]$File
    [int]$Line
    [string]$Type
    [string]$Name
    [string]$Version
    [string]$CurrentRef
    [string]$Severity
    [ValidateSet('Unpinned', 'Stale', 'VersionMismatch', 'MissingVersionComment', 'MissingPermissions', '')]
    [string]$ViolationType
    [string]$Description
    [string]$Remediation
    [hashtable]$Metadata

    DependencyViolation() {
        $this.Metadata = @{}
    }

    DependencyViolation(
        [string]$File,
        [int]$Line,
        [string]$Type,
        [string]$Name,
        [string]$Severity,
        [string]$Description
    ) {
        $this.File = $File
        $this.Line = $Line
        $this.Type = $Type
        $this.Name = $Name
        $this.Severity = $Severity
        $this.Description = $Description
        $this.Metadata = @{}
    }
}

class ComplianceReport {
    <#
    .SYNOPSIS
        Aggregates dependency violations and generates compliance reports.

    .DESCRIPTION
        Collects violations from dependency scans and provides metrics like
        compliance score, total dependencies, and summary by type.
    #>

    [string]$ScanPath
    [datetime]$Timestamp
    [int]$TotalFiles
    [int]$ScannedFiles
    [int]$TotalDependencies
    [int]$PinnedDependencies
    [int]$UnpinnedDependencies
    [decimal]$ComplianceScore
    [DependencyViolation[]]$Violations
    [hashtable]$Summary
    [hashtable]$Metadata

    ComplianceReport() {
        $this.Timestamp = Get-Date
        $this.Violations = @()
        $this.Summary = @{}
        $this.Metadata = @{}
    }

    ComplianceReport([string]$ScanPath) {
        $this.ScanPath = $ScanPath
        $this.Timestamp = Get-Date
        $this.Violations = @()
        $this.Summary = @{}
        $this.Metadata = @{}
    }

    [void] AddViolation([DependencyViolation]$Violation) {
        $this.Violations += $Violation
        $this.UnpinnedDependencies = $this.Violations.Count
    }

    [void] CalculateScore() {
        if ($this.TotalDependencies -gt 0) {
            $this.ComplianceScore = [math]::Round(
                ($this.PinnedDependencies / $this.TotalDependencies) * 100, 2
            )
        }
        else {
            $this.ComplianceScore = 100.0
        }
    }

    [hashtable] ToHashtable() {
        return @{
            ScanPath             = $this.ScanPath
            Timestamp            = $this.Timestamp.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            TotalFiles           = $this.TotalFiles
            ScannedFiles         = $this.ScannedFiles
            TotalDependencies    = $this.TotalDependencies
            PinnedDependencies   = $this.PinnedDependencies
            UnpinnedDependencies = $this.UnpinnedDependencies
            ComplianceScore      = $this.ComplianceScore
            Violations           = $this.Violations
            Summary              = $this.Summary
            Metadata             = $this.Metadata
        }
    }
}

# Classes are exported automatically when imported via 'using module' syntax.
# No functions to export.
Export-ModuleMember -Function @()
