# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# CopyrightHeader.psm1
#
# Purpose: Shared copyright header constants and regex helpers for hve-core scripts.
# Author: HVE Core Team

#Requires -Version 7.4

$script:CopyrightLineLiteral = 'Copyright (c) 2026 Microsoft Corporation. All rights reserved.'
$script:SpdxLineLiteral = 'SPDX-License-Identifier: MIT'

function Get-CopyrightLineRegex {
    <#
    .SYNOPSIS
    Builds a regex for the canonical copyright line.

    .DESCRIPTION
    Returns a regex that matches the canonical copyright header line with a
    four-digit year of 2026 or later. The regex is anchored to the start and
    end of the line so it can be used for validation without matching unrelated
    comments.

    .PARAMETER CommentPrefix
    The comment prefix used by the file, either '#' or '//'.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('#', '//')]
        [string]$CommentPrefix = '#'
    )

    $escapedPrefix = [regex]::Escape($CommentPrefix)
    $yearPattern = '(?:20(?:2[6-9]|[3-9]\d)|2[1-9]\d{2})'

    return "^\s*$escapedPrefix\s*Copyright\s*\(c\)\s*$yearPattern\s+Microsoft\s+Corporation\.\s*All\s+rights\s+reserved\.\s*$"
}

function Get-SpdxLineRegex {
    <#
    .SYNOPSIS
    Builds a regex for the SPDX line.

    .DESCRIPTION
    Returns a regex that matches the SPDX line for the canonical header using
    the supplied comment prefix.

    .PARAMETER CommentPrefix
    The comment prefix used by the file, either '#' or '//'.

    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('#', '//')]
        [string]$CommentPrefix = '#'
    )

    $escapedPrefix = [regex]::Escape($CommentPrefix)
    return "^\s*$escapedPrefix\s*SPDX-License-Identifier:\s*MIT\s*$"
}

function Get-CanonicalHeaderLines {
    <#
    .SYNOPSIS
    Returns the canonical header lines for a comment prefix.

    .DESCRIPTION
    Builds the two-line canonical header for either '#' or '//' comment styles.

    .PARAMETER CommentPrefix
    The comment prefix used by the file, either '#' or '//'.

    .OUTPUTS
    System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('#', '//')]
        [string]$CommentPrefix
    )

    return @(
        "$CommentPrefix $script:CopyrightLineLiteral"
        "$CommentPrefix $script:SpdxLineLiteral"
    )
}

Export-ModuleMember -Function Get-CopyrightLineRegex, Get-SpdxLineRegex, Get-CanonicalHeaderLines -Variable CopyrightLineLiteral, SpdxLineLiteral
