# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# AdrBodyParser.psm1
#
# Purpose: Shared body-section parser for ADR consistency validation.
#          Extracts H2 sections, bullets, table rows, and path-shaped tokens
#          from Architecture Decision Record markdown for downstream rule checks.
# Author: HVE Core Team

#Requires -Version 7.4

#region Parsing Helpers

function Remove-AdrFencedCodeBlocks {
    <#
    .SYNOPSIS
        Removes fenced code blocks and inline code spans from ADR body text.
    .DESCRIPTION
        Strips ``` and ~~~ delimited fenced code blocks line-by-line so downstream
        section parsers do not pick up bullets, headings, or path tokens that appear
        inside code samples. Fences are matched on the trimmed line start to tolerate
        leading whitespace inside lists. Single-backtick inline code spans are also
        removed so path-shaped tokens inside `code` do not leak into rule scans.
    .PARAMETER Text
        The raw ADR body text (frontmatter already stripped).
    .PARAMETER PreserveInlineCode
        When set, retains single-backtick inline code spans. Multi-line fenced
        blocks are still stripped. Use this when the caller needs to detect
        path-shaped tokens that authors place inside inline code.
    .OUTPUTS
        The same text with fenced code-block lines (and optionally inline code
        spans) removed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$PreserveInlineCode
    )

    if ([string]::IsNullOrEmpty($Text)) { return '' }

    $lines = $Text -split "`r?`n"
    $sb = [System.Text.StringBuilder]::new()
    $inFence = $false
    $fenceMarker = $null

    foreach ($line in $lines) {
        $trimmed = $line.TrimStart()
        if (-not $inFence) {
            if ($trimmed -match '^(```+|~~~+)') {
                $inFence = $true
                $fenceMarker = $matches[1].Substring(0, 1)
                continue
            }
            [void]$sb.AppendLine($line)
        }
        else {
            if ($trimmed -match "^($([regex]::Escape($fenceMarker))){3,}\s*$") {
                $inFence = $false
                $fenceMarker = $null
            }
            continue
        }
    }

    $result = $sb.ToString()
    if (-not $PreserveInlineCode) {
        $result = $result -replace '`[^`]*`', ''
    }
    return $result
}

function Get-AdrH2Section {
    <#
    .SYNOPSIS
        Returns the body of a single ATX H2 section by heading text.
    .DESCRIPTION
        Locates a heading line of the form '## <HeadingText>' (case-insensitive,
        leading/trailing whitespace tolerated) and returns all text up to the next
        '## ' heading or end of input. Returns an empty string when the heading is
        not found.
    .PARAMETER Text
        ADR body text with fenced code blocks already removed.
    .PARAMETER HeadingText
        Plain heading text (without leading '## ').
    .OUTPUTS
        The section body text or an empty string when missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HeadingText
    )

    if ([string]::IsNullOrEmpty($Text)) { return '' }

    $lines = $Text -split "`r?`n"
    $startIndex = -1
    $headingPattern = '^\s*##\s+' + [regex]::Escape($HeadingText) + '\s*$'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $headingPattern) {
            $startIndex = $i + 1
            break
        }
    }

    if ($startIndex -lt 0) { return '' }

    $endIndex = $lines.Count
    for ($j = $startIndex; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^\s*##\s+\S') {
            $endIndex = $j
            break
        }
    }

    return ($lines[$startIndex..($endIndex - 1)] -join "`n")
}

function Get-AdrH3SectionInH2 {
    <#
    .SYNOPSIS
        Returns the body of an ATX H3 subsection nested inside a named H2 section.
    .DESCRIPTION
        First locates the parent H2 via Get-AdrH2Section, then within that section
        scans for an '### <HeadingText>' heading (case-insensitive, leading/trailing
        whitespace tolerated) and returns text up to the next '### ' heading or the
        end of the parent H2. Returns an empty string when either heading is missing.

        This supports MADR v4 canonical structure where 'Consequences' and
        'Confirmation' appear as H3 children of '## Decision Outcome' rather than
        as standalone H2 sections.
    .PARAMETER Text
        ADR body text with fenced code blocks already removed.
    .PARAMETER ParentH2
        Plain heading text of the enclosing H2 (without leading '## ').
    .PARAMETER HeadingText
        Plain heading text of the H3 subsection (without leading '### ').
    .OUTPUTS
        The H3 subsection body text or an empty string when missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParentH2,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HeadingText
    )

    $parent = Get-AdrH2Section -Text $Text -HeadingText $ParentH2
    if ([string]::IsNullOrEmpty($parent)) { return '' }

    $lines = $parent -split "`r?`n"
    $startIndex = -1
    $headingPattern = '^\s*###\s+' + [regex]::Escape($HeadingText) + '\s*$'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $headingPattern) {
            $startIndex = $i + 1
            break
        }
    }

    if ($startIndex -lt 0) { return '' }

    $endIndex = $lines.Count
    for ($j = $startIndex; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^\s*###\s+\S') {
            $endIndex = $j
            break
        }
    }

    return ($lines[$startIndex..($endIndex - 1)] -join "`n")
}

function Get-AdrBulletItems {
    <#
    .SYNOPSIS
        Extracts top-level bullet items from a markdown section.
    .DESCRIPTION
        Returns the trimmed text of every bullet that begins with '*', '-', or '+'
        at column 0-3 (CommonMark allows up to three leading spaces before a list
        marker). Nested bullets indented four or more spaces are excluded.
    .PARAMETER SectionText
        Section body text returned by Get-AdrH2Section.
    .OUTPUTS
        String array of bullet item text.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SectionText
    )

    $items = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrEmpty($SectionText)) { return @() }

    foreach ($line in ($SectionText -split "`r?`n")) {
        if ($line -match '^[ \t]{0,3}[\*\-\+]\s+(.+)$') {
            $items.Add($matches[1].Trim())
        }
    }

    return $items.ToArray()
}

function Get-AdrTableRows {
    <#
    .SYNOPSIS
        Extracts the first-column cell value from every data row in a markdown table.
    .DESCRIPTION
        Detects pipe-delimited markdown tables, skips the header and the alignment
        separator row (the row containing only '-', ':', spaces, and pipes), and
        returns the trimmed first-column value of every remaining data row.
    .PARAMETER SectionText
        Section body text returned by Get-AdrH2Section.
    .OUTPUTS
        String array of first-column cell values.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SectionText
    )

    $rows = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrEmpty($SectionText)) { return @() }

    $lines = $SectionText -split "`r?`n"
    $sawHeader = $false
    $sawSeparator = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('|')) {
            if ($sawSeparator) { $sawHeader = $false; $sawSeparator = $false }
            continue
        }

        if (-not $sawHeader) {
            $sawHeader = $true
            continue
        }

        if (-not $sawSeparator) {
            if ($trimmed -match '^\|[\s\-:|]+\|$') {
                $sawSeparator = $true
                continue
            }
            $sawHeader = $false
            continue
        }

        $cells = $trimmed.Trim('|') -split '\|'
        if ($cells.Count -ge 1) {
            $first = $cells[0].Trim()
            if ($first) { $rows.Add($first) }
        }
    }

    return $rows.ToArray()
}

function Get-AdrPathTokens {
    <#
    .SYNOPSIS
        Extracts repository-relative path-shaped tokens from a section.
    .DESCRIPTION
        Scans a section's text (including code spans wrapped in backticks) and
        returns tokens that look like repo-relative paths: they contain at least
        one forward slash, either end in a recognized file extension or a trailing
        slash, and consist of path-safe characters. Markdown link text and inline
        code spans are both considered.
    .PARAMETER SectionText
        Section body text returned by Get-AdrH2Section.
    .OUTPUTS
        Distinct string array of path-shaped tokens preserving first-seen order.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SectionText
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $ordered = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrEmpty($SectionText)) { return @() }

    $pattern = '(?<![A-Za-z0-9_\-./])([A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*(?:/\.[A-Za-z0-9_][A-Za-z0-9_.-]*|\.[A-Za-z0-9]{1,8}|/))(?![A-Za-z0-9_.-])'
    foreach ($match in [regex]::Matches($SectionText, $pattern)) {
        $token = $match.Groups[1].Value.Trim()
        if (-not $token) { continue }
        if ($seen.Add($token)) { $ordered.Add($token) }
    }

    return $ordered.ToArray()
}

function Get-AdrBadConsequenceBullets {
    <#
    .SYNOPSIS
        Extracts bullets under the 'Bad' subsection of '## Consequences'.
    .DESCRIPTION
        Returns top-level bullets that appear after the first heading or bold-prefixed
        line whose text begins with 'Bad' (case-insensitive) within the Consequences
        section, and stops at the next sibling heading or bold-prefixed group.
    .PARAMETER ConsequencesText
        Body text of the '## Consequences' section.
    .OUTPUTS
        String array of bullet item text under the Bad subsection.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ConsequencesText
    )

    if ([string]::IsNullOrEmpty($ConsequencesText)) { return @() }

    $lines = $ConsequencesText -split "`r?`n"
    $inBad = $false
    $items = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        $isGroupStart = $trimmed -match '^(#{3,6}\s+|[\*_]{1,2})\s*Bad\b'
        $isOtherGroup = $trimmed -match '^(#{3,6}\s+|[\*_]{1,2})\s*(Good|Neutral)\b'

        if ($isGroupStart) { $inBad = $true; continue }
        if ($inBad -and $isOtherGroup) { $inBad = $false; continue }

        if ($inBad -and ($line -match '^[ \t]{0,3}[\*\-\+]\s+(.+)$')) {
            $items.Add($matches[1].Trim())
        }
    }

    return $items.ToArray()
}

#endregion Parsing Helpers

#region Public API

function Get-AdrBodySections {
    <#
    .SYNOPSIS
        Parses an ADR markdown body into a structured object for consistency checks.
    .DESCRIPTION
        Strips fenced code blocks, locates ATX H2 sections, and extracts the bullet
        items, table rows, and path-shaped tokens needed by the ADR consistency rule
        registry. Returns a single object whose property names mirror the rule
        registry's expectations.

        The parser recognizes these sections (case-insensitive, ATX style only):
          * '## Affected Components'  - bullet list under heading
          * '## Decision Drivers'     - bullet list under heading
          * '## Decision Outcome'     - first markdown table; first column collected
          * 'Consequences'            - bullets under the 'Bad' subsection.
                                        Looked up at '## Consequences' (H2) first;
                                        falls back to '### Consequences' nested in
                                        '## Decision Outcome' (MADR v4 canonical).
          * '## Risks and Mitigations'- first markdown table; first column collected
          * 'Confirmation'            - raw section text retained.
                                        Looked up at '## Confirmation' (H2) first;
                                        falls back to '### Confirmation' nested in
                                        '## Decision Outcome' (MADR v4 canonical).
          * '## Context'              - path tokens extracted
          * '## More Information'     - path tokens extracted

    .PARAMETER Text
        ADR body markdown with frontmatter already stripped.
    .OUTPUTS
        PSCustomObject with the following properties:
          AffectedComponents             [string[]]
          DecisionDrivers                [string[]]
          DecisionOutcomeMatrixDrivers   [string[]]
          BadConsequences                [string[]]
          RisksAndMitigationsRisks       [string[]]
          Confirmation                   [string]
          ContextPathTokens              [string[]]
          MoreInformationPathTokens      [string[]]
          ConfirmationPathTokens         [string[]]
    .EXAMPLE
        $body = Get-Content ./adr.md -Raw
        $sections = Get-AdrBodySections -Text $body
        $sections.AffectedComponents
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $sanitized = Remove-AdrFencedCodeBlocks -Text $Text
    $sanitizedKeepInline = Remove-AdrFencedCodeBlocks -Text $Text -PreserveInlineCode

    $affectedSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Affected Components'
    $driversSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Decision Drivers'
    $outcomeSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Decision Outcome'
    $consequencesSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Consequences'
    if ([string]::IsNullOrEmpty($consequencesSection)) {
        $consequencesSection = Get-AdrH3SectionInH2 -Text $sanitized -ParentH2 'Decision Outcome' -HeadingText 'Consequences'
    }
    $risksSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Risks and Mitigations'
    $confirmationSection = Get-AdrH2Section -Text $sanitized -HeadingText 'Confirmation'
    if ([string]::IsNullOrEmpty($confirmationSection)) {
        $confirmationSection = Get-AdrH3SectionInH2 -Text $sanitized -ParentH2 'Decision Outcome' -HeadingText 'Confirmation'
    }

    # Path-token sections retain inline code spans so authors can cite affected
    # components inside `backticks`, which is the idiomatic markdown form.
    $contextSectionInline = Get-AdrH2Section -Text $sanitizedKeepInline -HeadingText 'Context'
    $moreInfoSectionInline = Get-AdrH2Section -Text $sanitizedKeepInline -HeadingText 'More Information'
    $confirmationSectionInline = Get-AdrH2Section -Text $sanitizedKeepInline -HeadingText 'Confirmation'
    if ([string]::IsNullOrEmpty($confirmationSectionInline)) {
        $confirmationSectionInline = Get-AdrH3SectionInH2 -Text $sanitizedKeepInline -ParentH2 'Decision Outcome' -HeadingText 'Confirmation'
    }

    return [pscustomobject]@{
        AffectedComponents           = Get-AdrBulletItems -SectionText $affectedSection
        DecisionDrivers              = Get-AdrBulletItems -SectionText $driversSection
        DecisionOutcomeMatrixDrivers = Get-AdrTableRows -SectionText $outcomeSection
        BadConsequences              = Get-AdrBadConsequenceBullets -ConsequencesText $consequencesSection
        RisksAndMitigationsRisks     = Get-AdrTableRows -SectionText $risksSection
        Confirmation                 = $confirmationSection
        ContextPathTokens            = Get-AdrPathTokens -SectionText $contextSectionInline
        MoreInformationPathTokens    = Get-AdrPathTokens -SectionText $moreInfoSectionInline
        ConfirmationPathTokens       = Get-AdrPathTokens -SectionText $confirmationSectionInline
    }
}

#endregion Public API

Export-ModuleMember -Function @('Get-AdrBodySections', 'Remove-AdrFencedCodeBlocks')
