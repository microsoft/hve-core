#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Repository-aware wrapper for markdown-link-check.

.DESCRIPTION
    Runs markdown-link-check with the repo-specific configuration. Internal links
    are always validated across the whole repository, because deleting, renaming,
    or moving a target breaks references in files the change never touched.
    External links are fetched once per unique URL and may be scoped to changed
    files. Checks tracked and untracked, nonignored files so local validation does
    not require staging.

.PARAMETER Path
    One or more files or directories to scan. Directories are searched
    recursively for Markdown files. Defaults to the Docsify navigation sources.

.PARAMETER ConfigPath
    Path to the shared markdown-link-check configuration file.

.PARAMETER Quiet
    Suppress non-error output from markdown-link-check.

.PARAMETER ChangedFilesOnly
    Restrict external-link validation to Markdown files changed relative to
    BaseBranch. Internal links are still validated repository-wide. External links
    in unchanged files are reported as skipped rather than checked.

.PARAMETER BaseBranch
    Branch reference used by -ChangedFilesOnly to compute the changed-file set.

.PARAMETER ThrottleLimit
    Maximum number of markdown-link-check processes run concurrently, and the
    minimum number of batches targets are distributed across. Additional batches
    are created when a batch would exceed the platform command-line length limit.

.EXAMPLE
    # Validate all markdown links across the repository
    ./Markdown-Link-Check.ps1

.EXAMPLE
    # Validate specific path with verbose output
    ./Markdown-Link-Check.ps1 -Path ".github" -Quiet:$false

.EXAMPLE
    # Validate internal links repository-wide and external links only in changed files
    ./Markdown-Link-Check.ps1 -ChangedFilesOnly
    #>

[CmdletBinding()]
param(
    [string[]]$Path = @(
        ".",
        ".github",
        ".devcontainer"
    ),

    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'markdown-link-check.config.json'),

    [switch]$Quiet,

    [switch]$ChangedFilesOnly,

    [string]$BaseBranch = 'origin/main',

    [ValidateRange(1, 32)]
    [int]$ThrottleLimit = 8
)

$ErrorActionPreference = 'Stop'

# Import LintingHelpers module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

function Get-MarkdownTarget {
    <#
    .SYNOPSIS
        Resolves Markdown files to validate from provided path arguments.

    .DESCRIPTION
        Accepts files or directories, expanding directories to all tracked and
        untracked, nonignored Markdown files discovered recursively, and returns
        a sorted, unique list of absolute file paths for downstream validation.

    .PARAMETER InputPath
        Files or directories that may contain Markdown content.

    .PARAMETER ChangedFilesOnly
        Restrict the result to Markdown files changed relative to BaseBranch.

    .PARAMETER BaseBranch
        Branch reference used to compute the changed-file set.

    .OUTPUTS
        System.String[]
    #>
    param(
        [string[]]$InputPath,

        [switch]$ChangedFilesOnly,

        [string]$BaseBranch = 'origin/main'
    )

    $targets = @()
    $repoRoot = git rev-parse --show-toplevel 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Not in a git repository, falling back to file system search"
        if ($ChangedFilesOnly) {
            Write-Warning "Changed-files-only mode requires a git repository; scanning all Markdown files"
        }
        # Fallback to original implementation if not in git repo
        foreach ($item in $InputPath) {
            if ([string]::IsNullOrWhiteSpace($item)) {
                continue
            }

            $resolved = Resolve-Path -LiteralPath $item -ErrorAction SilentlyContinue
            if (-not $resolved) {
                Write-Warning "Unable to resolve path: $item"
                continue
            }

            foreach ($resolvedPath in $resolved) {
                if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
                    $targets += Get-ChildItem -LiteralPath $resolvedPath -Recurse -Include *.md |
                                Where-Object { -not $_.PSIsContainer } |
                                Select-Object -ExpandProperty FullName
                }
                else {
                    $targets += $resolvedPath.ProviderPath
                }
            }
        }
        return ($targets | Sort-Object -Unique)
    }

    Write-Verbose "Searching for tracked and untracked, nonignored markdown files..."
    Write-Verbose "Repository root: $repoRoot"

    # Repo-relative changed-file allowlist; $null means "no changed-file filtering".
    $changedSet = $null
    if ($ChangedFilesOnly) {
        $changedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($changed in @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.md'))) {
            [void]$changedSet.Add(($changed -replace '\\', '/'))
        }

        Write-Verbose "Changed markdown files detected against ${BaseBranch}: $($changedSet.Count)"
    }

    # Git-aware implementation
    foreach ($item in $InputPath) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        # Check if it's a specific file or directory
        if (Test-Path -Path $item -PathType Leaf) {
            # Specific file - check if it is tracked or untracked and nonignored.
            $absolutePath = (Resolve-Path $item).Path
            $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $absolutePath) -replace '\\', '/'
            $listed = git ls-files --cached --others --exclude-standard -- $relativePath 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "git ls-files failed while resolving '$item'."
            }

            if ($listed -and $item -like "*.md") {
                if ($null -eq $changedSet -or $changedSet.Contains($relativePath)) {
                    $targets += $absolutePath
                }
            }
            elseif (-not $listed) {
                Write-Warning "File is ignored by git: $item"
            }
        }
        elseif (Test-Path -Path $item -PathType Container) {
            # Directory - get all tracked and untracked, nonignored markdown files.
            $absolutePath = (Resolve-Path $item).Path
            $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $absolutePath) -replace '\\', '/'
            $prefix = if ($relativePath -eq '.') { '' } else { "$relativePath/" }

            Write-Verbose "Searching under: $(if ($prefix) { $prefix } else { '<repository root>' })"

            # Enumerate without a pathspec, then filter in PowerShell. Git pathspec
            # wildcards match a single path component here, so '<dir>/**/*.md' silently
            # skipped both nested files and files sitting directly in <dir>.
            $listedFiles = @(git ls-files --cached --others --exclude-standard 2>$null)
            if ($LASTEXITCODE -ne 0) {
                throw "git ls-files failed while searching '$item'."
            }

            $trackedFiles = $listedFiles |
                Where-Object { $_ -like '*.md' } |
                Where-Object { $prefix -eq '' -or $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) } |
                Where-Object { $_ -notlike 'scripts/tests/*fixtures/*' } |
                # Generated output; 490 of its 504 markdown files symlink to sources already checked.
                Where-Object { $_ -notlike 'plugins/*' } |
                Where-Object { $null -eq $changedSet -or $changedSet.Contains($_) }

            if ($trackedFiles) {
                foreach ($file in $trackedFiles) {
                    $fullPath = Join-Path $repoRoot $file
                    if (Test-Path -LiteralPath $fullPath) {
                        $targets += $fullPath
                    }
                }
            }
        }
        else {
            Write-Warning "Unable to resolve path: $item"
        }
    }

    Write-Verbose "Found $($targets.Count) tracked and untracked markdown files"
    return ($targets | Sort-Object -Unique)
}

function Get-RelativePrefix {
    <#
    .SYNOPSIS
        Builds a normalized relative prefix between two paths.

    .DESCRIPTION
        Computes the relative path from a source directory to a destination and
        enforces forward-slash separators with a trailing slash when required to
        produce consistent link prefixes.

    .PARAMETER FromPath
        The directory from which the relative path should be calculated.

    .PARAMETER ToPath
        The target path that should be expressed relative to the source.

    .OUTPUTS
        System.String
    #>
    param(
        [string]$FromPath,
        [string]$ToPath
    )

    $relative = [System.IO.Path]::GetRelativePath($FromPath, $ToPath)
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative -eq '.') {
        return ''
    }

    $normalized = $relative -replace '\\', '/'
    if (-not $normalized.EndsWith('/')) {
        $normalized += '/'
    }

    return $normalized
}

function Split-MarkdownTargetBatch {
    <#
    .SYNOPSIS
        Splits Markdown targets into deterministic balanced batches.

    .DESCRIPTION
        Sorts the supplied target paths and distributes them across no more than
        the configured throttle limit. Each returned object preserves its file
        array as one pipeline item for parallel processing.

        When an argument-length budget is supplied, the throttle limit becomes a
        minimum batch count rather than a maximum: a count-balanced batch whose
        arguments would not fit is split into contiguous sub-batches so every
        emitted batch stays within the budget. Callers that omit the budget keep
        the count-only behavior.

    .PARAMETER Target
        Repository-relative Markdown file paths to batch.

    .PARAMETER ThrottleLimit
        Minimum number of batches to create, and the maximum when no
        argument-length budget applies.

    .PARAMETER ArgumentLengthBudget
        Total command-line length available to one invocation. Zero disables
        length-based splitting.

    .PARAMETER ReservedLength
        Length already consumed by the executable path and the fixed arguments
        every invocation carries, which is unavailable to target arguments.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$Target,

        [ValidateRange(1, 32)]
        [int]$ThrottleLimit,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$ArgumentLengthBudget = 0,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$ReservedLength = 0
    )

    $sortedTargets = @($Target | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
    if ($sortedTargets.Count -eq 0) {
        return
    }

    $batchCount = [Math]::Min($sortedTargets.Count, $ThrottleLimit)
    $baseSize = [Math]::Floor($sortedTargets.Count / $batchCount)
    $remainder = $sortedTargets.Count % $batchCount
    $offset = 0
    $countBalancedBatches = @()

    for ($index = 0; $index -lt $batchCount; $index++) {
        $batchSize = $baseSize + $(if ($index -lt $remainder) { 1 } else { 0 })
        $countBalancedBatches += , @($sortedTargets[$offset..($offset + $batchSize - 1)])
        $offset += $batchSize
    }

    $emitIndex = 0
    if ($ArgumentLengthBudget -le 0) {
        foreach ($files in $countBalancedBatches) {
            [pscustomobject]@{
                Index = $emitIndex
                Files = @($files)
            }
            $emitIndex++
        }
        return
    }

    $available = $ArgumentLengthBudget - $ReservedLength
    if ($available -le 0) {
        throw "The reserved command-line length $ReservedLength leaves no room within the budget $ArgumentLengthBudget."
    }

    # Balanced-by-count batches are not balanced by length when path lengths vary,
    # so each batch is packed greedily against the budget rather than trusting an
    # average. Every argument also costs a separating space and the two quote
    # characters a shell adds for values containing spaces.
    foreach ($files in $countBalancedBatches) {
        $currentFiles = @()
        $currentLength = 0

        foreach ($file in $files) {
            $cost = $file.Length + 3
            if ($cost -gt $available) {
                throw "Markdown target '$file' alone exceeds the available command-line length $available."
            }

            if ($currentFiles.Count -gt 0 -and ($currentLength + $cost) -gt $available) {
                [pscustomobject]@{
                    Index = $emitIndex
                    Files = @($currentFiles)
                }
                $emitIndex++
                $currentFiles = @()
                $currentLength = 0
            }

            $currentFiles += $file
            $currentLength += $cost
        }

        if ($currentFiles.Count -gt 0) {
            [pscustomobject]@{
                Index = $emitIndex
                Files = @($currentFiles)
            }
            $emitIndex++
        }
    }
}

function Get-MarkdownBatchLengthBudget {
    <#
    .SYNOPSIS
        Computes the command-line length budget for source-pass batches.

    .DESCRIPTION
        Returns the platform command-line ceiling and the length reserved by the
        executable path and the fixed arguments every source invocation carries,
        so batching can bound only the target arguments it appends.

        On Windows the CLI resolves to a .cmd shim, so the process is dispatched
        through the command interpreter and the 8191-character interpreter limit
        governs rather than the 32767-character CreateProcess limit. The reserved
        allowance therefore includes the interpreter wrapper and per-argument
        quoting overhead.

    .PARAMETER Cli
        Path to the markdown-link-check executable.

    .PARAMETER BaseArgument
        Arguments applied to every invocation before target files.

    .PARAMETER ReportPath
        A representative JUnit report path carried by the reporter arguments.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Cli,

        [string[]]$BaseArgument,

        [string]$ReportPath
    )

    $budget = if ($IsWindows) { 8191 } else { 131072 }

    $fixedArguments = @($BaseArgument) + @(
        '--reporters',
        'default,junit',
        '--junit-output',
        $ReportPath
    )

    $reserved = $Cli.Length + 3
    foreach ($argument in $fixedArguments) {
        $reserved += ([string]$argument).Length + 3
    }

    if ($IsWindows) {
        # PowerShell dispatches a .cmd shim through the command interpreter.
        $reserved += 'cmd.exe /c ""'.Length
    }

    return [pscustomobject]@{
        Budget = $budget
        Reserved = $reserved
    }
}

function Test-MarkdownExternalScope {
    <#
    .SYNOPSIS
        Tests whether a source file belongs to the external-link scope.

    .DESCRIPTION
        Compares a relative source path against the external-link allowlist. An
        absent allowlist means every file is in scope; an empty allowlist means
        no file is. Those two states have opposite meanings, so callers must pass
        $null rather than an empty set when no scoping applies.

        Both sides are normalized to forward slashes because relative source
        paths carry the platform separator while the allowlist is normalized when
        it is built.

    .PARAMETER RelativePath
        Repository-relative source path as reported by the source pass.

    .PARAMETER Scope
        Allowlist of normalized repository-relative paths, or $null for all files.

    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$RelativePath,

        [AllowNull()]
        [System.Collections.Generic.HashSet[string]]$Scope
    )

    if ($null -eq $Scope) {
        return $true
    }

    return $Scope.Contains(($RelativePath -replace '\\', '/'))
}

function ConvertFrom-MarkdownLinkCheckReport {
    <#
    .SYNOPSIS
        Converts a batched JUnit report into per-file link-check results.

    .DESCRIPTION
        Matches each JUnit suite to an expected file through its full file
        property. Selective attribution is trusted only when suites and expected
        files form a one-to-one set; otherwise every expected file fails closed
        while links from suites that could be identified remain available.

    .PARAMETER ExpectedFile
        Repository-relative files supplied to one CLI invocation.

    .PARAMETER ReportContent
        JUnit XML emitted by markdown-link-check.

    .PARAMETER ExitCode
        Aggregate exit code from the batched CLI invocation.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]]$ExpectedFile,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$ReportContent,

        [int]$ExitCode = 0
    )

    $expectedFiles = @($ExpectedFile | Sort-Object)
    if ($expectedFiles.Count -eq 0) {
        return
    }

    $pathComparer = if ($IsWindows) {
        [System.StringComparer]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparer]::Ordinal
    }
    $expectedByNormalizedPath = [System.Collections.Generic.Dictionary[string, string]]::new($pathComparer)
    $linksByFile = @{}
    $failedByFile = @{}
    $reportTrusted = $true
    $reportError = $null

    foreach ($expected in $expectedFiles) {
        $normalized = $expected -replace '\\', '/'
        if ($expectedByNormalizedPath.ContainsKey($normalized)) {
            $reportTrusted = $false
        }
        else {
            $expectedByNormalizedPath.Add($normalized, $expected)
        }
        $linksByFile[$expected] = @()
        $failedByFile[$expected] = $false
    }

    try {
        if ([string]::IsNullOrWhiteSpace($ReportContent)) {
            throw 'The JUnit report was not created.'
        }

        [xml]$xml = $ReportContent
        $seenFiles = [System.Collections.Generic.HashSet[string]]::new($pathComparer)
        foreach ($testSuite in @($xml.testsuites.testsuite)) {
            $fileProperties = @($testSuite.properties.property | Where-Object { $_.name -eq 'file' })
            if ($fileProperties.Count -ne 1 -or [string]::IsNullOrWhiteSpace($fileProperties[0].value)) {
                $reportTrusted = $false
                continue
            }

            $normalizedSuiteFile = ([string]$fileProperties[0].value) -replace '\\', '/'
            if (-not $expectedByNormalizedPath.ContainsKey($normalizedSuiteFile) -or -not $seenFiles.Add($normalizedSuiteFile)) {
                $reportTrusted = $false
                continue
            }

            $expected = $expectedByNormalizedPath[$normalizedSuiteFile]
            $links = foreach ($testCase in @($testSuite.testcase)) {
                if ($null -eq $testCase) {
                    continue
                }

                $properties = @($testCase.properties.property)
                [pscustomobject]@{
                    Url = ($properties | Where-Object { $_.name -eq 'url' } | Select-Object -First 1).value
                    Status = ($properties | Where-Object { $_.name -eq 'status' } | Select-Object -First 1).value
                    StatusCode = ($properties | Where-Object { $_.name -eq 'statusCode' } | Select-Object -First 1).value
                }
            }
            $linksByFile[$expected] = @($links)
            $failedByFile[$expected] = (
                [int]$testSuite.failures -gt 0 -or
                [int]$testSuite.errors -gt 0 -or
                @($links | Where-Object { $_.Status -in @('dead', 'error') }).Count -gt 0
            )
        }

        if ($seenFiles.Count -ne $expectedByNormalizedPath.Count) {
            $reportTrusted = $false
        }
    }
    catch {
        $reportTrusted = $false
        $reportError = $_.Exception.Message
    }

    $hasReportedFailure = @($failedByFile.Values | Where-Object { $_ }).Count -gt 0
    $unexplainedExit = $reportTrusted -and $ExitCode -ne 0 -and -not $hasReportedFailure

    foreach ($expected in $expectedFiles) {
        [pscustomobject]@{
            File = $expected
            Links = @($linksByFile[$expected])
            Failed = (-not $reportTrusted) -or $unexplainedExit -or $failedByFile[$expected]
            ParseFailed = -not $reportTrusted
            ReportError = $reportError
        }
    }
}

function Invoke-MarkdownLinkCheckBatch {
    <#
    .SYNOPSIS
        Runs prepared markdown-link-check batches with bounded parallelism.

    .DESCRIPTION
        Invokes the configured CLI once for each prepared batch, using the
        caller-provided JUnit report path and returning raw ordered evidence for
        later source or aggregate conversion. The caller owns workspace cleanup.

    .PARAMETER Batch
        Batch objects containing Index, Files, and ReportPath properties.

    .PARAMETER Cli
        Path to the markdown-link-check executable.

    .PARAMETER BaseArgument
        Arguments applied to every CLI invocation before target files.

    .PARAMETER RootPath
        Working directory used by each parallel worker.

    .PARAMETER ThrottleLimit
        Maximum number of CLI processes to run concurrently.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [object[]]$Batch,

        [string]$Cli,

        [string[]]$BaseArgument,

        [string]$RootPath,

        [ValidateRange(1, 32)]
        [int]$ThrottleLimit
    )

    return @($Batch | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        Set-Location -LiteralPath $using:RootPath
        $currentBatch = $_
        $output = $null
        $exitCode = 0
        $reportContent = $null
        $invocationError = $null
        try {
            $commandArgs = $using:BaseArgument + @($currentBatch.Files) + @(
                '--reporters',
                'default,junit',
                '--junit-output',
                $currentBatch.ReportPath
            )

            $output = & $using:Cli @commandArgs 2>&1
            $exitCode = $LASTEXITCODE

            if (Test-Path -LiteralPath $currentBatch.ReportPath) {
                $reportContent = Get-Content -LiteralPath $currentBatch.ReportPath -Raw -Encoding utf8
            }
        }
        catch {
            $invocationError = $_.Exception.Message
        }

        [pscustomobject]@{
            Index = $currentBatch.Index
            Files = @($currentBatch.Files)
            ExpectedUrls = @($currentBatch.ExpectedUrls)
            ExitCode = $exitCode
            Output = $output
            ReportContent = $reportContent
            InvocationError = $invocationError
        }
    })
}

function ConvertFrom-MarkdownExternalLinkReport {
    <#
    .SYNOPSIS
        Validates one synthetic external-link JUnit report.

    .DESCRIPTION
        Trusts an aggregate report only when its suite is attributed to the
        expected synthetic file and every expected URL has one testcase with
        one supported status and at most one status code.

    .PARAMETER ExpectedFile
        Synthetic Markdown file supplied to the CLI invocation.

    .PARAMETER ExpectedUrl
        Exact external URLs assigned to the synthetic file.

    .PARAMETER ReportContent
        JUnit XML emitted by markdown-link-check.

    .PARAMETER ExitCode
        Exit code from the aggregate CLI invocation.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ExpectedFile,

        [string[]]$ExpectedUrl,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$ReportContent,

        [int]$ExitCode = 0
    )

    $links = @()
    $reportError = $null
    try {
        if ([string]::IsNullOrWhiteSpace($ReportContent)) {
            throw 'The JUnit report was not created.'
        }

        $pathComparer = if ($IsWindows) {
            [System.StringComparer]::OrdinalIgnoreCase
        }
        else {
            [System.StringComparer]::Ordinal
        }
        $expectedUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($url in $ExpectedUrl) {
            if ([string]::IsNullOrWhiteSpace($url) -or -not $expectedUrls.Add($url)) {
                throw 'Expected aggregate URLs must be unique and nonblank.'
            }
        }

        [xml]$xml = $ReportContent
        $testSuites = @($xml.testsuites.testsuite)
        if ($testSuites.Count -ne 1) {
            throw 'The aggregate report must contain exactly one test suite.'
        }

        $testSuite = $testSuites[0]
        $fileProperties = @($testSuite.properties.property | Where-Object { $_.name -eq 'file' })
        if ($fileProperties.Count -ne 1 -or [string]::IsNullOrWhiteSpace($fileProperties[0].value)) {
            throw 'The aggregate suite must contain exactly one nonblank file property.'
        }

        $reportedFile = ([string]$fileProperties[0].value) -replace '\\', '/'
        $normalizedExpectedFile = $ExpectedFile -replace '\\', '/'
        if (-not $pathComparer.Equals($reportedFile, $normalizedExpectedFile)) {
            throw "The aggregate suite was attributed to an unexpected file: $reportedFile"
        }

        $supportedStatuses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($status in @('alive', 'dead', 'ignored', 'error')) {
            [void]$supportedStatuses.Add($status)
        }
        $seenUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($testCase in @($testSuite.testcase)) {
            if ($null -eq $testCase) {
                continue
            }

            $properties = @($testCase.properties.property)
            $urlProperties = @($properties | Where-Object { $_.name -eq 'url' })
            $statusProperties = @($properties | Where-Object { $_.name -eq 'status' })
            $statusCodeProperties = @($properties | Where-Object { $_.name -eq 'statusCode' })
            if ($urlProperties.Count -ne 1 -or [string]::IsNullOrWhiteSpace($urlProperties[0].value)) {
                throw 'Each aggregate testcase must contain exactly one nonblank url property.'
            }
            if ($statusProperties.Count -ne 1 -or -not $supportedStatuses.Contains([string]$statusProperties[0].value)) {
                throw 'Each aggregate testcase must contain exactly one supported status property.'
            }
            if ($statusCodeProperties.Count -gt 1) {
                throw 'Each aggregate testcase may contain at most one statusCode property.'
            }

            $url = [string]$urlProperties[0].value
            if (-not $expectedUrls.Contains($url) -or -not $seenUrls.Add($url)) {
                throw "The aggregate report contained a duplicate or unexpected URL: $url"
            }

            $links += [pscustomobject]@{
                Url = $url
                Status = [string]$statusProperties[0].value
                StatusCode = if ($statusCodeProperties.Count -eq 1) {
                    [string]$statusCodeProperties[0].value
                }
                else {
                    $null
                }
            }
        }

        if ($seenUrls.Count -ne $expectedUrls.Count) {
            throw 'The aggregate report did not contain one result for every expected URL.'
        }

        $hasReportedFailure = @($links | Where-Object { $_.Status -in @('dead', 'error') }).Count -gt 0
        if ($ExitCode -ne 0 -and -not $hasReportedFailure) {
            throw "The aggregate CLI exited with code $ExitCode without a dead or error result."
        }
    }
    catch {
        $links = @()
        $reportError = $_.Exception.Message
    }

    return [pscustomobject]@{
        Trusted = $null -eq $reportError
        Links = @($links)
        ReportError = $reportError
    }
}

function Invoke-MarkdownLinkCheck {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string[]]$Path,
        [string]$ConfigPath,
        [switch]$Quiet,
        [switch]$ChangedFilesOnly,
        [string]$BaseBranch = 'origin/main',
        [int]$ThrottleLimit = 8
    )

    $scriptRootParent = Split-Path -Path $PSScriptRoot -Parent
    $repoRootPath = Split-Path -Path $scriptRootParent -Parent
    $repoRoot = Resolve-Path -LiteralPath $repoRootPath
    $config = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop

    # Internal links are validated repository-wide on every run, because deleting,
    # renaming, or moving a target breaks references in files the change never
    # touched. External links decay on their own schedule instead, so they are
    # scoped to changed Markdown and the weekly full sweep owns the rest.
    $filesToCheck = @(Get-MarkdownTarget -InputPath $Path)

    if (-not $filesToCheck -or @($filesToCheck).Count -eq 0) {
        throw 'No markdown files were found to validate.'
    }

    # $null means "no external scoping"; an empty set means "no file is in scope".
    # Conflating the two would silently disable all external checking.
    $externalScope = $null
    if ($ChangedFilesOnly) {
        $externalScope = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $changedTargets = @(Get-MarkdownTarget -InputPath $Path -ChangedFilesOnly -BaseBranch $BaseBranch)
        foreach ($changedTarget in $changedTargets) {
            $changedRelative = [System.IO.Path]::GetRelativePath($repoRoot.Path, $changedTarget) -replace '\\', '/'
            [void]$externalScope.Add($changedRelative)
        }

        if ($externalScope.Count -eq 0) {
            Write-Output 'No changed markdown files; external link validation was skipped.'
        }
    }

    $cliOverride = Get-Variable -Name MarkdownLinkCheckCliOverride -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($cliOverride) {
        $cli = [string]$cliOverride
    }
    else {
        $cli = Join-Path -Path $repoRoot.Path -ChildPath 'node_modules/.bin/markdown-link-check'
        if ($IsWindows) {
            $cli += '.cmd'
        }
    }

    if (-not (Test-Path -LiteralPath $cli)) {
        throw 'markdown-link-check is not installed. Run "npm install --save-dev markdown-link-check" first.'
    }

    $failedFiles = @()
    $brokenLinks = @()
    $totalLinks = 0
    $skippedLinks = 0
    $totalFiles = $filesToCheck.Count
    $rootPath = $repoRoot.Path

    $taskWorkspace = Join-Path ([System.IO.Path]::GetTempPath()) (
        'markdown-link-check-{0}' -f [System.Guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $taskWorkspace -Force | Out-Null
    try {
        $sourceConfig = Get-Content -LiteralPath $config.Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        $existingIgnorePatterns = @()
        if (
            $sourceConfig.ContainsKey('ignorePatterns') -and
            $null -ne $sourceConfig['ignorePatterns']
        ) {
            $existingIgnorePatterns += @($sourceConfig['ignorePatterns'])
        }
        $sourceConfig['ignorePatterns'] = $existingIgnorePatterns + @(
            @{ pattern = '^[Hh][Tt][Tt][Pp][Ss]?://' }
        )
        $sourceConfigPath = Join-Path $taskWorkspace 'source-config.json'
        $sourceConfig | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $sourceConfigPath -Encoding utf8

        $sourceArguments = @('-c', $sourceConfigPath)
        if ($Quiet) {
            $sourceArguments += '-q'
        }

        $relativeTargets = @($filesToCheck | ForEach-Object {
            [System.IO.Path]::GetRelativePath($rootPath, (Resolve-Path -LiteralPath $_))
        })
        $lengthBudget = Get-MarkdownBatchLengthBudget `
            -Cli $cli `
            -BaseArgument $sourceArguments `
            -ReportPath (Join-Path $taskWorkspace 'source-00.xml')
        $targetBatches = @(Split-MarkdownTargetBatch `
            -Target $relativeTargets `
            -ThrottleLimit $ThrottleLimit `
            -ArgumentLengthBudget $lengthBudget.Budget `
            -ReservedLength $lengthBudget.Reserved | ForEach-Object {
            [pscustomobject]@{
                Index = $_.Index
                Files = @($_.Files)
                ReportPath = Join-Path $taskWorkspace ('source-{0:D2}.xml' -f $_.Index)
            }
        })
        $batchResults = @(Invoke-MarkdownLinkCheckBatch `
            -Batch $targetBatches `
            -Cli $cli `
            -BaseArgument $sourceArguments `
            -RootPath $rootPath `
            -ThrottleLimit $ThrottleLimit)

        $fileResults = @()
        foreach ($batchResult in ($batchResults | Sort-Object -Property Index)) {
            if (($VerbosePreference -eq 'Continue' -or $batchResult.ExitCode -ne 0) -and $null -ne $batchResult.Output) {
                Write-Host $batchResult.Output
            }

            $convertedResults = @(ConvertFrom-MarkdownLinkCheckReport `
                -ExpectedFile $batchResult.Files `
                -ReportContent $batchResult.ReportContent `
                -ExitCode $batchResult.ExitCode)
            if (@($convertedResults | Where-Object ParseFailed).Count -gt 0) {
                $reason = if ($batchResult.InvocationError) {
                    $batchResult.InvocationError
                }
                elseif ($convertedResults[0].ReportError) {
                    $convertedResults[0].ReportError
                }
                else {
                    'The report did not contain one unique suite for every expected file.'
                }
                Write-Warning "Failed to parse or attribute XML output for batch $($batchResult.Index): $reason"
            }
            $fileResults += $convertedResults
        }

        $externalUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($fileResult in @($fileResults | Where-Object { -not $_.ParseFailed })) {
            if (-not (Test-MarkdownExternalScope -RelativePath $fileResult.File -Scope $externalScope)) {
                continue
            }

            foreach ($link in $fileResult.Links) {
                if ([regex]::IsMatch([string]$link.Url, '^[Hh][Tt][Tt][Pp][Ss]?://')) {
                    [void]$externalUrls.Add([string]$link.Url)
                }
            }
        }

        $externalResultsByUrl = [System.Collections.Generic.Dictionary[string, object]]::new(
            [System.StringComparer]::Ordinal
        )
        $externalErrorsByUrl = [System.Collections.Generic.Dictionary[string, string]]::new(
            [System.StringComparer]::Ordinal
        )
        if ($externalUrls.Count -gt 0) {
            $urlBatches = @(Split-MarkdownTargetBatch -Target @($externalUrls) -ThrottleLimit $ThrottleLimit)
            $aggregateBatches = @($urlBatches | ForEach-Object {
                $aggregatePath = Join-Path $taskWorkspace ('external-links-{0:D2}.md' -f $_.Index)
                $content = foreach ($url in $_.Files) {
                    '<a href="{0}">link</a>' -f [System.Net.WebUtility]::HtmlEncode($url)
                }
                $content | Set-Content -LiteralPath $aggregatePath -Encoding utf8
                [pscustomobject]@{
                    Index = $_.Index
                    Files = @($aggregatePath)
                    ExpectedUrls = @($_.Files)
                    ReportPath = Join-Path $taskWorkspace ('external-{0:D2}.xml' -f $_.Index)
                }
            })
            $aggregateArguments = @('-c', $config.Path, '-q')
            $aggregateResults = @(Invoke-MarkdownLinkCheckBatch `
                -Batch $aggregateBatches `
                -Cli $cli `
                -BaseArgument $aggregateArguments `
                -RootPath $rootPath `
                -ThrottleLimit $ThrottleLimit)

            foreach ($aggregateResult in ($aggregateResults | Sort-Object -Property Index)) {
                $convertedAggregate = ConvertFrom-MarkdownExternalLinkReport `
                    -ExpectedFile $aggregateResult.Files[0] `
                    -ExpectedUrl $aggregateResult.ExpectedUrls `
                    -ReportContent $aggregateResult.ReportContent `
                    -ExitCode $aggregateResult.ExitCode
                if ($convertedAggregate.Trusted) {
                    foreach ($link in $convertedAggregate.Links) {
                        $externalResultsByUrl[$link.Url] = $link
                    }
                    continue
                }

                $reason = if ($aggregateResult.InvocationError) {
                    $aggregateResult.InvocationError
                }
                else {
                    $convertedAggregate.ReportError
                }
                Write-Warning "Failed to trust external-link batch $($aggregateResult.Index): $reason"
                foreach ($url in $aggregateResult.ExpectedUrls) {
                    $externalErrorsByUrl[$url] = $reason
                }
            }
        }

        foreach ($fileResult in @($fileResults | Where-Object { -not $_.ParseFailed })) {
            $inExternalScope = Test-MarkdownExternalScope -RelativePath $fileResult.File -Scope $externalScope
            $replayedLinks = foreach ($link in $fileResult.Links) {
                $url = [string]$link.Url
                if (-not [regex]::IsMatch($url, '^[Hh][Tt][Tt][Pp][Ss]?://')) {
                    $link
                    continue
                }

                if (-not $inExternalScope) {
                    # The source pass ignores every external link by configuration,
                    # so the inbound placeholder already reads 'ignored'. A new link
                    # is built instead of passing it through, keeping "excluded by
                    # configuration" distinct from "excluded by this run's scope".
                    [pscustomobject]@{
                        Url = $url
                        Status = 'skipped'
                        StatusCode = $null
                    }
                    continue
                }

                if ($externalErrorsByUrl.ContainsKey($url)) {
                    $fileResult.Failed = $true
                    $fileResult.ParseFailed = $true
                    if ([string]::IsNullOrWhiteSpace($fileResult.ReportError)) {
                        $fileResult.ReportError = $externalErrorsByUrl[$url]
                    }
                    $link
                    continue
                }

                if (-not $externalResultsByUrl.ContainsKey($url)) {
                    $fileResult.Failed = $true
                    $fileResult.ParseFailed = $true
                    $fileResult.ReportError = "No trusted aggregate result was available for $url"
                    $link
                    continue
                }

                $externalResult = $externalResultsByUrl[$url]
                [pscustomobject]@{
                    Url = $url
                    Status = $externalResult.Status
                    StatusCode = $externalResult.StatusCode
                }
            }
            $fileResult.Links = @($replayedLinks)
            if (@($fileResult.Links | Where-Object { $_.Status -in @('dead', 'error') }).Count -gt 0) {
                $fileResult.Failed = $true
            }
        }

        foreach ($fileResult in ($fileResults | Sort-Object -Property File)) {
            $relative = $fileResult.File
            Write-Output "Checking $relative"

            foreach ($link in $fileResult.Links) {
                # A skipped link was deliberately left unchecked by this run's
                # scope, so counting it would overstate what was actually resolved.
                # It is counted separately instead, because a consumer reading only
                # the totals would otherwise see an unexplained shortfall.
                if ($link.Status -eq 'skipped') {
                    $skippedLinks++
                }
                else {
                    $totalLinks++
                }

                # Display human-readable output if not quiet
                if (-not $Quiet) {
                    if ($link.Status -eq 'alive') {
                        Write-Host "  ✓ $($link.Url)" -ForegroundColor Green
                    }
                    elseif ($link.Status -eq 'ignored') {
                        Write-Host "  / $($link.Url) (ignored)" -ForegroundColor Yellow
                    }
                    elseif ($link.Status -eq 'skipped') {
                        Write-Host "  - $($link.Url) (skipped: outside the changed-file scope)" -ForegroundColor DarkGray
                    }
                    elseif ($link.Status -eq 'dead') {
                        Write-Host "  ✖ $($link.Url) → Status: $($link.StatusCode)" -ForegroundColor Red
                    }
                }

                # Process broken links
                if ($link.Status -eq 'dead') {
                    $brokenLinks += @{
                        File = $relative
                        Link = $link.Url
                        Status = "$($link.StatusCode)"
                    }

                    Write-CIAnnotation -Message "Broken link: $($link.Url) (Status: $($link.StatusCode))" -Level Error -File $relative
                }
            }

            if ($fileResult.Failed -and $failedFiles -notcontains $relative) {
                $failedFiles += $relative
            }
        }

        # Create logs directory and export results
        $logsDir = Join-Path -Path $repoRoot.Path -ChildPath 'logs'
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }

        $results = @{
        Timestamp = Get-StandardTimestamp
        script = 'markdown-link-check'
        summary = @{
            total_files = $totalFiles
            files_with_broken_links = $failedFiles.Count
            total_links_checked = $totalLinks
            skipped_links = $skippedLinks
            total_broken_links = $brokenLinks.Count
        }
        broken_links = $brokenLinks
    }

        $resultsPath = Join-Path -Path $logsDir -ChildPath 'markdown-link-check-results.json'
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8

    # Generate GitHub step summary
        if ($failedFiles.Count -gt 0) {
            $summaryContent = @"
## ❌ Markdown Link Check Failed

**Files with broken links:** $($failedFiles.Count) / $totalFiles
**Total broken links:** $($brokenLinks.Count)

### Broken Links

| File | Broken Link |
|------|-------------|
"@

            foreach ($link in $brokenLinks) {
                $safeFile = if ((Get-CIPlatform) -eq 'azdo') {
                    ConvertTo-AzureDevOpsEscaped -Value $link.File
                } else { $link.File }
                $safeLink = if ((Get-CIPlatform) -eq 'azdo') {
                    ConvertTo-AzureDevOpsEscaped -Value $link.Link
                } else { $link.Link }
                $summaryContent += "`n| ``$safeFile`` | ``$safeLink`` |"
            }

            $summaryContent += @"


### How to Fix

1. Review the broken links listed above
2. Update or remove invalid links
3. Re-run the link check to verify fixes

For more information, see the [markdown-link-check documentation](https://github.com/tcort/markdown-link-check).
"@

            Write-CIStepSummary -Content $summaryContent
            Set-CIEnv -Name "MARKDOWN_LINK_CHECK_FAILED" -Value "true"

            throw ("markdown-link-check reported failures for: {0}" -f ($failedFiles -join ', '))
        }
        else {
            $summaryContent = @"
## ✅ Markdown Link Check Passed

**Files checked:** $totalFiles
**Total links checked:** $totalLinks
**Broken links:** 0

Great job! All markdown links are valid. 🎉
"@

            Write-CIStepSummary -Content $summaryContent
            Write-Output 'markdown-link-check completed successfully.'
        }
    }
    finally {
        Remove-Item -LiteralPath $taskWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-MarkdownLinkCheck -Path $Path -ConfigPath $ConfigPath -Quiet:$Quiet `
            -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -ThrottleLimit $ThrottleLimit
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Markdown-Link-Check failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
