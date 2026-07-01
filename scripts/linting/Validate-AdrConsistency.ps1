#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Entry-point for ADR Planner Govern-phase consistency validation.
.DESCRIPTION
    Discovers ADR markdown files under the supplied paths, dispatches each file
    to the AdrConsistency module's rule registry, and emits a JSON report plus
    optional CI annotations and step summaries. Designed to fail the Govern exit
    gate when 'error'-severity rules trip, with optional escalation of warnings.
.PARAMETER Paths
    Repository-relative or absolute paths to scan recursively for *.md files.
    Ignored when -Files or -ChangedFilesOnly is specified.
.PARAMETER Files
    Explicit set of repository-relative or absolute markdown files to validate.
    Files outside the resolved repository root are skipped with a warning.
.PARAMETER ExcludePaths
    Wildcard patterns (forward-slash form, evaluated against repo-relative paths)
    that exclude matching files from the scan.
.PARAMETER WarningsAsErrors
    Treat 'warn'-severity violations as failures so the script exits non-zero
    when only warnings are present.
.PARAMETER ChangedFilesOnly
    Limit the scan to markdown files under -Paths changed against -BaseBranch
    (uses git diff).
.PARAMETER BaseBranch
    Branch reference used by -ChangedFilesOnly to compute the changed-file set.
.PARAMETER OutputPath
    File path where the JSON report is written. Parent directory is created if
    it does not exist.
.PARAMETER SarifOutputPath
    Optional file path where a SARIF 2.1.0 report is written. Parent directory
    is created if it does not exist.
.EXAMPLE
    pwsh ./scripts/linting/Validate-AdrConsistency.ps1
    Scans the default docs/planning/adrs/ tree and writes results to
    logs/adr-consistency-results.json.
.EXAMPLE
    pwsh ./scripts/linting/Validate-AdrConsistency.ps1 -ChangedFilesOnly -BaseBranch origin/main
    Validates only ADRs changed relative to origin/main.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('docs/planning/adrs/'),

    [Parameter(Mandatory = $false)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths = @(),

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/adr-consistency-results.json',

    [Parameter(Mandatory = $false)]
    [string]$SarifOutputPath = ''
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/AdrConsistency.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

function Get-AdrRepoRoot {
    <#
    .SYNOPSIS
        Resolves the repository root for ADR consistency validation.
    .DESCRIPTION
        Prefers `git rev-parse --show-toplevel` so non-default working trees are
        respected, and falls back to the script's parent directory when git is
        unavailable or the script lives outside a working tree.
    .OUTPUTS
        String absolute path to the repository root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $root = (& git rev-parse --show-toplevel 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $root) { return $root }
    }
    catch {
        Write-Verbose "git rev-parse failed: $($_.Exception.Message)"
    }
    return (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../..')).Path
}

function Resolve-AdrFiles {
    <#
    .SYNOPSIS
        Resolves the working set of ADR markdown files for validation.
    .DESCRIPTION
        Expands -ChangedFilesOnly, -Files, and -Paths into an absolute file list,
        rejects candidates that escape the resolved repository root via traversal
        or absolute paths outside the tree, and applies the -ExcludePaths wildcard
        filter.
    .OUTPUTS
        String[] absolute paths of markdown files inside the repository root.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string[]]$Paths,
        [string[]]$Files,
        [string[]]$ExcludePaths,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch,
        [string]$RepoRoot
    )

    $resolved = New-Object System.Collections.Generic.List[string]
    $repoRootAbsolute = [System.IO.Path]::GetFullPath($RepoRoot)
    $boundary = $repoRootAbsolute.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if ($ChangedFilesOnly) {
        $scanRoots = New-Object System.Collections.Generic.List[object]
        foreach ($path in $Paths) {
            $fullPath = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path -Path $RepoRoot -ChildPath $path }
            $absolutePath = [System.IO.Path]::GetFullPath($fullPath)
            if (-not $absolutePath.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Skipping path outside repository root: $path"
                continue
            }
            $normalizedRoot = $absolutePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            $null = $scanRoots.Add([pscustomobject]@{
                    Path     = $normalizedRoot
                    Boundary = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
                    IsFile   = [System.IO.Path]::GetExtension($normalizedRoot) -eq '.md'
                })
        }

        $changed = Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.md')
        foreach ($file in $changed) {
            $full = if ([System.IO.Path]::IsPathRooted($file)) { $file } else { Join-Path -Path $RepoRoot -ChildPath $file }
            $absolute = [System.IO.Path]::GetFullPath($full)
            if (-not $absolute.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Skipping path outside repository root: $file"
                continue
            }
            if ($scanRoots.Count -gt 0) {
                $included = $false
                foreach ($scanRoot in $scanRoots) {
                    if (($scanRoot.IsFile -and $absolute -eq $scanRoot.Path) -or
                        ((-not $scanRoot.IsFile) -and $absolute.StartsWith($scanRoot.Boundary, [System.StringComparison]::OrdinalIgnoreCase))) {
                        $included = $true
                        break
                    }
                }
                if (-not $included) { continue }
            }
            if (Test-Path -LiteralPath $full) { $null = $resolved.Add($full) }
        }
    }
    elseif ($Files) {
        foreach ($file in $Files) {
            $full = if ([System.IO.Path]::IsPathRooted($file)) { $file } else { Join-Path -Path $RepoRoot -ChildPath $file }
            $absolute = [System.IO.Path]::GetFullPath($full)
            if (-not $absolute.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Skipping path outside repository root: $file"
                continue
            }
            if (Test-Path -LiteralPath $full) { $null = $resolved.Add($full) }
        }
    }
    else {
        foreach ($p in $Paths) {
            $full = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path -Path $RepoRoot -ChildPath $p }
            $absolute = [System.IO.Path]::GetFullPath($full)
            if (-not $absolute.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Skipping path outside repository root: $p"
                continue
            }
            if (-not (Test-Path -LiteralPath $full)) { continue }
            if ((Get-Item -LiteralPath $full).PSIsContainer) {
                Get-ChildItem -LiteralPath $full -Recurse -Filter '*.md' -File |
                    ForEach-Object { $null = $resolved.Add($_.FullName) }
            }
            else {
                $null = $resolved.Add($full)
            }
        }
    }

    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($file in $resolved) {
        $rel = $file
        if ($file.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $file.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        }
        $excluded = $false
        foreach ($pattern in $ExcludePaths) {
            $normPattern = $pattern.Replace('\', '/')
            if ($rel -like $normPattern) { $excluded = $true; break }
        }
        if (-not $excluded) { $null = $filtered.Add($file) }
    }
    return , $filtered.ToArray()
}

function ConvertTo-AdrConsistencySarif {
    <#
    .SYNOPSIS
        Converts ADR consistency violations to SARIF 2.1.0.
    .DESCRIPTION
        Builds a SARIF payload compatible with GitHub code scanning upload by
        mapping ADR rule identifiers to SARIF rules and validator findings to
        SARIF results with file and line locations.
    .PARAMETER Violations
        ADR consistency violations produced by Invoke-AdrConsistencyValidator.
    .OUTPUTS
        Ordered hashtable representing a SARIF 2.1.0 document.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [pscustomobject[]]$Violations
    )

    $rulesById = [ordered]@{}
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($violation in $Violations) {
        $ruleId = if ($violation.ruleId) { [string]$violation.ruleId } else { 'ADR-CONSISTENCY' }
        if (-not $rulesById.Contains($ruleId)) {
            $rulesById[$ruleId] = [ordered]@{
                id               = $ruleId
                name             = $ruleId
                shortDescription = [ordered]@{
                    text = $ruleId
                }
            }
        }

        $level = 'note'
        if ($violation.severity -eq 'error') {
            $level = 'error'
        }
        elseif ($violation.severity -in @('warn', 'warning')) {
            $level = 'warning'
        }

        $line = 1
        if ($null -ne $violation.line) {
            $parsedLine = 0
            if ([int]::TryParse([string]$violation.line, [ref]$parsedLine) -and $parsedLine -gt 0) {
                $line = $parsedLine
            }
        }

        $null = $results.Add([ordered]@{
                ruleId    = $ruleId
                level     = $level
                message   = [ordered]@{
                    text = [string]$violation.message
                }
                locations = @(
                    [ordered]@{
                        physicalLocation = [ordered]@{
                            artifactLocation = [ordered]@{
                                uri = ([string]$violation.file).Replace('\', '/')
                            }
                            region           = [ordered]@{
                                startLine = $line
                            }
                        }
                    }
                )
            })
    }

    return [ordered]@{
        version   = '2.1.0'
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        runs      = @(
            [ordered]@{
                tool    = [ordered]@{
                    driver = [ordered]@{
                        name           = 'ADR Consistency Validator'
                        version        = '1.0.0'
                        informationUri = 'https://github.com/microsoft/hve-core'
                        rules          = [object[]]$rulesById.Values
                    }
                }
                results = $results.ToArray()
            }
        )
    }
}

function Invoke-AdrConsistencyValidator {
    <#
    .SYNOPSIS
        Orchestrates ADR consistency validation across a resolved file set.
    .DESCRIPTION
        Resolves target ADR files via Resolve-AdrFiles, invokes the AdrConsistency
        module rule registry on each file, aggregates violations, emits CI
        annotations and a step summary when running in CI, writes a JSON report
        to -OutputPath, and returns a report object whose ExitCode property
        reflects error and (optionally) warning severity counts.
    .PARAMETER Paths
        Directory or file paths to scan recursively for ADR markdown.
    .PARAMETER Files
        Explicit set of files to validate; takes precedence over -Paths.
    .PARAMETER ExcludePaths
        Wildcard patterns (repo-relative) that exclude matching files.
    .PARAMETER ChangedFilesOnly
        Limit the scan to markdown files changed against -BaseBranch.
    .PARAMETER BaseBranch
        Branch reference used by -ChangedFilesOnly for the changed-file diff.
    .PARAMETER OutputPath
        Destination JSON report path; parent directory is created if missing.
    .PARAMETER SarifOutputPath
        Optional destination SARIF report path; parent directory is created if missing.
    .PARAMETER WarningsAsErrors
        Treat warn-severity violations as failures in the returned ExitCode.
    .OUTPUTS
        [pscustomobject] with summary, violations, and ExitCode properties.
    .EXAMPLE
        Invoke-AdrConsistencyValidator -Paths @('docs/planning/adrs/') -OutputPath 'logs/adr-consistency-results.json'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$Paths,
        [string[]]$Files,
        [string[]]$ExcludePaths,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch,
        [string]$OutputPath,
        [string]$SarifOutputPath,
        [switch]$WarningsAsErrors
    )

    $repoRoot = Get-AdrRepoRoot
    $targets = Resolve-AdrFiles -Paths $Paths -Files $Files -ExcludePaths $ExcludePaths `
        -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -RepoRoot $repoRoot

    $allViolations = New-Object System.Collections.Generic.List[pscustomobject]
    foreach ($file in $targets) {
        $result = Invoke-AdrConsistencyValidation -Path $file -RepoRoot $repoRoot
        foreach ($v in $result.Violations) {
            $relFile = $v.file
            if ($relFile.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relFile = $relFile.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
            }
            $null = $allViolations.Add([pscustomobject]@{
                    file     = $relFile
                    ruleId   = $v.ruleId
                    severity = $v.severity
                    message  = $v.message
                    line     = $v.line
                })
        }
    }

    $errorCount = @($allViolations | Where-Object { $_.severity -eq 'error' }).Count
    $warnCount = @($allViolations | Where-Object { $_.severity -eq 'warn' }).Count

    $report = [pscustomobject]@{
        summary    = [pscustomobject]@{
            totalFiles  = $targets.Count
            errorCount  = $errorCount
            warnCount   = $warnCount
        }
        violations = @($allViolations)
    }

    foreach ($v in $allViolations) {
        $level = if ($v.severity -eq 'error') { 'Error' } else { 'Warning' }
        Write-Host "[$($v.severity)] $($v.file): [$($v.ruleId)] $($v.message)"
        if (Test-CIEnvironment) {
            $annotationParams = @{
                Level   = $level
                Message = "[$($v.ruleId)] $($v.message)"
                File    = $v.file
            }
            if ($null -ne $v.line) { $annotationParams['Line'] = [int]$v.line }
            Write-CIAnnotation @annotationParams
        }
    }

    Write-Host ''
    Write-Host "ADR consistency: $($targets.Count) file(s) | $errorCount error(s) | $warnCount warning(s)"

    $outDir = Split-Path -Path $OutputPath -Parent
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    if ($SarifOutputPath) {
        $sarifDir = Split-Path -Path $SarifOutputPath -Parent
        if ($sarifDir -and -not (Test-Path -LiteralPath $sarifDir)) {
            New-Item -ItemType Directory -Path $sarifDir -Force | Out-Null
        }
        ConvertTo-AdrConsistencySarif -Violations @($allViolations) |
            ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath $SarifOutputPath -Encoding UTF8
    }

    if (Test-CIEnvironment) {
        $summaryMd = @(
            '## ADR Consistency Validation',
            '',
            "- Files scanned: $($targets.Count)",
            "- Errors: $errorCount",
            "- Warnings: $warnCount"
        ) -join "`n"
        Write-CIStepSummary -Content $summaryMd
    }

    $exitCode = 0
    if ($errorCount -gt 0) { $exitCode = 1 }
    elseif ($WarningsAsErrors -and $warnCount -gt 0) { $exitCode = 1 }

    Add-Member -InputObject $report -MemberType NoteProperty -Name ExitCode -Value $exitCode -Force
    return $report
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-AdrConsistencyValidator -Paths $Paths -Files $Files -ExcludePaths $ExcludePaths `
            -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -OutputPath $OutputPath `
            -SarifOutputPath $SarifOutputPath -WarningsAsErrors:$WarningsAsErrors
        exit $result.ExitCode
    }
    catch {
        Write-Error "ADR consistency validator failed: $_"
        if (Test-CIEnvironment) {
            Write-CIAnnotation -Level 'Error' -Message "ADR consistency validator failed: $_"
        }
        exit 1
    }
}
