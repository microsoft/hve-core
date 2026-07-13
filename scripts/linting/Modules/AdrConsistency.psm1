# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# AdrConsistency.psm1
#
# Purpose: ADR Planner Govern-phase consistency validator.
# Enforces the rule registry under scripts/linting/rules/adr-consistency-rules.json
# (ADR-CONSISTENCY-001 .. 009) against rendered ADR markdown files.
# Author: HVE Core Team

#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PowerShell-Yaml'; RequiredVersion = '0.4.7' }

#region Module setup

if (-not (Get-Module -Name PowerShell-Yaml)) {
    try {
        Import-Module PowerShell-Yaml -ErrorAction Stop
    }
    catch {
        throw "PowerShell-Yaml module (RequiredVersion 0.4.7) is required by AdrConsistency.psm1. Install via: Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7 -Scope CurrentUser. Inner error: $($_.Exception.Message)"
    }
}

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'AdrBodyParser.psm1') -Force

$script:RuleRegistryPath = Join-Path -Path $PSScriptRoot -ChildPath '../rules/adr-consistency-rules.json'
$script:RuleRegistry = @{}
try {
    $registryRaw = Get-Content -Path $script:RuleRegistryPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    foreach ($rule in $registryRaw.rules) {
        $script:RuleRegistry[$rule.id] = $rule
    }
}
catch {
    throw "Failed to load ADR consistency rule registry from $($script:RuleRegistryPath): $($_.Exception.Message)"
}

$script:CanonicalPlanners = @('Security Planner', 'RAI Planner', 'SSSC Planner', 'ADR Planner')
$script:UpstreamLabels = @('BRD', 'PRD', 'RPI')

#endregion Module setup

#region Helpers

function Resolve-AdrTitleCase {
    <#
    .SYNOPSIS
        Returns the input text with each word's first letter capitalized.
    .DESCRIPTION
        Normalizes case-insensitive regex captures to a stable form before
        comparing against the canonical peer-planner set.
    .PARAMETER Text
        Input text.
    .OUTPUTS
        [string] Title-cased string in the invariant culture.
    .EXAMPLE
        Resolve-AdrTitleCase -Text 'security planner'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    return $culture.TextInfo.ToTitleCase($Text.ToLowerInvariant())
}

function Get-AdrFrontmatterAndBody {
    <#
    .SYNOPSIS
        Splits ADR markdown into YAML frontmatter and body text.
    .DESCRIPTION
        Detects a leading '---' fenced YAML block and parses it via
        ConvertFrom-Yaml. Returns the parsed frontmatter (or $null on parse
        failure) alongside the remaining body markdown.
    .PARAMETER Content
        Raw ADR file content.
    .OUTPUTS
        [pscustomobject] with Frontmatter (parsed object or $null), Body (string),
        and BodyStartLine (1-based file line where the body begins).
    .EXAMPLE
        Get-AdrFrontmatterAndBody -Content (Get-Content adr.md -Raw)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $frontmatter = $null
    $body = $Content
    $bodyStartLine = 1
    if ($Content -match '(?s)^---\s*\r?\n(.*?)\r?\n---\r?\n?(.*)$') {
        $yamlBlock = $Matches[1]
        $body = $Matches[2]
        $preambleLength = $Content.Length - $body.Length
        if ($preambleLength -gt 0) {
            $preamble = $Content.Substring(0, $preambleLength)
            $bodyStartLine = ([regex]::Matches($preamble, "`n")).Count + 1
        }
        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $yamlBlock
        }
        catch {
            $frontmatter = $null
        }
    }

    return [pscustomobject]@{
        Frontmatter   = $frontmatter
        Body          = $body
        BodyStartLine = $bodyStartLine
    }
}

function Get-AdrFileLine {
    <#
    .SYNOPSIS
        Maps a character offset within body text to a 1-based file line number.
    .PARAMETER Text
        Body text the offset refers to.
    .PARAMETER Offset
        Zero-based character offset within Text.
    .PARAMETER BodyStartLine
        1-based file line where Text begins.
    .OUTPUTS
        [object] File line number, or $null when Offset is out of range.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$Text,
        [Parameter(Mandatory = $true)] [int]$Offset,
        [int]$BodyStartLine = 1
    )

    if ($Offset -lt 0 -or $Offset -gt $Text.Length) { return $null }
    $prefix = $Text.Substring(0, $Offset)
    return $BodyStartLine + ([regex]::Matches($prefix, "`n")).Count
}

function Find-AdrTextLine {
    <#
    .SYNOPSIS
        Resolves the file line of the first case-insensitive occurrence of a string.
    .PARAMETER RawBody
        Raw ADR body markdown.
    .PARAMETER Search
        Literal text to locate.
    .PARAMETER BodyStartLine
        1-based file line where RawBody begins.
    .OUTPUTS
        [object] File line number, or $null when not found.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$RawBody,
        [string]$Search,
        [int]$BodyStartLine = 1
    )

    if ([string]::IsNullOrEmpty($Search)) { return $null }
    $index = $RawBody.IndexOf($Search, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return $null }
    return Get-AdrFileLine -Text $RawBody -Offset $index -BodyStartLine $BodyStartLine
}

function Find-AdrHeadingLine {
    <#
    .SYNOPSIS
        Resolves the file line of an H2 or H3 heading by its text.
    .PARAMETER RawBody
        Raw ADR body markdown.
    .PARAMETER Heading
        Heading text without leading '#' markers.
    .PARAMETER BodyStartLine
        1-based file line where RawBody begins.
    .OUTPUTS
        [object] File line number, or $null when the heading is absent.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string]$RawBody,
        [Parameter(Mandatory = $true)] [string]$Heading,
        [int]$BodyStartLine = 1
    )

    $escaped = [regex]::Escape($Heading)
    $match = [regex]::Match($RawBody, '(?im)^\s*#{2,3}\s+' + $escaped + '\s*$')
    if (-not $match.Success) { return $null }
    return Get-AdrFileLine -Text $RawBody -Offset $match.Index -BodyStartLine $BodyStartLine
}

function Get-AdrRawH2Section {
    <#
    .SYNOPSIS
        Returns the raw text of an H2 section located by heading text.
    .DESCRIPTION
        Locates an H2 heading by exact text and returns the section body up
        to the next H2 heading or end of input.
    .PARAMETER Body
        ADR body markdown.
    .PARAMETER Heading
        Plain heading text without the '## ' prefix.
    .OUTPUTS
        [string] Section text or empty string when missing.
    .EXAMPLE
        Get-AdrRawH2Section -Body $body -Heading 'More Information'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [string]$Heading
    )

    $escaped = [regex]::Escape($Heading)
    $pattern = '(?ims)^\s*##\s+' + $escaped + '\s*$(.*?)(?=^\s*##\s+\S|\z)'
    if ($Body -match $pattern) {
        return $Matches[1]
    }
    return ''
}

function Get-AdrDescriptionText {
    <#
    .SYNOPSIS
        Returns the body text preceding the first H2 section.
    .DESCRIPTION
        Captures the description prologue between the title and the first H2
        heading. Returns the full body when no H2 heading is present.
    .PARAMETER Body
        ADR body markdown.
    .OUTPUTS
        [string] Description prologue text.
    .EXAMPLE
        Get-AdrDescriptionText -Body $rawBody
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Body
    )

    if ($Body -match '(?sm)\A(.*?)(?=^\s*##\s+\S)') {
        return $Matches[1]
    }
    return $Body
}

function Format-AdrList {
    <#
    .SYNOPSIS
        Formats a string array as a single-quoted, comma-separated list.
    .DESCRIPTION
        Renders lists for inclusion in violation messages. Returns '(none)'
        for null or empty input.
    .PARAMETER Items
        String items to format.
    .OUTPUTS
        [string] Formatted list.
    .EXAMPLE
        Format-AdrList -Items @('foo', 'bar')
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string[]]$Items
    )

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return '(none)'
    }
    return ($Items | ForEach-Object { "'$_'" }) -join ', '
}

function New-AdrViolation {
    <#
    .SYNOPSIS
        Builds a violation object for a registered ADR consistency rule.
    .DESCRIPTION
        Looks up the rule from the in-memory registry, applies replacement
        tokens to the message template, and returns a structured record.
    .PARAMETER RuleId
        Stable rule identifier (ADR-CONSISTENCY-NNN).
    .PARAMETER FilePath
        ADR file the violation applies to.
    .PARAMETER Replacements
        Hashtable of token names to substitution values.
    .PARAMETER Line
        Optional line number associated with the violation.
    .OUTPUTS
        [pscustomobject] Violation record with file, ruleId, severity, message, line.
    .EXAMPLE
        New-AdrViolation -RuleId 'ADR-CONSISTENCY-001' -FilePath $path -Replacements @{ frontmatter_only = '...' }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleId,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [hashtable]$Replacements = @{},

        [Parameter(Mandatory = $false)]
        [Nullable[int]]$Line
    )

    $rule = $script:RuleRegistry[$RuleId]
    if (-not $rule) {
        throw "Unknown rule id: $RuleId"
    }

    $message = $rule.message
    foreach ($key in $Replacements.Keys) {
        $token = '{' + $key + '}'
        $message = $message.Replace($token, [string]$Replacements[$key])
    }

    return [pscustomobject]@{
        file     = $FilePath
        ruleId   = $RuleId
        severity = $rule.severity
        message  = $message
        line     = $Line
    }
}

function ConvertTo-AdrNormalizedText {
    <#
    .SYNOPSIS
        Normalizes text for set-equality comparisons.
    .DESCRIPTION
        Trims, lowercases, collapses internal whitespace, and strips trailing
        sentence punctuation so equivalent items compare equal.
    .PARAMETER Text
        Input text.
    .OUTPUTS
        [string] Normalized form, or empty string for null/whitespace input.
    .EXAMPLE
        ConvertTo-AdrNormalizedText -Text '  Foo Bar.  '
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $normalized = $Text.Trim().ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '\s+', ' ')
    $normalized = $normalized.TrimEnd('.', '!', '?', ',', ';', ':')
    return $normalized
}

#endregion Helpers

#region Rule checks

function Test-AffectedComponentsMirror {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-001: frontmatter and body Affected Components must agree.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object from Get-AdrBodySections.
    .PARAMETER FilePath
        ADR file path used in violations.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    $fmList = @()
    if ($Frontmatter -and $Frontmatter.affected_components) {
        $fmList = @($Frontmatter.affected_components | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ })
    }
    $bodyList = @($Body.AffectedComponents | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ })

    $fmOnly = @($fmList | Where-Object { $_ -and $bodyList -notcontains $_ })
    $bodyOnly = @($bodyList | Where-Object { $_ -and $fmList -notcontains $_ })

    if ($fmOnly.Count -eq 0 -and $bodyOnly.Count -eq 0) { return @() }

    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-001' -FilePath $FilePath -Replacements @{
            frontmatter_only = Format-AdrList -Items $fmOnly
            body_only        = Format-AdrList -Items $bodyOnly
        })
}

function Test-SuccessCriteriaSourceResolves {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-002: success_criteria[].source paths must resolve inside the repo.
    .DESCRIPTION
        Joins each path-shaped source against RepoRoot, normalizes the absolute
        path, and verifies the resolved location both exists and falls inside
        the repository tree. Paths that escape the repo via '..' segments or
        absolute references outside RepoRoot raise the same violation as
        missing files.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .PARAMETER RepoRoot
        Repository root used as the resolution base and containment boundary.
    .OUTPUTS
        [object[]] Zero or more violation records.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$RepoRoot
    )

    $violations = @()
    if (-not $Frontmatter -or -not $Frontmatter.success_criteria) { return $violations }

    $pathPattern = '^[A-Za-z0-9_\-./]+/[A-Za-z0-9_\-./]+\.[A-Za-z0-9]{1,8}$'
    $repoRootAbsolute = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $boundary = $repoRootAbsolute + [System.IO.Path]::DirectorySeparatorChar

    $criteria = @($Frontmatter.success_criteria)
    for ($i = 0; $i -lt $criteria.Count; $i++) {
        $entry = $criteria[$i]
        if (-not $entry) { continue }
        $source = $null
        if ($entry -is [System.Collections.IDictionary]) {
            $source = $entry['source']
        }
        elseif ($entry.PSObject.Properties['source']) {
            $source = $entry.source
        }
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($source -notmatch $pathPattern) { continue }

        $joined = Join-Path -Path $RepoRoot -ChildPath $source
        $resolvedAbsolute = $null
        try {
            $resolvedAbsolute = [System.IO.Path]::GetFullPath($joined)
        }
        catch {
            $resolvedAbsolute = $null
        }

        $insideRepo = $resolvedAbsolute -and (
            $resolvedAbsolute -eq $repoRootAbsolute -or
            $resolvedAbsolute.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)
        )

        if (-not $insideRepo -or -not (Test-Path -LiteralPath $resolvedAbsolute)) {
            $violations += New-AdrViolation -RuleId 'ADR-CONSISTENCY-002' -FilePath $FilePath -Replacements @{
                index  = $i
                source = $source
            }
        }
    }
    return $violations
}

function Test-StatePlaceholderResolved {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-003: unresolved {{state.*}} or pipe-separated enum placeholders.
    .DESCRIPTION
        Flags '{{state.<path>}}' tokens left in the body and any 'autonomyTier:'
        line whose value is still a pipe-separated word list (for example
        'autonomyTier: full|partial|manual' or 'autonomyTier: auto|semi'),
        which indicates an unresolved enum placeholder.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .PARAMETER RawBody
        Raw ADR body markdown.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$RawBody,
        [int]$BodyStartLine = 1
    )

    $tokens = @()
    $stateMatches = [regex]::Matches($RawBody, '\{\{state\.[^}]+\}\}')
    foreach ($m in $stateMatches) { $tokens += $m.Value }

    # Catches any unresolved enum-style placeholder after autonomyTier:
    $autonomyMatches = [regex]::Matches($RawBody, 'autonomyTier:\s*[A-Za-z]+\|[A-Za-z]+(\|[A-Za-z]+)*')
    foreach ($m in $autonomyMatches) { $tokens += $m.Value }

    if ($tokens.Count -eq 0) { return @() }

    $offset = -1
    if ($stateMatches.Count -gt 0) { $offset = $stateMatches[0].Index }
    if ($autonomyMatches.Count -gt 0 -and ($offset -lt 0 -or $autonomyMatches[0].Index -lt $offset)) {
        $offset = $autonomyMatches[0].Index
    }
    $line = if ($offset -ge 0) { Get-AdrFileLine -Text $RawBody -Offset $offset -BodyStartLine $BodyStartLine } else { $null }

    $unique = @($tokens | Select-Object -Unique)
    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-003' -FilePath $FilePath -Line $line -Replacements @{
            tokens = Format-AdrList -Items $unique
        })
}

function Test-PeerPlannerNames {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-004: only canonical peer-planner labels in description and drivers.
    .DESCRIPTION
        Strips fenced code blocks and inline code spans from the description
        prologue and Decision Drivers, then scans case-insensitively for
        '<word> Planner' labels. Matches whose word is BRD, PRD, or RPI are
        normalized to uppercase and surfaced as upstream-artifact misuses;
        all other matches are title-cased and compared against
        $script:CanonicalPlanners.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .PARAMETER RawBody
        Raw ADR body markdown.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$RawBody,
        [int]$BodyStartLine = 1
    )

    $description = Get-AdrDescriptionText -Body $RawBody
    $driversText = ($Body.DecisionDrivers -join "`n")
    $scanText = "$description`n$driversText"
    $scanText = Remove-AdrFencedCodeBlocks -Text $scanText

    $found = New-Object System.Collections.Generic.List[string]

    foreach ($m in [regex]::Matches($scanText, '(?i)\b([A-Za-z]+)\s+Planner\b')) {
        $rawWord = $m.Groups[1].Value
        if ($script:UpstreamLabels -contains $rawWord.ToUpperInvariant()) { continue }
        $normalized = Resolve-AdrTitleCase -Text "$rawWord Planner"
        if ($script:CanonicalPlanners -notcontains $normalized) {
            $null = $found.Add($normalized)
        }
    }
    foreach ($m in [regex]::Matches($scanText, '(?i)\b(BRD|PRD|RPI)\s+Planner\b')) {
        $null = $found.Add(($m.Groups[1].Value.ToUpperInvariant() + ' Planner'))
    }

    if ($found.Count -eq 0) { return @() }

    $unique = @($found | Select-Object -Unique)
    $line = Find-AdrTextLine -RawBody $RawBody -Search $unique[0] -BodyStartLine $BodyStartLine
    if ($null -eq $line) {
        $line = Find-AdrHeadingLine -RawBody $RawBody -Heading 'Decision Drivers' -BodyStartLine $BodyStartLine
    }
    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-004' -FilePath $FilePath -Line $line -Replacements @{
            labels = Format-AdrList -Items $unique
        })
}

function Test-DriversMatrixCardinality {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-005: Decision Drivers and Decision Outcome matrix must be 1:1.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    $drivers = @($Body.DecisionDrivers | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ } | Where-Object { $_ })
    $matrix = @($Body.DecisionOutcomeMatrixDrivers | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ } | Where-Object { $_ })

    $driversOnly = @($drivers | Where-Object { $matrix -notcontains $_ })
    $matrixOnly = @($matrix | Where-Object { $drivers -notcontains $_ })

    if ($driversOnly.Count -eq 0 -and $matrixOnly.Count -eq 0) { return @() }

    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-005' -FilePath $FilePath -Replacements @{
            drivers_only = Format-AdrList -Items $driversOnly
            matrix_only  = Format-AdrList -Items $matrixOnly
        })
}

function Test-RisksConsequencesPairing {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-006: risk-shaped Bad consequences must be paired in Risks and Mitigations.
    .DESCRIPTION
        A bullet is treated as risk-shaped only when it begins with 'risk:'
        or contains the word 'risk' alongside a probability/uncertainty modal
        (may, could, might, likely, possible, possibility). Each risk-shaped
        bullet is then matched (substring or equality) against the Risks and
        Mitigations table.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string]$RawBody = '',
        [int]$BodyStartLine = 1
    )

    $bad = @($Body.BadConsequences)
    if ($bad.Count -eq 0) { return @() }

    $riskShaped = @($bad | Where-Object {
            $_ -match '(?i)^\s*risk\s*:' -or
            ($_ -match '(?i)\brisk\b' -and $_ -match '(?i)\b(may|could|might|likely|possible|possibility)\b')
        })
    if ($riskShaped.Count -eq 0) { return @() }

    $risks = @($Body.RisksAndMitigationsRisks | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ } | Where-Object { $_ })
    $unpaired = @()
    foreach ($entry in $riskShaped) {
        $needle = ConvertTo-AdrNormalizedText -Text ($entry -replace '(?i)^\s*risk\s*:\s*', '')
        if ([string]::IsNullOrEmpty($needle)) { continue }
        $paired = $false
        foreach ($r in $risks) {
            if ($r -eq $needle -or $r.Contains($needle) -or $needle.Contains($r)) {
                $paired = $true
                break
            }
        }
        if (-not $paired) { $unpaired += $entry }
    }

    if ($unpaired.Count -eq 0) { return @() }

    $line = $null
    if (-not [string]::IsNullOrEmpty($RawBody)) {
        $line = Find-AdrTextLine -RawBody $RawBody -Search $unpaired[0] -BodyStartLine $BodyStartLine
        if ($null -eq $line) {
            $line = Find-AdrHeadingLine -RawBody $RawBody -Heading 'Consequences' -BodyStartLine $BodyStartLine
        }
    }
    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-006' -FilePath $FilePath -Line $line -Replacements @{
            unpaired = Format-AdrList -Items $unpaired
        })
}

function Test-NumericClaimGeneralized {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-007: warn on unverified numeric claims in narrative sections.
    .DESCRIPTION
        Strips fenced code blocks and inline code spans from each scanned
        section before searching for '<number> <unit>' patterns. Sections
        inspected are Confirmation, Bad Consequences, and More Information.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .PARAMETER RawBody
        Raw ADR body markdown.
    .OUTPUTS
        [object[]] Zero or more violation records (one per matched claim).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string]$RawBody,
        [int]$BodyStartLine = 1
    )

    # Negative lookbehind skips version strings (e.g. 'v7.0', 'Version 7.0', '-Version 7.0')
    # so directives like '#Requires -Version 7.0' are not flagged as unverified numeric claims.
    $pattern = '(?<!(?i:v|ver\.?\s*|version\s*|-version\s*))\b(\d+(?:\.\d+)?)\s*(tests?|specs?|cases?|files?|lines?|hours?|days?|minutes?|seconds?|ms|users?|requests?|MB|GB|KB|%)\b'

    $sections = @(
        @{ Name = 'Confirmation'; Text = ($Body.Confirmation) },
        @{ Name = 'Consequences'; Text = (($Body.BadConsequences) -join "`n") },
        @{ Name = 'More Information'; Text = (Get-AdrRawH2Section -Body $RawBody -Heading 'More Information') }
    )

    $violations = @()
    foreach ($section in $sections) {
        $text = $section.Text
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $text = Remove-AdrFencedCodeBlocks -Text $text
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        foreach ($m in [regex]::Matches($text, $pattern)) {
            $claim = $m.Value
            $line = Find-AdrTextLine -RawBody $RawBody -Search $claim -BodyStartLine $BodyStartLine
            $violations += New-AdrViolation -RuleId 'ADR-CONSISTENCY-007' -FilePath $FilePath -Line $line -Replacements @{
                claim   = $claim
                section = $section.Name
            }
        }
    }
    return $violations
}

function Test-DriverTriggerMapComplete {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-008: every Decision Driver must key into driverToTriggerMap.
    .PARAMETER Frontmatter
        Parsed frontmatter object containing decisionMetadata.driverToTriggerMap.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    $drivers = @($Body.DecisionDrivers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($drivers.Count -eq 0) { return @() }

    $mapKeys = @()
    if ($Frontmatter -and $Frontmatter.decisionMetadata) {
        $dm = $Frontmatter.decisionMetadata
        $map = $null
        if ($dm -is [System.Collections.IDictionary]) {
            $map = $dm['driverToTriggerMap']
        }
        elseif ($dm.PSObject.Properties['driverToTriggerMap']) {
            $map = $dm.driverToTriggerMap
        }
        if ($map) {
            if ($map -is [System.Collections.IDictionary]) {
                $mapKeys = @($map.Keys | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ })
            }
            else {
                $mapKeys = @($map.PSObject.Properties.Name | ForEach-Object { ConvertTo-AdrNormalizedText -Text $_ })
            }
        }
    }

    $missing = @()
    foreach ($d in $drivers) {
        $needle = ConvertTo-AdrNormalizedText -Text $d
        $found = $false
        foreach ($k in $mapKeys) {
            if ($k -eq $needle -or $k.Contains($needle) -or $needle.Contains($k)) {
                $found = $true
                break
            }
        }
        if (-not $found) { $missing += $d }
    }

    if ($missing.Count -eq 0) { return @() }

    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-008' -FilePath $FilePath -Replacements @{
            missing = Format-AdrList -Items $missing
        })
}

function Test-AffectedComponentsCited {
    <#
    .SYNOPSIS
        ADR-CONSISTENCY-009: every affected_components entry must be cited in body.
    .DESCRIPTION
        Compares the frontmatter affected_components list against path tokens
        extracted from Context and More Information sections, treating filename
        equality and trailing-segment matches as citations.
    .PARAMETER Frontmatter
        Parsed frontmatter object.
    .PARAMETER Body
        Parsed body sections object.
    .PARAMETER FilePath
        ADR file path used in violations.
    .OUTPUTS
        [object[]] Zero or one violation record.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)] $Frontmatter,
        [Parameter(Mandatory = $true)] $Body,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    if (-not $Frontmatter -or -not $Frontmatter.affected_components) { return @() }
    $fmList = @($Frontmatter.affected_components | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($fmList.Count -eq 0) { return @() }

    $citationTokens = @()
    $citationTokens += @($Body.ContextPathTokens)
    $citationTokens += @($Body.MoreInformationPathTokens)
    $citationTokens = @($citationTokens | Where-Object { $_ })

    $uncited = @()
    foreach ($entry in $fmList) {
        $entryNorm = $entry.Trim()
        $base = [System.IO.Path]::GetFileName($entryNorm)
        $cited = $false
        foreach ($tok in $citationTokens) {
            if ($tok -eq $entryNorm -or $tok.EndsWith('/' + $entryNorm) -or [System.IO.Path]::GetFileName($tok) -eq $base) {
                $cited = $true
                break
            }
        }
        if (-not $cited) { $uncited += $entry }
    }

    if ($uncited.Count -eq 0) { return @() }

    return @(New-AdrViolation -RuleId 'ADR-CONSISTENCY-009' -FilePath $FilePath -Replacements @{
            uncited = Format-AdrList -Items $uncited
        })
}

#endregion Rule checks

#region Entry function

function Invoke-AdrConsistencyValidation {
    <#
    .SYNOPSIS
        Runs every ADR consistency rule against a single ADR markdown file.
    .DESCRIPTION
        Reads the ADR, splits frontmatter from body, parses body sections via
        AdrBodyParser, dispatches all Test-* rule functions, and returns the
        aggregated violations.
    .PARAMETER Path
        Absolute or repo-relative path to the ADR markdown file.
    .PARAMETER RepoRoot
        Repository root used as the path-resolution and containment boundary
        for path-shaped sources.
    .OUTPUTS
        [pscustomobject] with File and Violations properties.
    .EXAMPLE
        Invoke-AdrConsistencyValidation -Path docs/planning/adrs/0001.md -RepoRoot $repoRoot
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "ADR file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $split = Get-AdrFrontmatterAndBody -Content $content
    $body = Get-AdrBodySections -Text $split.Body
    $rawBody = $split.Body

    $violations = @()
    $violations += Test-AffectedComponentsMirror -Frontmatter $split.Frontmatter -Body $body -FilePath $Path
    $violations += Test-SuccessCriteriaSourceResolves -Frontmatter $split.Frontmatter -Body $body -FilePath $Path -RepoRoot $RepoRoot
    $violations += Test-StatePlaceholderResolved -Frontmatter $split.Frontmatter -Body $body -FilePath $Path -RawBody $rawBody -BodyStartLine $split.BodyStartLine
    $violations += Test-PeerPlannerNames -Frontmatter $split.Frontmatter -Body $body -FilePath $Path -RawBody $rawBody -BodyStartLine $split.BodyStartLine
    $violations += Test-DriversMatrixCardinality -Frontmatter $split.Frontmatter -Body $body -FilePath $Path
    $violations += Test-RisksConsequencesPairing -Frontmatter $split.Frontmatter -Body $body -FilePath $Path -RawBody $rawBody -BodyStartLine $split.BodyStartLine
    $violations += Test-NumericClaimGeneralized -Frontmatter $split.Frontmatter -Body $body -FilePath $Path -RawBody $rawBody -BodyStartLine $split.BodyStartLine
    $violations += Test-DriverTriggerMapComplete -Frontmatter $split.Frontmatter -Body $body -FilePath $Path
    $violations += Test-AffectedComponentsCited -Frontmatter $split.Frontmatter -Body $body -FilePath $Path

    return [pscustomobject]@{
        File       = $Path
        Violations = @($violations)
    }
}

#endregion Entry function

Export-ModuleMember -Function @('Invoke-AdrConsistencyValidation')
