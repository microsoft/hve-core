# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Get-AgentActivationFingerprint.psm1
#
# Purpose: Compute deterministic activation fingerprint (byte counts + SHA256)
#          for a custom agent file across canonical activation scenarios.
#          Used by the activation-harness Pester suite to assert cold-start
#          byte budgets and dispatch-table loading behavior for the ADR
#          Creator agent (and any future agent reusing this contract).
# Author:  HVE Core Team

#Requires -Version 7.4

#region Internal Helpers

<#
.SYNOPSIS
    Resolves a `#file:` directive's relative path to an absolute path.

.DESCRIPTION
    `#file:` directives in agent or instruction bodies use paths relative to
    the file containing the directive. This helper normalizes the reference
    against the source file's parent directory and returns the absolute path
    when it exists on disk.

.PARAMETER Reference
    The raw reference text captured from the `#file:` directive
    (e.g. `../../instructions/project-planning/adr-identity.instructions.md`).

.PARAMETER SourcePath
    Absolute path of the file that contained the directive.

.OUTPUTS
    [string] Absolute path to the referenced file, or $null when it does not
    resolve to an existing file.
#>
function Resolve-FileReferencePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Reference,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath
    )

    $sourceDir = Split-Path -Parent $SourcePath
    $combined = Join-Path -Path $sourceDir -ChildPath $Reference
    try {
        $resolved = (Resolve-Path -LiteralPath $combined -ErrorAction Stop).Path
    } catch {
        return $null
    }

    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        return $resolved
    }
    return $null
}

<#
.SYNOPSIS
    Extracts every `#file:` directive payload from a string body.

.DESCRIPTION
    Returns the relative-path text following each `#file:` token. Strips a
    trailing punctuation character (`.`, `,`, `;`, `:`, `)`, `]`, `>`) so
    references embedded in prose ("see #file:foo.md.") do not inherit the
    closing punctuation.

.PARAMETER Body
    The text to scan.

.OUTPUTS
    [string[]] Distinct, order-preserved relative paths.
#>
function Get-FileDirectiveReferences {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body
    )

    $regexMatches = [regex]::Matches($Body, '#file:([^\s\)\]\>]+)')
    $result = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $regexMatches) {
        $ref = $m.Groups[1].Value.TrimEnd('.', ',', ';', ':')
        if ($seen.Add($ref)) {
            [void]$result.Add($ref)
        }
    }
    return $result.ToArray()
}

<#
.SYNOPSIS
    Extracts every `read_file`-style dispatch reference from a string body.

.DESCRIPTION
    The ADR Creator agent body's Lifecycle Dispatch Tables cite on-demand
    reads using the literal pattern `` `read_file` `<repo-relative-path>` ``.
    This helper captures each backtick-quoted path that immediately follows
    a `` `read_file` `` token, strips any trailing `#anchor` fragment so a
    SKILL.md anchor (e.g. `SKILL.md#frame`) resolves to the underlying file,
    and returns distinct, order-preserved paths. Unlike `#file:` directives,
    these paths are repo-root-relative.

.PARAMETER Body
    The text to scan.

.OUTPUTS
    [string[]] Distinct, order-preserved repo-relative paths.
#>
function Get-ReadFileReferences {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body
    )

    $regexMatches = [regex]::Matches($Body, '`read_file`\s+`([^`]+)`')
    $result = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $regexMatches) {
        $ref = $m.Groups[1].Value
        $hashIdx = $ref.IndexOf('#')
        if ($hashIdx -ge 0) { $ref = $ref.Substring(0, $hashIdx) }
        $ref = $ref.Trim()
        if ($ref -and $seen.Add($ref)) {
            [void]$result.Add($ref)
        }
    }
    return $result.ToArray()
}

<#
.SYNOPSIS
    Splits an agent file's text into frontmatter and body.

.PARAMETER Content
    Full agent file text.

.OUTPUTS
    [hashtable] @{ Frontmatter = <string>; Body = <string> }. Frontmatter is
    empty when no `---` delimited block is present at the top of the file.
#>
function Split-AgentContent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    if ($Content -match '(?s)\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z') {
        return @{ Frontmatter = $Matches[1]; Body = $Matches[2] }
    }
    return @{ Frontmatter = ''; Body = $Content }
}

<#
.SYNOPSIS
    Reads frontmatter `applyTo` globs as a string array.

.PARAMETER Frontmatter
    Frontmatter YAML text (without surrounding `---` lines).

.OUTPUTS
    [string[]] Glob patterns parsed from the `applyTo:` line. Empty array
    when the field is absent.
#>
function Get-ApplyToGlobs {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Frontmatter
    )

    if ($Frontmatter -match "(?m)^applyTo:\s*['""]?([^'""\r\n]+)['""]?\s*$") {
        return ($Matches[1] -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    return @()
}

<#
.SYNOPSIS
    Discovers instruction files whose `applyTo` would auto-attach inside the
    `.copilot-tracking/adr-plans/` working directory.

.DESCRIPTION
    Scans `.github/instructions/**/*.instructions.md` under the repository
    root, parses each file's frontmatter `applyTo`, and returns the paths
    whose globs include any of the canonical ADR working-directory tokens
    (`adr-plans` or `docs/planning/adrs`).

.PARAMETER RepoRoot
    Absolute path to the repository root.

.OUTPUTS
    [string[]] Sorted, distinct absolute paths.
#>
function Get-AdrApplyToInstructions {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $instructionsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/instructions'
    if (-not (Test-Path -LiteralPath $instructionsRoot)) {
        return @()
    }

    $tokens = @('adr-plans', 'docs/planning/adrs')
    $matched = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -LiteralPath $instructionsRoot -Recurse -Filter '*.instructions.md' -File |
        ForEach-Object {
            $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
            $split = Split-AgentContent -Content $text
            $globs = Get-ApplyToGlobs -Frontmatter $split.Frontmatter
            foreach ($g in $globs) {
                foreach ($t in $tokens) {
                    if ($g -like "*$t*") {
                        [void]$matched.Add($_.FullName)
                        break
                    }
                }
            }
        }

    return ($matched | Sort-Object -Unique)
}

<#
.SYNOPSIS
    Extracts file paths cited inside the agent body's Lifecycle Dispatch
    Tables (Table A and Table B) for a given lifecycle phase token.

.DESCRIPTION
    The ADR Creator agent body uses two markdown tables — Table A (lifecycle
    phases: Frame / Decide / Govern) and Table B (adopt-template steps:
    Ingest / Normalize / Derive Questions / Fill / Govern). Cells contain
    `#file:`-style references to the on-demand reads required by that phase
    or step. This helper returns the set of references whose row label
    matches the supplied `PhaseToken` (case-insensitive substring match).

.PARAMETER Body
    Agent body text.

.PARAMETER PhaseToken
    Token to match against the leading column of a table row (e.g. 'Govern',
    'Ingest').

.OUTPUTS
    [string[]] Distinct relative-path references from matching rows.
#>
function Get-DispatchTableReferences {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhaseToken
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $rowPattern = '(?im)^\|\s*[^|]*' + [regex]::Escape($PhaseToken) + '[^|]*\|.*$'
    foreach ($row in [regex]::Matches($Body, $rowPattern)) {
        foreach ($ref in (Get-FileDirectiveReferences -Body $row.Value)) {
            if ($seen.Add($ref)) {
                [void]$result.Add($ref)
            }
        }
        foreach ($ref in (Get-ReadFileReferences -Body $row.Value)) {
            if ($seen.Add($ref)) {
                [void]$result.Add($ref)
            }
        }
        foreach ($m in [regex]::Matches($row.Value, '`([^`]+\.(?:md|py|ps1|psm1|psd1|json|ya?ml|sh|js|ts|txt))(?:#[^`]*)?`')) {
            $ref = $m.Groups[1].Value.Trim()
            if ($ref -and $ref.Contains('/') -and $seen.Add($ref)) {
                [void]$result.Add($ref)
            }
        }
    }
    return $result.ToArray()
}

<#
.SYNOPSIS
    Returns the UTF-8 byte count of a file with line endings normalized to LF.

.DESCRIPTION
    Reads the file as UTF-8 text, strips a leading BOM if present, normalizes
    CRLF to LF, and returns the resulting UTF-8 byte length. Ensures the
    activation fingerprint is identical across Windows (CRLF working trees)
    and Linux/macOS CI runners (LF working trees).
#>
function Get-NormalizedFileByteCount {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    $normalized = $text -replace "`r`n", "`n"
    return [int][System.Text.Encoding]::UTF8.GetByteCount($normalized)
}

#endregion

#region Public Surface

<#
.SYNOPSIS
    Computes a deterministic activation fingerprint for a custom agent file.

.DESCRIPTION
    Models four canonical activation scenarios for VS Code Copilot custom
    agents and returns the bytes that would be loaded into context plus a
    SHA256 hash of the deterministic file-path / byte-count tuple.

    Scenarios:
      * CleanWorkspace - cold start: agent file plus every `#file:` directive
        in the agent body. Models the case where no open editor file matches
        any `applyTo` glob.
      * SteadyState    - working inside `.copilot-tracking/adr-plans/`:
        CleanWorkspace plus every instruction file whose frontmatter
        `applyTo` glob covers the ADR working directories.
      * GovernEntry    - SteadyState plus references in Lifecycle Dispatch
        Table rows tagged 'Govern'.
      * AdoptTemplate  - SteadyState plus references in Lifecycle Dispatch
        Table rows tagged 'Ingest', 'Normalize', 'Derive', or 'Fill'
        (the adopt-template Table B steps).

    The returned hashtable is JSON-serializable and feeds the harness
    baseline file at scripts/agents/activation-harness/baseline.json.

.PARAMETER AgentPath
    Absolute or repo-relative path to the agent .agent.md file.

.PARAMETER ScenarioName
    One of CleanWorkspace, SteadyState, GovernEntry, AdoptTemplate.

.PARAMETER RepoRoot
    Optional absolute path to the repository root. When omitted, resolves
    three levels above this module file.

.OUTPUTS
    [hashtable] @{
        ScenarioName   = <string>
        AgentBytes     = <int>
        ColdStartBytes = <int>          # total bytes for the scenario
        LoadedFiles    = @(@{Path=<repo-relative>; Bytes=<int>})
        Hash           = <string>        # lowercase hex SHA256
    }

.EXAMPLE
    Import-Module ./Get-AgentActivationFingerprint.psm1
    Get-AgentActivationFingerprint `
        -AgentPath '.github/agents/project-planning/adr-creation.agent.md' `
        -ScenarioName 'CleanWorkspace'
#>
function Get-AgentActivationFingerprint {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CleanWorkspace', 'SteadyState', 'GovernEntry', 'AdoptTemplate')]
        [string]$ScenarioName,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' '..')).Path
    } else {
        $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    }

    $agentFullPath = (Resolve-Path -LiteralPath $AgentPath).Path
    $agentBytes = Get-NormalizedFileByteCount -Path $agentFullPath
    $agentText = Get-Content -LiteralPath $agentFullPath -Raw -Encoding UTF8
    $split = Split-AgentContent -Content $agentText

    $loaded = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $loaded[$agentFullPath] = $agentBytes

    foreach ($ref in Get-FileDirectiveReferences -Body $split.Body) {
        $resolved = Resolve-FileReferencePath -Reference $ref -SourcePath $agentFullPath
        if ($resolved -and -not $loaded.ContainsKey($resolved)) {
            $loaded[$resolved] = Get-NormalizedFileByteCount -Path $resolved
        }
    }

    if ($ScenarioName -in @('SteadyState', 'GovernEntry', 'AdoptTemplate')) {
        foreach ($path in Get-AdrApplyToInstructions -RepoRoot $RepoRoot) {
            if (-not $loaded.ContainsKey($path)) {
                $loaded[$path] = Get-NormalizedFileByteCount -Path $path
            }
        }
    }

    if ($ScenarioName -eq 'GovernEntry') {
        foreach ($ref in Get-DispatchTableReferences -Body $split.Body -PhaseToken 'Govern') {
            $candidate = Join-Path -Path $RepoRoot -ChildPath $ref
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $resolved = (Resolve-Path -LiteralPath $candidate).Path
                if (-not $loaded.ContainsKey($resolved)) {
                    $loaded[$resolved] = Get-NormalizedFileByteCount -Path $resolved
                }
            }
        }
    }

    if ($ScenarioName -eq 'AdoptTemplate') {
        foreach ($token in @('Ingest', 'Normalize', 'Derive', 'Fill')) {
            foreach ($ref in Get-DispatchTableReferences -Body $split.Body -PhaseToken $token) {
                $candidate = Join-Path -Path $RepoRoot -ChildPath $ref
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $resolved = (Resolve-Path -LiteralPath $candidate).Path
                    if (-not $loaded.ContainsKey($resolved)) {
                        $loaded[$resolved] = Get-NormalizedFileByteCount -Path $resolved
                    }
                }
            }
        }
    }

    $orderedPaths = $loaded.Keys | Sort-Object
    $loadedFilesList = @(
        foreach ($abs in $orderedPaths) {
            $rel = $abs.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
            [ordered]@{ Path = $rel; Bytes = $loaded[$abs] }
        }
    )

    $coldStartBytes = ($loaded.Values | Measure-Object -Sum).Sum

    $hashInput = ($loadedFilesList | ForEach-Object { "$($_.Path):$($_.Bytes)" }) -join '|'
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
    } finally {
        $sha.Dispose()
    }
    $hash = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })

    return [ordered]@{
        ScenarioName   = $ScenarioName
        AgentBytes     = $agentBytes
        ColdStartBytes = [int]$coldStartBytes
        LoadedFiles    = $loadedFilesList
        Hash           = $hash
    }
}

#endregion

Export-ModuleMember -Function Get-AgentActivationFingerprint
