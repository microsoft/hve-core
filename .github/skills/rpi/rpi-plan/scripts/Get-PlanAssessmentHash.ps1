#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Emit the canonical assessed projection and SHA-256 of a saved RPI plan.
.DESCRIPTION
    Read strict UTF-8, normalize line endings, and exclude only documented
    bookkeeping, marked checklist status and task-local Guidance blocks.
    Return JSON without modifying the plan. Invalid input terminates with exit 1.
.PARAMETER PlanPath
    Literal path to the saved UTF-8 plan.
.EXAMPLE
    ./Get-PlanAssessmentHash.ps1 -PlanPath ./plan.md
.NOTES
    Requires only PowerShell 7.4. Tests run through npm run test:ps.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PlanPath
)

$ErrorActionPreference = 'Stop'

#region Functions
function Get-PlanAssessmentHash {
    <#
    .SYNOPSIS
        Compute versioned assessed content from a canonical RPI Markdown plan.
    .PARAMETER PlanPath
        Literal path to the saved plan.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PlanPath
    )

    $Path = (Get-Item -LiteralPath $PlanPath -ErrorAction Stop).FullName
    $Utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $Text = $Utf8.GetString([System.IO.File]::ReadAllBytes($Path))
    if ($Text.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)) {
        $Text = $Text.Substring(1)
    }
    $Text = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'The plan is empty.'
    }

    $ExcludedSections = @(
        'Critique Disposition', 'Artifact Self-Check', 'Planning Readiness and Next Step',
        'Follow-Up Items', 'Handoff'
    )
    $Lines = $Text.Split("`n")
    $Result = [System.Text.StringBuilder]::new()
    $Excluded = $false
    $InChecklist = $false
    $ChecklistCount = 0
    $InTask = $false
    $TaskBlock = ''
    $InGuidance = $false
    $Marker = ''
    $Fence = ''
    $FenceLength = 0
    $InComment = $false

    for ($Index = 0; $Index -lt $Lines.Length; $Index++) {
        $Line = $Lines[$Index]
        $OutputLine = $Line
        $Structural = $true
        if ($Fence) {
            if ($Line -cmatch ('^ {0,3}' + [regex]::Escape($Fence) + '{' + $FenceLength + ',}[ \t]*$')) {
                $Fence = ''
            }
            $Structural = $false
        }
        elseif (-not $InComment -and $Line -cmatch '^ {0,3}(`{3,}|~{3,})(.*)$') {
            $Delimiter = $Matches[1]
            $Info = $Matches[2]
            if ($Delimiter[0] -eq '~' -or -not $Info.Contains('`')) {
                $Fence = [string]$Delimiter[0]
                $FenceLength = $Delimiter.Length
                $Structural = $false
            }
        }
        elseif ($InComment -or $Line.Contains('<!--')) {
            $WasInComment = $InComment
            $Offset = 0
            while ($Offset -lt $Line.Length) {
                $Token = if ($InComment) { '-->' } else { '<!--' }
                $Position = $Line.IndexOf($Token, $Offset, [System.StringComparison]::Ordinal)
                if ($Position -lt 0) { break }
                $InComment = -not $InComment
                $Offset = $Position + $Token.Length
            }
            $Structural = -not $WasInComment -and -not $InComment -and
                $Line -cmatch '^<!-- rpi:(?:phase id=P[0-9]{2}|task id=P[0-9]{2}-T[0-9]{2}) -->$'
        }

        if ($Structural) {
            if ($Line -cmatch '^(#{1,4})[ \t]+(.+?)[ \t]*$') {
                $Level = $Matches[1].Length
                $Heading = $Matches[2] -creplace '[ \t]+#+$', ''
                if ($InGuidance) {
                    throw 'Task-local Guidance must end at References before another heading.'
                }
                $InTask = $false
                $TaskBlock = ''
                if ($Level -le 2) {
                    $Excluded = $Level -eq 2 -and $ExcludedSections -ccontains $Heading
                    $InChecklist = $Level -eq 2 -and $Heading -ceq 'Phase Checklist'
                    if ($InChecklist) { $ChecklistCount++ }
                }
                if ($InChecklist -and $Marker) {
                    $TaskMarker = $Marker.Contains('-T')
                    $ExpectedLevel = if ($TaskMarker) { 4 } else { 3 }
                    $Pattern = '^' + ('#' * $ExpectedLevel) + ' \[[ xX]\] ' + [regex]::Escape($Marker) + ': .+$'
                    if ($Line -cmatch $Pattern) {
                        $OutputLine = $Line -creplace '^((?:###|####) )\[[ xX]\]', '${1}[ ]'
                        $InTask = $TaskMarker
                    }
                }
            }

            if ($InTask -and $Line -cmatch '^([A-Za-z][A-Za-z -]*):[ \t]*$') {
                $Label = $Matches[1]
                if ($InGuidance) {
                    if ($Label -cne 'References') {
                        throw 'Task-local Guidance must be followed by References.'
                    }
                    $InGuidance = $false
                }
                elseif ($Label -ceq 'Guidance') {
                    if ($TaskBlock -cne 'Details') {
                        throw 'Task-local Guidance must follow Details.'
                    }
                    $InGuidance = $true
                }
                $TaskBlock = $Label
            }

            $Marker = ''
            if ($InChecklist -and $Line -cmatch '^<!-- rpi:(?:phase id=(P[0-9]{2})|task id=(P[0-9]{2}-T[0-9]{2})) -->$') {
                $Marker = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
                if ($InGuidance) {
                    throw 'Task-local Guidance must end at References before another marker.'
                }
            }
        }
        else {
            $Marker = ''
        }

        if (-not $Excluded -and -not $InGuidance) {
            [void]$Result.Append($OutputLine)
            if ($Index -lt $Lines.Length - 1) {
                [void]$Result.Append("`n")
            }
        }
    }

    if ($Fence -or $InComment -or $InGuidance) {
        throw 'The plan contains an unterminated fence, comment or Guidance block.'
    }
    if ($ChecklistCount -ne 1) {
        throw 'The plan must contain exactly one level-two Phase Checklist section.'
    }
    $Projection = $Result.ToString()
    $Hash = [System.Security.Cryptography.SHA256]::HashData($Utf8.GetBytes($Projection))
    [pscustomobject][ordered]@{
        projection_version = 'rpi-plan-assessment-v1'
        sha256 = [System.Convert]::ToHexString($Hash).ToLowerInvariant()
        projection = $Projection
    }
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ([string]::IsNullOrWhiteSpace($PlanPath)) {
            throw 'Specify -PlanPath with a saved UTF-8 plan.'
        }
        Get-PlanAssessmentHash -PlanPath $PlanPath | ConvertTo-Json -Depth 3 -EscapeHandling EscapeNonAscii
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Plan assessment hash failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution
