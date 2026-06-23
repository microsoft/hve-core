# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# AnalyzerFixtures.psm1
#
# Purpose: Reusable mock-object factories for PSScriptAnalyzer-related Pester tests.
# Author: HVE Core Team
#

function New-MockAnalyzerIssue {
    <#
    .SYNOPSIS
    Builds a PSScriptAnalyzer-shaped diagnostic record for use as a mock return value.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ScriptPath = 'test.ps1',
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Line = 1,
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Column = 1,
        [string]$RuleName = 'TestRule',
        [ValidateSet('ParseError', 'Error', 'Warning', 'Information')]
        [string]$Severity = 'Warning',
        [string]$Message = 'Test message'
    )
    [PSCustomObject]@{
        ScriptPath = $ScriptPath
        Line       = $Line
        Column     = $Column
        RuleName   = $RuleName
        Severity   = $Severity
        Message    = $Message
    }
}

Export-ModuleMember -Function New-MockAnalyzerIssue
