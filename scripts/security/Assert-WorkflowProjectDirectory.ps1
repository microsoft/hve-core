#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates repository-derived project directories before they become workflow data.
.DESCRIPTION
    Workflow discovery steps enumerate project directories from the checked-out repository
    and publish them as a JSON matrix through GITHUB_OUTPUT. Those directory names originate
    in repository content, so on a pull request they are contributor-controlled. JSON encoding
    protects the GITHUB_OUTPUT write, but fromJson decodes the value before it is interpolated
    downstream, so the encoding does not protect the consuming step.

    This script enforces one path contract at that boundary. A candidate is accepted only when
    it is '.' or a normalized repository-relative POSIX path built from the allowed character
    set. Absolute paths, backslashes, control characters, shell metacharacters, empty segments,
    and traversal segments are rejected.

    Dot-source the script to use its functions inside a workflow discovery step, or invoke it
    directly to validate a candidate list from the command line.
.PARAMETER Path
    Candidate repository-relative project directories to validate.
.PARAMETER Quiet
    Suppresses the per-path confirmation output when invoked directly.
.EXAMPLE
    . ./scripts/security/Assert-WorkflowProjectDirectory.ps1
    $validated = Assert-WorkflowProjectDirectory -Path $projectList
.EXAMPLE
    ./scripts/security/Assert-WorkflowProjectDirectory.ps1 -Path 'scripts' -Path 'docs/docusaurus'
.NOTES
    Consumed by the project discovery steps in pr-validation.yml, release-stable.yml, and
    weekly-validation.yml. Behavior is owned by scripts/tests/security/Assert-WorkflowProjectDirectory.Tests.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Path = @(),

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

#region Functions

<#
.SYNOPSIS
    Returns the reason a project directory candidate is rejected, or $null when it is accepted.
.DESCRIPTION
    Evaluates one candidate against the workflow project-directory contract and returns a
    human-readable rejection reason. Returning $null means the candidate is safe to publish
    into a workflow matrix.
.PARAMETER Candidate
    The candidate repository-relative project directory.
#>
function Get-WorkflowProjectDirectoryRejection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Candidate
    )

    if ($null -eq $Candidate -or $Candidate -eq '') {
        return 'the path is empty'
    }

    if ($Candidate -ne $Candidate.Trim()) {
        return 'the path has leading or trailing whitespace'
    }

    # Control characters, including newline and carriage return, must never reach a shell,
    # a JSON matrix value, or a GITHUB_OUTPUT line.
    foreach ($character in $Candidate.ToCharArray()) {
        if ([char]::IsControl($character)) {
            return 'the path contains a control character'
        }
    }

    # The repository root is the one non-path-shaped value discovery may legitimately produce.
    if ($Candidate -eq '.') {
        return $null
    }

    if ($Candidate.Contains('\')) {
        return 'the path contains a backslash; repository-relative POSIX separators are required'
    }

    if ($Candidate.StartsWith('/')) {
        return 'the path is absolute'
    }

    if ($Candidate -match '^[A-Za-z]:') {
        return 'the path is a drive-qualified absolute path'
    }

    # The allowed set excludes every shell metacharacter, quote, and whitespace character,
    # so a rejected candidate cannot alter command structure in any consuming step.
    if ($Candidate -notmatch '^[A-Za-z0-9._/-]+$') {
        return 'the path contains a character outside the allowed set [A-Za-z0-9._/-]'
    }

    $segments = $Candidate.Split('/')
    foreach ($segment in $segments) {
        if ($segment -eq '') {
            return 'the path contains an empty segment'
        }
        if ($segment -eq '.' -or $segment -eq '..') {
            return 'the path contains a relative traversal segment'
        }
    }

    return $null
}

<#
.SYNOPSIS
    Validates a complete candidate list and returns it when every entry is accepted.
.DESCRIPTION
    Evaluates every candidate before returning. A single rejected candidate throws, so a
    calling discovery step terminates before writing any workflow output. The complete list
    is validated rather than filtered, because silently dropping a hostile path would hide
    the condition from the operator.
.PARAMETER Path
    Candidate repository-relative project directories to validate.
#>
function Assert-WorkflowProjectDirectory {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Path = @()
    )

    $rejections = @()
    foreach ($candidate in $Path) {
        $reason = Get-WorkflowProjectDirectoryRejection -Candidate $candidate
        if ($null -ne $reason) {
            $rejections += "'$candidate' was rejected because $reason."
        }
    }

    if ($rejections.Count -gt 0) {
        $detail = $rejections -join ' '
        throw "Unsafe project directory detected in repository content. $detail Rename the directory to use only [A-Za-z0-9._/-] characters."
    }

    return $Path
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $validated = Assert-WorkflowProjectDirectory -Path $Path
        if (-not $Quiet) {
            foreach ($validated_path in $validated) {
                Write-Output $validated_path
            }
        }
        exit 0
    }
    catch {
        Write-Error -Message $_.Exception.Message -ErrorAction Continue
        exit 1
    }
}

#endregion Main Execution
