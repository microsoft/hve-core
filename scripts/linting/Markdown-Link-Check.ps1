#!/usr/bin/env pwsh
#Requires -Version 7.0


<#
.SYNOPSIS
    Repository-aware wrapper for markdown-link-check.

.DESCRIPTION
    Runs markdown-link-check with the repo-specific configuration to validate
    all markdown links across the repository. Only checks files that are tracked
    by git (respects .gitignore and only includes committed/staged files).

.PARAMETER Path
    One or more files or directories to scan. Directories are searched
    recursively for Markdown files. Defaults to the Docsify navigation sources.

.PARAMETER ConfigPath
    Path to the shared markdown-link-check configuration file.

.PARAMETER Quiet
    Suppress non-error output from markdown-link-check.

.EXAMPLE
    # Validate all markdown files in default paths
    ./Markdown-Link-Check.ps1

.EXAMPLE
    # Validate specific path with verbose output
    ./Markdown-Link-Check.ps1 -Path ".github" -Quiet:$false
    #>

[CmdletBinding()]
param(
    [string[]]$Path = @(
        ".",
        ".github",
        ".devcontainer"
    ),

    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'markdown-link-check.config.json'),

    [switch]$Quiet
)

# Import LintingHelpers module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force

function Get-MarkdownTarget {
    <#
    .SYNOPSIS
        Resolves Markdown files to validate from provided path arguments.

    .DESCRIPTION
        Accepts files or directories, expanding directories to all git-tracked
        Markdown files discovered recursively, and returns a sorted, unique list
        of absolute file paths for downstream validation. Only checks files that
        are tracked by git (respects .gitignore).

    .PARAMETER InputPath
        Files or directories that may contain Markdown content.

    .OUTPUTS
        System.String[]
    #>
    param(
        [string[]]$InputPath
    )

    $targets = @()
    $repoRoot = git rev-parse --show-toplevel 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Not in a git repository, falling back to file system search"
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

    Write-Verbose "Searching for git-tracked markdown files..."
    Write-Verbose "Repository root: $repoRoot"

    # Git-aware implementation
    foreach ($item in $InputPath) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        # Check if it's a specific file or directory
        if (Test-Path -Path $item -PathType Leaf) {
            # Specific file - check if it's tracked by git
            $absolutePath = (Resolve-Path $item).Path
            $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $absolutePath)
            $tracked = git ls-files $relativePath 2>$null

            if ($tracked -and $item -like "*.md") {
                $targets += $absolutePath
            }
            elseif (-not $tracked) {
                Write-Warning "File not tracked by git: $item"
            }
        }
        elseif (Test-Path -Path $item -PathType Container) {
            # Directory - get all tracked markdown files
            $absolutePath = (Resolve-Path $item).Path
            $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $absolutePath)
            $searchPath = if ($relativePath -eq '.') { '*.md' } else { "$relativePath/**/*.md" }

            Write-Verbose "Searching in: $searchPath"
            $trackedFiles = git ls-files $searchPath 2>$null

            if ($trackedFiles) {
                foreach ($file in $trackedFiles) {
                    $fullPath = Join-Path $repoRoot $file
                    if (Test-Path $fullPath) {
                        $targets += $fullPath
                    }
                }
            }
        }
        else {
            Write-Warning "Unable to resolve path: $item"
        }
    }

    Write-Verbose "Found $($targets.Count) git-tracked markdown files"
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

#region Main Execution
try {
    $scriptRootParent = Split-Path -Path $PSScriptRoot -Parent
    $repoRootPath = Split-Path -Path $scriptRootParent -Parent
    $repoRoot = Resolve-Path -LiteralPath $repoRootPath
    $config = Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop
    $filesToCheck = Get-MarkdownTarget -InputPath $Path

    if (-not $filesToCheck -or $filesToCheck.Count -eq 0) {
        Write-Error 'No markdown files were found to validate.'
        exit 1
    }

    $cli = Join-Path -Path $repoRoot.Path -ChildPath 'node_modules/.bin/markdown-link-check'
    if ($IsWindows) {
        $cli += '.cmd'
    }

    if (-not (Test-Path -LiteralPath $cli)) {
        Write-Error 'markdown-link-check is not installed. Run "npm install --save-dev markdown-link-check" first.'
        exit 1
    }

    $baseArguments = @('-c', $config.Path)
    if ($Quiet) {
        $baseArguments += '-q'
    }

    $failedFiles = @()
    $brokenLinks = @()
    $totalLinks = 0
    $totalFiles = $filesToCheck.Count

    Push-Location $repoRoot.Path
    try {
        foreach ($file in $filesToCheck) {
            $absolute = Resolve-Path -LiteralPath $file
            $relative = [System.IO.Path]::GetRelativePath($repoRoot.Path, $absolute)
            Write-Output "Checking $relative"

            # Create temp file for XML output
            $xmlFile = [System.IO.Path]::GetTempFileName() + '.xml'
            try {
                $commandArgs = $baseArguments + @($relative, '--reporters', 'default,junit', '--junit-output', $xmlFile)

                # Run markdown-link-check with XML output and capture output
                $output = & $cli @commandArgs 2>&1
                $exitCode = $LASTEXITCODE
                
                # Display output if verbose mode or if there were errors
                if ($VerbosePreference -eq 'Continue' -or $exitCode -ne 0) {
                    Write-Host $output
                }

                # Parse XML output
                if (Test-Path $xmlFile) {
                    [xml]$xml = Get-Content $xmlFile -Raw -Encoding utf8

                    foreach ($testsuite in $xml.testsuites.testsuite) {
                        foreach ($testcase in $testsuite.testcase) {
                            $totalLinks++

                            # Extract properties
                            $url = ($testcase.properties.property | Where-Object { $_.name -eq 'url' }).value
                            $status = ($testcase.properties.property | Where-Object { $_.name -eq 'status' }).value
                            $statusCode = ($testcase.properties.property | Where-Object { $_.name -eq 'statusCode' }).value

                            # Display human-readable output if not quiet
                            if (-not $Quiet) {
                                if ($status -eq 'alive') {
                                    Write-Host "  ✓ $url" -ForegroundColor Green
                                }
                                elseif ($status -eq 'ignored') {
                                    Write-Host "  / $url (ignored)" -ForegroundColor Yellow
                                }
                                elseif ($status -eq 'dead') {
                                    Write-Host "  ✖ $url → Status: $statusCode" -ForegroundColor Red
                                }
                            }

                            # Process broken links
                            if ($status -eq 'dead') {
                                $brokenLinks += @{
                                    File = $relative
                                    Link = $url
                                    Status = "$statusCode"
                                }

                                # Create GitHub annotation
                                Write-GitHubAnnotation -Type 'error' -Message "Broken link: $url (Status: $statusCode)" -File $relative
                            }
                        }
                    }
                }

                if ($exitCode -ne 0) {
                    $failedFiles += $relative
                }
            }
            catch {
                Write-Warning "Failed to parse XML output for $relative : $_"
                if ($exitCode -ne 0) {
                    $failedFiles += $relative
                }
            }
            finally {
                if (Test-Path $xmlFile) {
                    Remove-Item $xmlFile -Force
                }
            }
        }
    }
    finally {
        Pop-Location
    }

    # Create logs directory and export results
    $logsDir = Join-Path -Path $repoRoot.Path -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $results = @{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        script = 'markdown-link-check'
        summary = @{
            total_files = $totalFiles
            files_with_broken_links = $failedFiles.Count
            total_links_checked = $totalLinks
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
            $summaryContent += "`n| ``$($link.File)`` | ``$($link.Link)`` |"
        }

        $summaryContent += @"


### How to Fix

1. Review the broken links listed above
2. Update or remove invalid links
3. Re-run the link check to verify fixes

For more information, see the [markdown-link-check documentation](https://github.com/tcort/markdown-link-check).
"@

        Write-GitHubStepSummary -Content $summaryContent
        Set-GitHubEnv -Name "MARKDOWN_LINK_CHECK_FAILED" -Value "true"

        Write-Error ("markdown-link-check reported failures for: {0}" -f ($failedFiles -join ', '))
        exit 1
    }
    else {
        $summaryContent = @"
## ✅ Markdown Link Check Passed

**Files checked:** $totalFiles
**Total links checked:** $totalLinks
**Broken links:** 0

Great job! All markdown links are valid. 🎉
"@

        Write-GitHubStepSummary -Content $summaryContent
        Write-Output 'markdown-link-check completed successfully.'
        exit 0
    }
}
catch {
    Write-Error "Markdown Link Check failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion