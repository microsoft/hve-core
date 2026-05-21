#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

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
    Limit the scan to markdown files changed against -BaseBranch (uses git diff).
.PARAMETER BaseBranch
    Branch reference used by -ChangedFilesOnly to compute the changed-file set.
.PARAMETER OutputPath
    File path where the JSON report is written. Parent directory is created if
    it does not exist.
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
    [string]$OutputPath = 'logs/adr-consistency-results.json'
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
        $changed = Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.md')
        foreach ($file in $changed) {
            $full = if ([System.IO.Path]::IsPathRooted($file)) { $file } else { Join-Path -Path $RepoRoot -ChildPath $file }
            $absolute = [System.IO.Path]::GetFullPath($full)
            if (-not $absolute.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Skipping path outside repository root: $file"
                continue
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
        if ($file.StartsWith($RepoRoot)) {
            $rel = $file.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        }
        $excluded = $false
        foreach ($pattern in $ExcludePaths) {
            $normPattern = $pattern.Replace('\', '/')
            if ($rel -like $normPattern) { $excluded = $true; break }
        }
        if (-not $excluded) { $null = $filtered.Add($file) }
    }
    return $filtered.ToArray()
}

function Invoke-AdrConsistencyValidator {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$Paths,
        [string[]]$Files,
        [string[]]$ExcludePaths,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch,
        [string]$OutputPath,
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
            if ($relFile.StartsWith($repoRoot)) {
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
            -WarningsAsErrors:$WarningsAsErrors
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
